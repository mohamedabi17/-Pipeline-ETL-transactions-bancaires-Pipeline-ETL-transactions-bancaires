# 🔧 Troubleshooting Guide

## Common Issues and Solutions

### 1. Python Dependencies Issues

#### Problem: `pip install` fails
```
ERROR: Could not install packages due to an EnvironmentError
```

**Solution:**
```powershell
# Upgrade pip first
python -m pip install --upgrade pip

# Install with user flag if permission denied
pip install --user -r requirements.txt

# Or create virtual environment
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

#### Problem: PySpark installation fails

**Solution:**
```powershell
# Ensure Java is installed first
java -version

# Install PySpark separately
pip install pyspark==3.5.0

# If still fails, install from wheel
pip install pyspark==3.5.0 --no-cache-dir
```

---

### 2. MinIO Issues

#### Problem: MinIO won't start

**Solution:**
```powershell
# Check if port 9000 is already in use
netstat -ano | findstr :9000

# Kill process if needed
taskkill /PID <process_id> /F

# Start MinIO on different port
.\minio.exe server .\data --address ":9001" --console-address ":9002"
```

#### Problem: Cannot create buckets

**Solution:**
```powershell
# Verify MinIO is running
curl http://localhost:9000

# Set alias correctly
mc alias set local http://localhost:9000 minioadmin minioadmin

# Check connection
mc admin info local
```

---

### 3. PostgreSQL Issues

#### Problem: Cannot connect to database

**Solution:**
```powershell
# Check PostgreSQL service is running
Get-Service postgresql*

# Start service if stopped
Start-Service postgresql-x64-14

# Verify connection with psql
psql -U postgres -d banking_transactions

# Check connection in config
# Edit config/database_config.json with correct credentials
```

#### Problem: Database doesn't exist

**Solution:**
```sql
-- Connect to postgres database first
psql -U postgres

-- Create database
CREATE DATABASE banking_transactions;

-- Run table creation script
\i sql/create_tables.sql
```

#### Problem: Permission denied errors

**Solution:**
```sql
-- Grant all privileges
GRANT ALL PRIVILEGES ON DATABASE banking_transactions TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
```

---

### 4. Spark Issues

#### Problem: `JAVA_HOME is not set`

**Solution:**
```powershell
# Download and install Java 11 or later
# https://adoptium.net/

# Set JAVA_HOME
$env:JAVA_HOME = "C:\Program Files\Java\jdk-11"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

# Verify
java -version
```

#### Problem: `winutils.exe` error on Windows

**Solution:**
```powershell
# Download winutils.exe
# https://github.com/steveloughran/winutils

# Place in Hadoop bin directory
mkdir "$env:HADOOP_HOME\bin"
# Copy winutils.exe to $env:HADOOP_HOME\bin\

# Set permissions
$env:HADOOP_HOME = "C:\hadoop"
```

#### Problem: Spark runs out of memory

**Solution:**
```json
// Edit config/spark_config.json
{
  "spark": {
    "config": {
      "spark.driver.memory": "8g",      // Increase from 4g
      "spark.executor.memory": "8g",    // Increase from 4g
      "spark.sql.shuffle.partitions": "100"  // Reduce from 200
    }
  }
}
```

---

### 5. Data Generation Issues

#### Problem: Faker is slow or hangs

**Solution:**
```powershell
# Reduce transaction count for testing
python scripts\data_generator.py --count 10000 --days 1

# Use simpler locale
# Edit data_generator.py: Faker('en_US') instead of Faker('fr_FR')
```

#### Problem: Out of memory during generation

**Solution:**
```python
# Generate data in batches
python scripts\data_generator.py --count 100000 --days 1
# Repeat multiple times instead of generating all at once
```

---

### 6. ETL Pipeline Issues

#### Problem: Pipeline fails with "No such file or directory"

**Solution:**
```powershell
# Use absolute paths
python scripts\etl_pipeline.py `
  --input "C:\Users\mohamed abi\Desktop\aws transaction system\data\raw\*.csv" `
  --output "C:\Users\mohamed abi\Desktop\aws transaction system\data\processed"

# Or ensure working directory is correct
cd "C:\Users\mohamed abi\Desktop\aws transaction system"
```

#### Problem: "Table already exists" error

**Solution:**
```sql
-- Drop and recreate tables
DROP TABLE IF EXISTS transactions_fact CASCADE;

-- Or truncate existing data
TRUNCATE TABLE transactions_fact CASCADE;
```

#### Problem: Spark job takes too long

**Solution:**
```json
// Optimize Spark config
{
  "processing": {
    "batch_size": 50000,        // Reduce from 100000
    "num_partitions": 16,       // Increase from 8
    "cache_enabled": false      // Disable if memory limited
  }
}
```

---

### 7. Performance Monitoring Issues

#### Problem: `pg_stat_statements` extension not available

**Solution:**
```sql
-- Enable extension
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Add to postgresql.conf
shared_preload_libraries = 'pg_stat_statements'

-- Restart PostgreSQL service
```

#### Problem: Monitoring script fails to connect

**Solution:**
```powershell
# Verify credentials in config/database_config.json
# Test connection manually
python scripts\test_db_connection.py

# Check firewall allows connections
Test-NetConnection localhost -Port 5432
```

---

### 8. File Permission Issues

#### Problem: Permission denied when writing files

**Solution:**
```powershell
# Run PowerShell as Administrator
# Or change output directory to user folder

# Fix permissions
icacls "C:\Users\mohamed abi\Desktop\aws transaction system" /grant Users:F /t
```

---

### 9. Import Errors

#### Problem: `ModuleNotFoundError: No module named 'xyz'`

**Solution:**
```powershell
# Reinstall requirements
pip install -r requirements.txt --force-reinstall

# Check Python path
python -c "import sys; print(sys.path)"

# Install missing module individually
pip install <module_name>
```

---

### 10. Performance Issues

#### Problem: Queries are slow

**Solution:**
```sql
-- Update statistics
ANALYZE transactions_fact;

-- Rebuild indexes
REINDEX TABLE transactions_fact;

-- Check query plan
EXPLAIN ANALYZE SELECT * FROM transactions_fact WHERE customer_id = 'CUST00001234';

-- Add missing indexes
CREATE INDEX idx_custom ON transactions_fact (column_name);
```

#### Problem: Database is bloated

**Solution:**
```sql
-- Vacuum to reclaim space
VACUUM FULL ANALYZE transactions_fact;

-- Enable auto-vacuum
ALTER TABLE transactions_fact SET (
    autovacuum_enabled = true,
    autovacuum_vacuum_scale_factor = 0.1
);
```

---

## Diagnostic Commands

### Check System Resources
```powershell
# CPU and Memory
Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 10

# Disk space
Get-PSDrive C | Select-Object Used,Free

# Network connectivity
Test-NetConnection localhost -Port 9000  # MinIO
Test-NetConnection localhost -Port 5432  # PostgreSQL
```

### Check Services Status
```powershell
# PostgreSQL
Get-Service postgresql*

# Check if MinIO is running
Get-Process | Where-Object {$_.Name -like "*minio*"}
```

### Check Logs
```powershell
# View recent ETL logs
Get-Content -Tail 50 logs\etl_pipeline_*.log

# View error logs
Get-Content logs\*.log | Select-String "ERROR"
```

---

## Getting Help

### Debug Mode

Enable verbose logging:

```powershell
# Set environment variable
$env:LOGLEVEL = "DEBUG"

# Run with more output
python scripts\etl_pipeline.py --input data\raw --output data\processed --verbose
```

### Generate Diagnostic Report

```powershell
# Create diagnostic report
python monitoring\performance_monitor.py --save logs\diagnostic_report.json

# View system info
python -c "import psutil; print(psutil.virtual_memory()); print(psutil.cpu_count())"
```

---

## Quick Fixes Checklist

- [ ] Restart PostgreSQL service
- [ ] Restart MinIO server
- [ ] Clear temporary files in `data/staging/`
- [ ] Delete Spark checkpoints in `spark-warehouse/`
- [ ] Update statistics: `ANALYZE;`
- [ ] Vacuum database: `VACUUM ANALYZE;`
- [ ] Reinstall Python packages
- [ ] Check disk space
- [ ] Verify all config files are correct
- [ ] Review latest log files

---

## Still Having Issues?

1. **Check the logs** in `logs/` directory
2. **Review the configuration** files in `config/`
3. **Test components individually**:
   - Database: `python scripts\test_db_connection.py`
   - Spark: `python scripts\test_spark.py`
   - MinIO: `python scripts\minio_manager.py stats`
4. **Simplify the pipeline** - Use smaller dataset for testing
5. **Check system requirements** - Ensure enough RAM, disk space, CPU

---

## Prevention Tips

✅ **Always backup data** before major operations  
✅ **Test with small datasets** first  
✅ **Monitor resource usage** during pipeline execution  
✅ **Keep logs** for at least 7 days  
✅ **Document any custom changes** to configurations  
✅ **Use version control** for code changes  

---

**Last Updated**: December 2025
