# ⚡ Quick Reference Card

## 🏦 Banking Transactions ETL - Command Cheat Sheet

---

## 🚀 Quick Start

```powershell
# 1. Setup (one time)
pip install -r requirements.txt
.\QUICKSTART.ps1

# 2. Run pipeline
.\run_pipeline.ps1

# 3. Monitor
python monitoring\performance_monitor.py
```

---

## 📊 Common Commands

### Data Generation
```powershell
# Generate 10K transactions (test)
python scripts\data_generator.py --count 10000

# Generate 1M transactions (production)
python scripts\data_generator.py --count 1000000 --days 1

# Generate multiple days
python scripts\data_generator.py --count 500000 --days 7

# Custom output
python scripts\data_generator.py --count 100000 --output data\custom\
```

### ETL Pipeline
```powershell
# Basic ETL run
python scripts\etl_pipeline.py --input data\raw --output data\processed

# ETL with database load
python scripts\etl_pipeline.py --input data\raw --output data\processed --load-db

# ETL without aggregations
python scripts\etl_pipeline.py --input data\raw --output data\processed --no-aggregations

# Process specific file
python scripts\etl_pipeline.py --input data\raw\transactions_20241201.csv --output data\processed
```

### MinIO Operations
```powershell
# Initialize buckets
python scripts\minio_manager.py init

# Upload directory
python scripts\minio_manager.py upload --bucket transactions-raw --local data\raw

# Upload single file
python scripts\minio_manager.py upload --bucket transactions-raw --local data\raw\file.csv --remote file.csv

# List objects
python scripts\minio_manager.py list --bucket transactions-raw

# List with prefix
python scripts\minio_manager.py list --bucket transactions-raw --prefix "2024/12/"

# Download file
python scripts\minio_manager.py download --bucket transactions-raw --remote file.csv --local data\download\file.csv

# Get statistics
python scripts\minio_manager.py stats
```

### Performance Monitoring
```powershell
# One-time dashboard
python monitoring\performance_monitor.py

# Continuous monitoring (refresh every 30s)
python monitoring\performance_monitor.py --watch

# Save metrics to file
python monitoring\performance_monitor.py --save logs\metrics.json

# Watch and save
python monitoring\performance_monitor.py --watch --save logs\metrics.json
```

---

## 🗄️ Database Commands

### PostgreSQL Access
```powershell
# Connect to database
psql -U postgres -d banking_transactions

# Run SQL file
psql -U postgres -d banking_transactions -f sql\analytics_queries.sql

# Backup database
pg_dump -U postgres banking_transactions > backup.sql

# Restore database
psql -U postgres banking_transactions < backup.sql
```

### Quick Queries
```sql
-- Total transactions
SELECT COUNT(*) FROM transactions_fact;

-- Today's transactions
SELECT COUNT(*) FROM transactions_fact WHERE transaction_date = CURRENT_DATE;

-- Top customers
SELECT customer_id, SUM(amount) as total 
FROM transactions_fact 
GROUP BY customer_id 
ORDER BY total DESC 
LIMIT 10;

-- Fraud alerts
SELECT * FROM transactions_fact WHERE is_fraudulent = TRUE;

-- Table sizes
SELECT pg_size_pretty(pg_total_relation_size('transactions_fact'));
```

---

## 🔧 Maintenance Commands

### Database Maintenance
```sql
-- Update statistics
ANALYZE transactions_fact;

-- Reclaim space
VACUUM transactions_fact;

-- Full vacuum
VACUUM FULL ANALYZE transactions_fact;

-- Rebuild indexes
REINDEX TABLE transactions_fact;

-- Check table bloat
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) 
FROM pg_tables 
WHERE schemaname = 'public';
```

### System Checks
```powershell
# Check Python
python --version
pip list | findstr pyspark

# Check Java (for Spark)
java -version

# Check PostgreSQL service
Get-Service postgresql*

# Check ports
netstat -ano | findstr :5432  # PostgreSQL
netstat -ano | findstr :9000  # MinIO

# Check disk space
Get-PSDrive C

# Check processes
Get-Process | Where-Object {$_.Name -like "*postgres*"}
Get-Process | Where-Object {$_.Name -like "*minio*"}
```

---

## 📁 File Locations

### Data
- Raw: `data\raw\`
- Processed: `data\processed\`
- Logs: `logs\`

### Configuration
- MinIO: `config\minio_config.json`
- Spark: `config\spark_config.json`
- Database: `config\database_config.json`

### Scripts
- Generator: `scripts\data_generator.py`
- ETL: `scripts\etl_pipeline.py`
- MinIO: `scripts\minio_manager.py`
- Monitor: `monitoring\performance_monitor.py`

---

## 🎯 Typical Workflows

### Daily ETL Run
```powershell
# 1. Generate daily data
python scripts\data_generator.py --count 1000000

# 2. Run ETL
python scripts\etl_pipeline.py --input data\raw --output data\processed

# 3. Check results
python monitoring\performance_monitor.py

# 4. Backup (optional)
pg_dump -U postgres banking_transactions > backup_$(Get-Date -Format yyyyMMdd).sql
```

### Testing Workflow
```powershell
# 1. Generate small dataset
python scripts\data_generator.py --count 1000

# 2. Test ETL
python scripts\etl_pipeline.py --input data\raw --output data\processed

# 3. Verify in database
psql -U postgres -d banking_transactions -c "SELECT COUNT(*) FROM transactions_fact;"
```

### Performance Optimization
```powershell
# 1. Check current performance
python monitoring\performance_monitor.py

# 2. Update database statistics
psql -U postgres -d banking_transactions -c "ANALYZE;"

# 3. Rebuild indexes
psql -U postgres -d banking_transactions -f sql\create_indexes.sql

# 4. Verify improvement
python monitoring\performance_monitor.py
```

---

## 🔍 Troubleshooting Commands

### Diagnose Issues
```powershell
# Check logs
Get-Content -Tail 50 logs\etl_pipeline_*.log
Get-Content logs\*.log | Select-String "ERROR"

# Test database connection
python scripts\test_db_connection.py

# Test Spark
python scripts\test_spark.py

# Check system resources
python -c "import psutil; print(f'CPU: {psutil.cpu_percent()}%'); print(f'RAM: {psutil.virtual_memory().percent}%')"
```

### Fix Common Issues
```powershell
# Restart PostgreSQL
Restart-Service postgresql-x64-14

# Clear temp files
Remove-Item data\staging\* -Recurse -Force

# Reinstall Python packages
pip install -r requirements.txt --force-reinstall

# Reset database (⚠️ deletes all data)
psql -U postgres -c "DROP DATABASE banking_transactions;"
psql -U postgres -f sql\create_tables.sql
```

---

## 📊 Useful Queries

### Performance Analysis
```sql
-- Slowest queries
SELECT queryid, calls, mean_exec_time, query 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;

-- Table access patterns
SELECT schemaname, tablename, seq_scan, idx_scan 
FROM pg_stat_user_tables;

-- Index usage
SELECT indexrelname, idx_scan 
FROM pg_stat_user_indexes 
ORDER BY idx_scan DESC;
```

### Business Analytics
```sql
-- Daily volume
SELECT transaction_date, COUNT(*), SUM(amount) 
FROM transactions_fact 
GROUP BY transaction_date 
ORDER BY transaction_date DESC;

-- Top merchants
SELECT merchant_name, COUNT(*), SUM(amount) 
FROM transactions_fact 
WHERE status = 'COMPLETED' 
GROUP BY merchant_name 
ORDER BY SUM(amount) DESC 
LIMIT 20;

-- Fraud rate
SELECT COUNT(*) FILTER (WHERE is_fraudulent) * 100.0 / COUNT(*) as fraud_rate_pct 
FROM transactions_fact;
```

---

## ⚙️ Configuration Quick Reference

### Spark Memory
```json
// Edit config/spark_config.json
"spark.driver.memory": "4g"     // Increase if out of memory
"spark.executor.memory": "4g"   // Increase for large datasets
```

### Spark Parallelism
```json
"spark.default.parallelism": "8"        // Number of CPU cores
"spark.sql.shuffle.partitions": "200"   // Reduce for small data
```

### Database Connection
```json
// Edit config/database_config.json
"host": "localhost",
"port": 5432,
"database": "banking_transactions",
"user": "postgres",
"password": "postgres"  // ⚠️ Change in production!
```

---

## 📞 Quick Help

- **Full Docs**: [README.md](README.md)
- **Setup**: [QUICKSTART.ps1](QUICKSTART.ps1)
- **Problems**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Architecture**: [ARCHITECTURE.md](ARCHITECTURE.md)

---

## 🎓 Key Concepts

| Term | Meaning |
|------|---------|
| **ETL** | Extract, Transform, Load |
| **Partitioning** | Split table by date for performance |
| **Parquet** | Columnar file format (compressed) |
| **MinIO** | S3-compatible object storage |
| **PySpark** | Python API for Apache Spark |
| **Fact Table** | Main transaction records |
| **Dimension Table** | Reference data (customers, merchants) |

---

**Last Updated**: December 2025  
**Version**: 1.0
