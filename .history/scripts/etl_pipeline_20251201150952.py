"""
ETL Pipeline - Banking Transactions
Alternative to AWS Glue using Apache Spark (PySpark)

This pipeline:
1. Reads raw transaction data from MinIO (S3 alternative)
2. Cleans and validates the data
3. Applies business transformations
4. Partitions and compresses output
5. Loads to PostgreSQL (Redshift alternative)
"""

import json
import time
from pathlib import Path
from datetime import datetime
from typing import Dict, List
import argparse

from pyspark.sql import SparkSession, DataFrame
from pyspark.sql import functions as F
from pyspark.sql.types import *
from pyspark.sql.window import Window

import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class BankingETLPipeline:
    """ETL Pipeline for Banking Transactions - AWS Glue Alternative"""
    
    def __init__(self, config_path: str = 'config/spark_config.json'):
        """Initialize Spark session with optimized configuration"""
        
        # Load configuration
        with open(config_path, 'r') as f:
            self.config = json.load(f)
        
        # Initialize Spark with optimizations
        logger.info("Initializing Spark session...")
        builder = SparkSession.builder.appName(self.config['spark']['app_name'])
        
        # Apply Spark configurations
        for key, value in self.config['spark']['config'].items():
            builder = builder.config(key, value)
        
        self.spark = builder.getOrCreate()
        
        # Set log level
        self.spark.sparkContext.setLogLevel("WARN")
        
        logger.info(f"✓ Spark session initialized - Version {self.spark.version}")
        logger.info(f"✓ Master: {self.spark.sparkContext.master}")
        
        # Define schema for transactions
        self.transaction_schema = StructType([
            StructField("transaction_id", StringType(), False),
            StructField("transaction_date", StringType(), False),
            StructField("transaction_timestamp", TimestampType(), False),
            StructField("customer_id", StringType(), False),
            StructField("transaction_type", StringType(), False),
            StructField("amount", DoubleType(), False),
            StructField("currency", StringType(), True),
            StructField("status", StringType(), False),
            StructField("merchant_id", StringType(), True),
            StructField("merchant_name", StringType(), True),
            StructField("merchant_category", StringType(), True),
            StructField("country", StringType(), True),
            StructField("channel", StringType(), True),
            StructField("card_type", StringType(), True),
            StructField("is_fraudulent", BooleanType(), True),
            StructField("processing_time_ms", IntegerType(), True)
        ])
        
        self.stats = {
            'start_time': None,
            'end_time': None,
            'records_read': 0,
            'records_after_cleaning': 0,
            'records_written': 0,
            'duplicates_removed': 0,
            'invalid_records': 0
        }
    
    def read_data(self, input_path: str, file_format: str = 'csv') -> DataFrame:
        """
        Read raw transaction data with schema enforcement
        Equivalent to AWS Glue's Data Catalog + DynamicFrame
        """
        
        logger.info(f"Reading data from: {input_path}")
        
        try:
            if file_format == 'csv':
                df = self.spark.read \
                    .option("header", "true") \
                    .option("inferSchema", "true") \
                    .option("mode", "PERMISSIVE") \
                    .csv(input_path)
            elif file_format == 'json':
                df = self.spark.read \
                    .option("mode", "PERMISSIVE") \
                    .json(input_path)
            elif file_format == 'parquet':
                df = self.spark.read.parquet(input_path)
            else:
                raise ValueError(f"Unsupported format: {file_format}")
            
            self.stats['records_read'] = df.count()
            logger.info(f"✓ Read {self.stats['records_read']:,} records")
            
            return df
            
        except Exception as e:
            logger.error(f"Error reading data: {e}")
            raise
    
    def clean_data(self, df: DataFrame) -> DataFrame:
        """
        Data Quality & Cleaning
        Equivalent to AWS Glue's Data Quality rules
        """
        
        logger.info("Starting data cleaning process...")
        initial_count = df.count()
        
        # 1. Remove duplicates based on transaction_id
        logger.info("Removing duplicates...")
        df_clean = df.dropDuplicates(['transaction_id'])
        self.stats['duplicates_removed'] = initial_count - df_clean.count()
        logger.info(f"✓ Removed {self.stats['duplicates_removed']:,} duplicates")
        
        # 2. Remove records with null critical fields
        logger.info("Removing invalid records...")
        df_clean = df_clean.filter(
            (F.col('transaction_id').isNotNull()) &
            (F.col('customer_id').isNotNull()) &
            (F.col('amount').isNotNull()) &
            (F.col('transaction_date').isNotNull())
        )
        
        # 3. Data type conversions and validations
        df_clean = df_clean.withColumn(
            'transaction_timestamp',
            F.to_timestamp(F.col('transaction_timestamp'))
        )
        
        df_clean = df_clean.withColumn(
            'transaction_date',
            F.to_date(F.col('transaction_date'))
        )
        
        # 4. Amount validation (positive amounts only)
        df_clean = df_clean.filter(F.col('amount') > 0)
        
        # 5. Remove outliers (amounts > 1 million are suspicious)
        df_clean = df_clean.filter(F.col('amount') <= 1000000)
        
        # 6. Fill missing values
        df_clean = df_clean.fillna({
            'merchant_id': 'UNKNOWN',
            'merchant_name': 'UNKNOWN',
            'merchant_category': 'UNKNOWN',
            'currency': 'EUR',
            'is_fraudulent': False,
            'card_type': 'UNKNOWN'
        })
        
        invalid_count = initial_count - self.stats['duplicates_removed'] - df_clean.count()
        self.stats['invalid_records'] = invalid_count
        self.stats['records_after_cleaning'] = df_clean.count()
        
        logger.info(f"✓ Removed {invalid_count:,} invalid records")
        logger.info(f"✓ Clean records: {self.stats['records_after_cleaning']:,}")
        
        return df_clean
    
    def apply_transformations(self, df: DataFrame) -> DataFrame:
        """
        Business Transformations
        Equivalent to AWS Glue's transformation logic
        """
        
        logger.info("Applying business transformations...")
        
        # 1. Add derived columns
        df_transformed = df.withColumn(
            'year',
            F.year(F.col('transaction_date'))
        ).withColumn(
            'month',
            F.month(F.col('transaction_date'))
        ).withColumn(
            'day',
            F.dayofmonth(F.col('transaction_date'))
        ).withColumn(
            'day_of_week',
            F.dayofweek(F.col('transaction_date'))
        ).withColumn(
            'hour',
            F.hour(F.col('transaction_timestamp'))
        )
        
        # 2. Add amount categories
        df_transformed = df_transformed.withColumn(
            'amount_category',
            F.when(F.col('amount') < 10, 'MICRO')
            .when((F.col('amount') >= 10) & (F.col('amount') < 100), 'SMALL')
            .when((F.col('amount') >= 100) & (F.col('amount') < 1000), 'MEDIUM')
            .when((F.col('amount') >= 1000) & (F.col('amount') < 10000), 'LARGE')
            .otherwise('VERY_LARGE')
        )
        
        # 3. Add time categories
        df_transformed = df_transformed.withColumn(
            'time_of_day',
            F.when(F.col('hour').between(6, 11), 'MORNING')
            .when(F.col('hour').between(12, 17), 'AFTERNOON')
            .when(F.col('hour').between(18, 21), 'EVENING')
            .otherwise('NIGHT')
        )
        
        # 4. Calculate customer transaction frequency (using window functions)
        window_spec = Window.partitionBy('customer_id', 'transaction_date')
        
        df_transformed = df_transformed.withColumn(
            'daily_transaction_count',
            F.count('*').over(window_spec)
        )
        
        # 5. Calculate running totals per customer per day
        window_spec_running = Window.partitionBy('customer_id', 'transaction_date') \
                                    .orderBy('transaction_timestamp') \
                                    .rowsBetween(Window.unboundedPreceding, Window.currentRow)
        
        df_transformed = df_transformed.withColumn(
            'daily_cumulative_amount',
            F.sum('amount').over(window_spec_running)
        )
        
        # 6. Flag high-risk transactions
        df_transformed = df_transformed.withColumn(
            'is_high_risk',
            (F.col('amount') > 5000) |
            (F.col('is_fraudulent') == True) |
            (F.col('daily_transaction_count') > 20)
        )
        
        # 7. Add processing metadata
        df_transformed = df_transformed.withColumn(
            'etl_processed_timestamp',
            F.current_timestamp()
        ).withColumn(
            'etl_job_id',
            F.lit(f"ETL_{datetime.now().strftime('%Y%m%d_%H%M%S')}")
        )
        
        logger.info("✓ Business transformations completed")
        
        return df_transformed
    
    def create_aggregations(self, df: DataFrame, output_path: str):
        """
        Create aggregated summary tables
        Similar to materialized views in Redshift
        """
        
        logger.info("Creating daily aggregations...")
        
        # Daily summary by customer
        daily_summary = df.groupBy(
            'customer_id',
            'transaction_date',
            'year',
            'month',
            'day'
        ).agg(
            F.count('*').alias('transaction_count'),
            F.sum('amount').alias('total_amount'),
            F.avg('amount').alias('avg_amount'),
            F.min('amount').alias('min_amount'),
            F.max('amount').alias('max_amount'),
            F.countDistinct('merchant_id').alias('unique_merchants'),
            F.sum(F.when(F.col('is_fraudulent'), 1).otherwise(0)).alias('fraud_count'),
            F.sum(F.when(F.col('status') == 'COMPLETED', 1).otherwise(0)).alias('completed_count'),
            F.sum(F.when(F.col('status') == 'FAILED', 1).otherwise(0)).alias('failed_count')
        )
        
        # Save aggregations
        agg_output = f"{output_path}/daily_summary"
        daily_summary.write \
            .mode('overwrite') \
            .partitionBy('year', 'month') \
            .parquet(agg_output)
        
        logger.info(f"✓ Daily aggregations saved to {agg_output}")
        
        # Merchant summary
        merchant_summary = df.groupBy(
            'merchant_id',
            'merchant_name',
            'merchant_category',
            'transaction_date'
        ).agg(
            F.count('*').alias('transaction_count'),
            F.sum('amount').alias('total_revenue'),
            F.avg('amount').alias('avg_transaction'),
            F.countDistinct('customer_id').alias('unique_customers')
        )
        
        merchant_output = f"{output_path}/merchant_summary"
        merchant_summary.write \
            .mode('overwrite') \
            .partitionBy('transaction_date') \
            .parquet(merchant_output)
        
        logger.info(f"✓ Merchant aggregations saved to {merchant_output}")
    
    def write_data(
        self, 
        df: DataFrame, 
        output_path: str,
        partition_by: List[str] = None,
        file_format: str = 'parquet'
    ):
        """
        Write transformed data with partitioning and compression
        Equivalent to AWS Glue's output to S3 with optimizations
        """
        
        logger.info(f"Writing data to: {output_path}")
        logger.info(f"Format: {file_format}, Partitioning: {partition_by}")
        
        # Get configuration
        compression = self.config['optimization']['compression_codec']
        
        try:
            writer = df.write.mode('overwrite')
            
            if partition_by:
                writer = writer.partitionBy(*partition_by)
            
            if file_format == 'parquet':
                writer.option('compression', compression) \
                      .parquet(output_path)
            elif file_format == 'csv':
                writer.option('header', 'true') \
                      .option('compression', 'gzip') \
                      .csv(output_path)
            elif file_format == 'json':
                writer.option('compression', compression) \
                      .json(output_path)
            else:
                raise ValueError(f"Unsupported format: {file_format}")
            
            self.stats['records_written'] = df.count()
            logger.info(f"✓ Wrote {self.stats['records_written']:,} records")
            
        except Exception as e:
            logger.error(f"Error writing data: {e}")
            raise
    
    def load_to_postgresql(self, df: DataFrame, table_name: str):
        """
        Load data to PostgreSQL (Redshift alternative)
        Using JDBC connector with optimizations
        """
        
        logger.info(f"Loading data to PostgreSQL table: {table_name}")
        
        # Load database configuration
        with open('config/database_config.json', 'r') as f:
            db_config = json.load(f)['postgresql']
        
        jdbc_url = f"jdbc:postgresql://{db_config['host']}:{db_config['port']}/{db_config['database']}"
        
        connection_properties = {
            "user": db_config['user'],
            "password": db_config['password'],
            "driver": "org.postgresql.Driver",
            "batchsize": "10000",
            "isolationLevel": "READ_COMMITTED"
        }
        
        try:
            df.write \
                .jdbc(
                    url=jdbc_url,
                    table=table_name,
                    mode='overwrite',
                    properties=connection_properties
                )
            
            logger.info(f"✓ Data loaded to PostgreSQL table: {table_name}")
            
        except Exception as e:
            logger.error(f"Error loading to PostgreSQL: {e}")
            logger.warning("Make sure PostgreSQL JDBC driver is in Spark classpath")
            logger.warning("Download from: https://jdbc.postgresql.org/download/")
            raise
    
    def run_pipeline(
        self,
        input_path: str,
        output_path: str,
        load_to_db: bool = False,
        create_aggregations: bool = True
    ):
        """
        Execute complete ETL pipeline
        Main orchestration method
        """
        
        logger.info("=" * 70)
        logger.info("BANKING TRANSACTIONS ETL PIPELINE - STARTING")
        logger.info("=" * 70)
        
        self.stats['start_time'] = time.time()
        
        try:
            # Step 1: Read raw data
            logger.info("\n[STEP 1/5] Reading raw data...")
            df_raw = self.read_data(input_path)
            
            # Step 2: Clean data
            logger.info("\n[STEP 2/5] Cleaning data...")
            df_clean = self.clean_data(df_raw)
            
            # Step 3: Apply transformations
            logger.info("\n[STEP 3/5] Applying transformations...")
            df_transformed = self.apply_transformations(df_clean)
            
            # Cache for multiple operations
            df_transformed.cache()
            
            # Step 4: Write transformed data
            logger.info("\n[STEP 4/5] Writing transformed data...")
            self.write_data(
                df_transformed,
                f"{output_path}/transactions",
                partition_by=['year', 'month', 'day'],
                file_format='parquet'
            )
            
            # Step 5: Create aggregations
            if create_aggregations:
                logger.info("\n[STEP 5/5] Creating aggregations...")
                self.create_aggregations(df_transformed, output_path)
            
            # Optional: Load to PostgreSQL
            if load_to_db:
                logger.info("\n[OPTIONAL] Loading to PostgreSQL...")
                self.load_to_postgresql(df_transformed, 'transactions_fact')
            
            # Unpersist cached data
            df_transformed.unpersist()
            
            self.stats['end_time'] = time.time()
            self._print_statistics()
            
            logger.info("=" * 70)
            logger.info("✓ ETL PIPELINE COMPLETED SUCCESSFULLY")
            logger.info("=" * 70)
            
        except Exception as e:
            logger.error(f"Pipeline failed: {e}")
            raise
        finally:
            self.spark.stop()
    
    def _print_statistics(self):
        """Print pipeline execution statistics"""
        
        duration = self.stats['end_time'] - self.stats['start_time']
        
        logger.info("\n" + "=" * 70)
        logger.info("PIPELINE STATISTICS")
        logger.info("=" * 70)
        logger.info(f"Total execution time: {duration:.2f} seconds ({duration/60:.2f} minutes)")
        logger.info(f"Records read: {self.stats['records_read']:,}")
        logger.info(f"Duplicates removed: {self.stats['duplicates_removed']:,}")
        logger.info(f"Invalid records: {self.stats['invalid_records']:,}")
        logger.info(f"Records after cleaning: {self.stats['records_after_cleaning']:,}")
        logger.info(f"Records written: {self.stats['records_written']:,}")
        
        if self.stats['records_read'] > 0:
            throughput = self.stats['records_read'] / duration
            logger.info(f"Throughput: {throughput:,.0f} records/second")
        
        logger.info("=" * 70)


def main():
    parser = argparse.ArgumentParser(description='Banking Transactions ETL Pipeline')
    parser.add_argument('--input', type=str, required=True,
                       help='Input path (local or MinIO)')
    parser.add_argument('--output', type=str, required=True,
                       help='Output path for processed data')
    parser.add_argument('--load-db', action='store_true',
                       help='Load data to PostgreSQL')
    parser.add_argument('--no-aggregations', action='store_true',
                       help='Skip creating aggregations')
    
    args = parser.parse_args()
    
    # Initialize and run pipeline
    pipeline = BankingETLPipeline()
    pipeline.run_pipeline(
        input_path=args.input,
        output_path=args.output,
        load_to_db=args.load_db,
        create_aggregations=not args.no_aggregations
    )


if __name__ == '__main__':
    main()
