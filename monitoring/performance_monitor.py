"""
Performance Monitoring System
Track ETL pipeline performance and data warehouse metrics
"""

import psycopg2
import json
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List
import logging
from tabulate import tabulate
import psutil

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class PerformanceMonitor:
    """Monitor ETL pipeline and database performance"""
    
    def __init__(self, config_path: str = 'config/database_config.json'):
        """Initialize monitoring connection"""
        
        with open(config_path, 'r') as f:
            db_config = json.load(f)['postgresql']
        
        self.db_config = db_config
        self.conn = None
        
    def connect(self):
        """Connect to PostgreSQL"""
        try:
            self.conn = psycopg2.connect(
                host=self.db_config['host'],
                port=self.db_config['port'],
                database=self.db_config['database'],
                user=self.db_config['user'],
                password=self.db_config['password']
            )
            logger.info("✓ Connected to PostgreSQL")
        except Exception as e:
            logger.error(f"Connection failed: {e}")
            raise
    
    def disconnect(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
            logger.info("✓ Disconnected from PostgreSQL")
    
    def get_table_stats(self) -> List[Dict]:
        """Get statistics for all tables"""
        
        query = """
        SELECT 
            schemaname,
            tablename,
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
            pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - 
                          pg_relation_size(schemaname||'.'||tablename)) AS indexes_size,
            n_live_tup AS row_count,
            n_dead_tup AS dead_rows,
            last_vacuum,
            last_autovacuum,
            last_analyze,
            last_autoanalyze
        FROM pg_stat_user_tables
        ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
        """
        
        cursor = self.conn.cursor()
        cursor.execute(query)
        
        columns = [desc[0] for desc in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        
        cursor.close()
        return results
    
    def get_index_stats(self) -> List[Dict]:
        """Get index usage statistics"""
        
        query = """
        SELECT 
            schemaname,
            tablename,
            indexname,
            idx_scan AS index_scans,
            idx_tup_read AS tuples_read,
            idx_tup_fetch AS tuples_fetched,
            pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
        FROM pg_stat_user_indexes
        ORDER BY idx_scan DESC
        LIMIT 20;
        """
        
        cursor = self.conn.cursor()
        cursor.execute(query)
        
        columns = [desc[0] for desc in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        
        cursor.close()
        return results
    
    def get_query_performance(self) -> List[Dict]:
        """Get slow query statistics"""
        
        query = """
        SELECT 
            queryid,
            calls,
            total_exec_time::numeric(10,2) AS total_time_ms,
            mean_exec_time::numeric(10,2) AS avg_time_ms,
            max_exec_time::numeric(10,2) AS max_time_ms,
            stddev_exec_time::numeric(10,2) AS stddev_time_ms,
            rows,
            SUBSTRING(query, 1, 100) AS query_preview
        FROM pg_stat_statements
        WHERE query NOT LIKE '%pg_stat%'
        ORDER BY total_exec_time DESC
        LIMIT 10;
        """
        
        try:
            cursor = self.conn.cursor()
            cursor.execute(query)
            
            columns = [desc[0] for desc in cursor.description]
            results = [dict(zip(columns, row)) for row in cursor.fetchall()]
            
            cursor.close()
            return results
        except Exception as e:
            logger.warning(f"Could not fetch query stats: {e}")
            logger.info("Make sure pg_stat_statements extension is enabled")
            return []
    
    def get_transaction_stats(self) -> Dict:
        """Get transaction table statistics"""
        
        queries = {
            'total_transactions': """
                SELECT COUNT(*) FROM transactions_fact;
            """,
            'total_amount': """
                SELECT SUM(amount)::numeric(15,2) FROM transactions_fact WHERE status = 'COMPLETED';
            """,
            'avg_amount': """
                SELECT AVG(amount)::numeric(10,2) FROM transactions_fact WHERE status = 'COMPLETED';
            """,
            'fraud_count': """
                SELECT COUNT(*) FROM transactions_fact WHERE is_fraudulent = TRUE;
            """,
            'high_risk_count': """
                SELECT COUNT(*) FROM transactions_fact WHERE is_high_risk = TRUE;
            """,
            'latest_transaction': """
                SELECT MAX(transaction_timestamp) FROM transactions_fact;
            """,
            'oldest_transaction': """
                SELECT MIN(transaction_timestamp) FROM transactions_fact;
            """,
            'unique_customers': """
                SELECT COUNT(DISTINCT customer_id) FROM transactions_fact;
            """,
            'unique_merchants': """
                SELECT COUNT(DISTINCT merchant_id) FROM transactions_fact;
            """,
            'by_status': """
                SELECT status, COUNT(*) as count, SUM(amount)::numeric(15,2) as total_amount
                FROM transactions_fact
                GROUP BY status
                ORDER BY count DESC;
            """,
            'by_type': """
                SELECT transaction_type, COUNT(*) as count, AVG(amount)::numeric(10,2) as avg_amount
                FROM transactions_fact
                GROUP BY transaction_type
                ORDER BY count DESC;
            """,
            'daily_volume': """
                SELECT transaction_date, COUNT(*) as count, SUM(amount)::numeric(15,2) as total
                FROM transactions_fact
                GROUP BY transaction_date
                ORDER BY transaction_date DESC
                LIMIT 7;
            """
        }
        
        cursor = self.conn.cursor()
        stats = {}
        
        for key, query in queries.items():
            cursor.execute(query)
            
            if key in ['by_status', 'by_type', 'daily_volume']:
                columns = [desc[0] for desc in cursor.description]
                stats[key] = [dict(zip(columns, row)) for row in cursor.fetchall()]
            else:
                result = cursor.fetchone()
                stats[key] = result[0] if result else 0
        
        cursor.close()
        return stats
    
    def get_partition_stats(self) -> List[Dict]:
        """Get partition size statistics"""
        
        query = """
        SELECT 
            tablename,
            pg_size_pretty(pg_total_relation_size('public.'||tablename)) AS size
        FROM pg_tables
        WHERE tablename LIKE 'transactions_fact_%'
        ORDER BY tablename;
        """
        
        cursor = self.conn.cursor()
        cursor.execute(query)
        
        columns = [desc[0] for desc in cursor.description]
        results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        
        cursor.close()
        return results
    
    def get_system_metrics(self) -> Dict:
        """Get system resource metrics"""
        
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        return {
            'cpu_percent': cpu_percent,
            'memory_percent': memory.percent,
            'memory_available_gb': memory.available / (1024**3),
            'disk_percent': disk.percent,
            'disk_free_gb': disk.free / (1024**3)
        }
    
    def print_dashboard(self):
        """Print comprehensive monitoring dashboard"""
        
        print("\n" + "=" * 80)
        print(" " * 20 + "BANKING TRANSACTIONS MONITORING DASHBOARD")
        print("=" * 80)
        print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 80)
        
        # System Metrics
        print("\n📊 SYSTEM METRICS")
        print("-" * 80)
        sys_metrics = self.get_system_metrics()
        sys_table = [
            ['CPU Usage', f"{sys_metrics['cpu_percent']:.1f}%"],
            ['Memory Usage', f"{sys_metrics['memory_percent']:.1f}%"],
            ['Memory Available', f"{sys_metrics['memory_available_gb']:.2f} GB"],
            ['Disk Usage', f"{sys_metrics['disk_percent']:.1f}%"],
            ['Disk Free', f"{sys_metrics['disk_free_gb']:.2f} GB"]
        ]
        print(tabulate(sys_table, headers=['Metric', 'Value'], tablefmt='grid'))
        
        # Transaction Statistics
        print("\n💰 TRANSACTION STATISTICS")
        print("-" * 80)
        tx_stats = self.get_transaction_stats()
        
        tx_table = [
            ['Total Transactions', f"{tx_stats['total_transactions']:,}"],
            ['Total Amount', f"€{tx_stats['total_amount']:,.2f}"],
            ['Average Amount', f"€{tx_stats['avg_amount']:,.2f}"],
            ['Unique Customers', f"{tx_stats['unique_customers']:,}"],
            ['Unique Merchants', f"{tx_stats['unique_merchants']:,}"],
            ['Fraud Cases', f"{tx_stats['fraud_count']:,}"],
            ['High Risk Transactions', f"{tx_stats['high_risk_count']:,}"],
            ['Latest Transaction', str(tx_stats['latest_transaction'])],
            ['Oldest Transaction', str(tx_stats['oldest_transaction'])]
        ]
        print(tabulate(tx_table, headers=['Metric', 'Value'], tablefmt='grid'))
        
        # By Status
        print("\n📈 TRANSACTIONS BY STATUS")
        print("-" * 80)
        print(tabulate(tx_stats['by_status'], headers='keys', tablefmt='grid'))
        
        # By Type
        print("\n🏷️  TRANSACTIONS BY TYPE")
        print("-" * 80)
        print(tabulate(tx_stats['by_type'], headers='keys', tablefmt='grid'))
        
        # Daily Volume (Last 7 Days)
        print("\n📅 DAILY VOLUME (Last 7 Days)")
        print("-" * 80)
        print(tabulate(tx_stats['daily_volume'], headers='keys', tablefmt='grid'))
        
        # Table Stats
        print("\n💾 DATABASE TABLES")
        print("-" * 80)
        table_stats = self.get_table_stats()
        table_display = [
            {
                'Table': row['tablename'],
                'Rows': f"{row['row_count']:,}" if row['row_count'] else 'N/A',
                'Total Size': row['total_size'],
                'Table Size': row['table_size'],
                'Index Size': row['indexes_size']
            }
            for row in table_stats[:10]
        ]
        print(tabulate(table_display, headers='keys', tablefmt='grid'))
        
        # Partition Stats
        print("\n📁 PARTITION SIZES")
        print("-" * 80)
        partition_stats = self.get_partition_stats()
        if partition_stats:
            print(tabulate(partition_stats, headers='keys', tablefmt='grid'))
        else:
            print("No partitions found")
        
        # Index Usage
        print("\n🔍 TOP 10 MOST USED INDEXES")
        print("-" * 80)
        index_stats = self.get_index_stats()
        if index_stats:
            index_display = [
                {
                    'Index': row['indexname'][:40],
                    'Scans': f"{row['index_scans']:,}",
                    'Tuples Read': f"{row['tuples_read']:,}",
                    'Size': row['index_size']
                }
                for row in index_stats[:10]
            ]
            print(tabulate(index_display, headers='keys', tablefmt='grid'))
        else:
            print("No index statistics available")
        
        # Query Performance
        print("\n⚡ TOP 10 QUERIES BY TOTAL TIME")
        print("-" * 80)
        query_stats = self.get_query_performance()
        if query_stats:
            query_display = [
                {
                    'Calls': row['calls'],
                    'Total (ms)': f"{row['total_time_ms']:,.2f}",
                    'Avg (ms)': f"{row['avg_time_ms']:.2f}",
                    'Max (ms)': f"{row['max_time_ms']:.2f}",
                    'Query': row['query_preview'][:50]
                }
                for row in query_stats
            ]
            print(tabulate(query_display, headers='keys', tablefmt='grid'))
        else:
            print("No query statistics available (enable pg_stat_statements)")
        
        print("\n" + "=" * 80)
        print("✓ Dashboard updated successfully")
        print("=" * 80 + "\n")
    
    def save_metrics_to_file(self, output_path: str = 'logs/metrics.json'):
        """Save metrics to JSON file"""
        
        metrics = {
            'timestamp': datetime.now().isoformat(),
            'system': self.get_system_metrics(),
            'transactions': self.get_transaction_stats(),
            'tables': self.get_table_stats(),
            'indexes': self.get_index_stats(),
            'queries': self.get_query_performance()
        }
        
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w') as f:
            json.dump(metrics, f, indent=2, default=str)
        
        logger.info(f"✓ Metrics saved to {output_path}")


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Performance Monitoring Dashboard')
    parser.add_argument('--watch', action='store_true',
                       help='Continuously monitor (refresh every 30s)')
    parser.add_argument('--save', type=str,
                       help='Save metrics to JSON file')
    
    args = parser.parse_args()
    
    monitor = PerformanceMonitor()
    
    try:
        monitor.connect()
        
        if args.watch:
            logger.info("Starting continuous monitoring (Ctrl+C to stop)...")
            while True:
                monitor.print_dashboard()
                if args.save:
                    monitor.save_metrics_to_file(args.save)
                time.sleep(30)
        else:
            monitor.print_dashboard()
            if args.save:
                monitor.save_metrics_to_file(args.save)
        
    except KeyboardInterrupt:
        logger.info("\nMonitoring stopped by user")
    except Exception as e:
        logger.error(f"Error: {e}")
    finally:
        monitor.disconnect()


if __name__ == '__main__':
    main()
