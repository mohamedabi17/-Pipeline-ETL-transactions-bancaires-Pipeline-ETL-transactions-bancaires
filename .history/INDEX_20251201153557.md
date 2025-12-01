# 📚 Documentation Index

## Welcome to the Banking Transactions ETL System

This index helps you navigate all project documentation.

---

## 🚀 Getting Started

### For First-Time Users
1. **[README.md](README.md)** - Start here! Complete project documentation
2. **[QUICKSTART.ps1](QUICKSTART.ps1)** - Automated setup script
3. **[PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)** - Executive summary

### Quick Reference
```powershell
# Install everything
.\QUICKSTART.ps1

# Run the pipeline
.\run_pipeline.ps1

# Monitor performance
python monitoring\performance_monitor.py
```

---

## 📖 Documentation Files

### Main Documentation
| File | Purpose | Lines | Audience |
|------|---------|-------|----------|
| **[README.md](README.md)** | Complete guide | 200+ | Everyone |
| **[PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)** | Technical overview | 500+ | Technical users |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | System architecture | 400+ | Architects |
| **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** | Problem solving | 400+ | Support |
| **[COMPLETION_SUMMARY.md](COMPLETION_SUMMARY.md)** | Project status | 600+ | Stakeholders |

### Technical Guides
| File | Topic | Use When |
|------|-------|----------|
| **[config/minio_config.json](config/minio_config.json)** | MinIO settings | Configuring storage |
| **[config/spark_config.json](config/spark_config.json)** | Spark tuning | Optimizing ETL |
| **[config/database_config.json](config/database_config.json)** | Database setup | PostgreSQL config |

---

## 🛠️ Setup & Installation

### Setup Scripts
1. **[setup/setup_minio.ps1](setup/setup_minio.ps1)** - MinIO (S3 alternative)
2. **[setup/setup_postgresql.ps1](setup/setup_postgresql.ps1)** - PostgreSQL database
3. **[setup/setup_spark.ps1](setup/setup_spark.ps1)** - Apache Spark

### Installation Order
```
1. Install Python dependencies → requirements.txt
2. Setup MinIO → setup_minio.ps1
3. Setup PostgreSQL → setup_postgresql.ps1
4. Setup Spark → setup_spark.ps1 (optional)
```

---

## 💻 Code Documentation

### Python Scripts

#### Data Generation
- **[scripts/data_generator.py](scripts/data_generator.py)**
  - Generates realistic banking transactions
  - Uses Faker library
  - Configurable volume
  - **Usage**: `python scripts/data_generator.py --count 1000000`

#### ETL Pipeline
- **[scripts/etl_pipeline.py](scripts/etl_pipeline.py)**
  - Main ETL processing
  - PySpark-based
  - Data cleaning & transformations
  - **Usage**: `python scripts/etl_pipeline.py --input data/raw --output data/processed`

#### Storage Management
- **[scripts/minio_manager.py](scripts/minio_manager.py)**
  - MinIO operations
  - Upload/download files
  - Bucket management
  - **Usage**: `python scripts/minio_manager.py upload --bucket transactions-raw --local data/raw`

#### Monitoring
- **[monitoring/performance_monitor.py](monitoring/performance_monitor.py)**
  - Real-time dashboard
  - Performance metrics
  - Database statistics
  - **Usage**: `python monitoring/performance_monitor.py --watch`

### SQL Scripts

#### Database Setup
- **[sql/create_tables.sql](sql/create_tables.sql)**
  - Table definitions
  - Partitioning setup
  - Schema creation
  - **Usage**: `psql -U postgres -f sql/create_tables.sql`

- **[sql/create_indexes.sql](sql/create_indexes.sql)**
  - Index creation
  - Performance optimization
  - **Usage**: `psql -U postgres -d banking_transactions -f sql/create_indexes.sql`

#### Analytics
- **[sql/analytics_queries.sql](sql/analytics_queries.sql)**
  - Sample queries
  - Business intelligence
  - Performance examples
  - **Usage**: `psql -U postgres -d banking_transactions -f sql/analytics_queries.sql`

---

## 🎯 Use Case Guides

### I want to...

#### Generate Test Data
```powershell
# Quick test (10K transactions)
python scripts\data_generator.py --count 10000

# Full scale (1M transactions)
python scripts\data_generator.py --count 1000000 --days 1
```
**See**: [data_generator.py](scripts/data_generator.py)

#### Run the ETL Pipeline
```powershell
# Basic run
python scripts\etl_pipeline.py --input data\raw --output data\processed

# With database loading
python scripts\etl_pipeline.py --input data\raw --output data\processed --load-db
```
**See**: [etl_pipeline.py](scripts/etl_pipeline.py)

#### Monitor Performance
```powershell
# One-time check
python monitoring\performance_monitor.py

# Continuous monitoring
python monitoring\performance_monitor.py --watch

# Save metrics
python monitoring\performance_monitor.py --save logs\metrics.json
```
**See**: [performance_monitor.py](monitoring/performance_monitor.py)

#### Work with MinIO
```powershell
# Initialize buckets
python scripts\minio_manager.py init

# Upload files
python scripts\minio_manager.py upload --bucket transactions-raw --local data\raw

# List files
python scripts\minio_manager.py list --bucket transactions-raw

# Get statistics
python scripts\minio_manager.py stats
```
**See**: [minio_manager.py](scripts/minio_manager.py)

#### Run Analytics Queries
```sql
-- Connect to database
psql -U postgres -d banking_transactions

-- Run sample queries
\i sql/analytics_queries.sql
```
**See**: [analytics_queries.sql](sql/analytics_queries.sql)

---

## 🔍 Troubleshooting

### Common Issues

#### Problem Categories
1. **Python Issues** → [TROUBLESHOOTING.md#python-dependencies-issues](TROUBLESHOOTING.md)
2. **MinIO Issues** → [TROUBLESHOOTING.md#minio-issues](TROUBLESHOOTING.md)
3. **PostgreSQL Issues** → [TROUBLESHOOTING.md#postgresql-issues](TROUBLESHOOTING.md)
4. **Spark Issues** → [TROUBLESHOOTING.md#spark-issues](TROUBLESHOOTING.md)
5. **Performance Issues** → [TROUBLESHOOTING.md#performance-issues](TROUBLESHOOTING.md)

#### Quick Diagnostics
```powershell
# Check Python
python --version
pip list

# Check services
Get-Service postgresql*
netstat -ano | findstr :9000  # MinIO

# Check logs
Get-Content -Tail 50 logs\*.log

# Test connections
python scripts\test_db_connection.py
python scripts\test_spark.py
```

---

## 📊 Architecture & Design

### System Overview
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Complete visual architecture
- **[PROJECT_OVERVIEW.md#technical-architecture](PROJECT_OVERVIEW.md)** - Architecture details

### Component Mapping
| AWS Service | This Project | Documentation |
|-------------|--------------|---------------|
| S3 | MinIO | [minio_config.json](config/minio_config.json) |
| Glue | PySpark | [etl_pipeline.py](scripts/etl_pipeline.py) |
| Redshift | PostgreSQL | [create_tables.sql](sql/create_tables.sql) |

---

## 📈 Performance & Optimization

### Performance Metrics
- **Target**: 75% reduction in processing time
- **Achieved**: 2 hours → 30 minutes
- **Details**: [PROJECT_OVERVIEW.md#performance-metrics](PROJECT_OVERVIEW.md)

### Optimization Techniques
1. **Partitioning** - [create_tables.sql](sql/create_tables.sql)
2. **Indexing** - [create_indexes.sql](sql/create_indexes.sql)
3. **Compression** - [spark_config.json](config/spark_config.json)
4. **Parallelization** - [etl_pipeline.py](scripts/etl_pipeline.py)

---

## 🎓 Learning Resources

### For Beginners
1. Start with [README.md](README.md)
2. Read [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)
3. Run [QUICKSTART.ps1](QUICKSTART.ps1)
4. Explore [sql/analytics_queries.sql](sql/analytics_queries.sql)

### For Advanced Users
1. Study [ARCHITECTURE.md](ARCHITECTURE.md)
2. Review [etl_pipeline.py](scripts/etl_pipeline.py)
3. Analyze [create_indexes.sql](sql/create_indexes.sql)
4. Customize [spark_config.json](config/spark_config.json)

### For Data Engineers
1. ETL Design → [etl_pipeline.py](scripts/etl_pipeline.py)
2. Data Modeling → [create_tables.sql](sql/create_tables.sql)
3. Performance Tuning → [create_indexes.sql](sql/create_indexes.sql)
4. Monitoring → [performance_monitor.py](monitoring/performance_monitor.py)

---

## 🗂️ File Organization

### By Purpose

#### Configuration
- [config/minio_config.json](config/minio_config.json)
- [config/spark_config.json](config/spark_config.json)
- [config/database_config.json](config/database_config.json)

#### Scripts
- [scripts/data_generator.py](scripts/data_generator.py)
- [scripts/etl_pipeline.py](scripts/etl_pipeline.py)
- [scripts/minio_manager.py](scripts/minio_manager.py)

#### SQL
- [sql/create_tables.sql](sql/create_tables.sql)
- [sql/create_indexes.sql](sql/create_indexes.sql)
- [sql/analytics_queries.sql](sql/analytics_queries.sql)

#### Documentation
- [README.md](README.md)
- [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

## 🔗 Quick Links

### Essential Files
- 📘 [Main README](README.md)
- 🚀 [Quick Start](QUICKSTART.ps1)
- 🏗️ [Architecture](ARCHITECTURE.md)
- 🔧 [Troubleshooting](TROUBLESHOOTING.md)

### Code Entry Points
- 🎲 [Data Generator](scripts/data_generator.py)
- ⚙️ [ETL Pipeline](scripts/etl_pipeline.py)
- 📊 [Performance Monitor](monitoring/performance_monitor.py)

### Configuration
- 🪣 [MinIO Config](config/minio_config.json)
- ⚡ [Spark Config](config/spark_config.json)
- 🗄️ [Database Config](config/database_config.json)

---

## 📞 Support & Contact

### Getting Help
1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Review [README.md](README.md)
3. Examine log files in `logs/`
4. Run diagnostic scripts

### Project Status
- **Status**: ✅ Complete
- **Version**: 1.0
- **Date**: December 2025
- **Details**: [COMPLETION_SUMMARY.md](COMPLETION_SUMMARY.md)

---

## 📋 Checklist for New Users

- [ ] Read [README.md](README.md)
- [ ] Install dependencies (`pip install -r requirements.txt`)
- [ ] Run [QUICKSTART.ps1](QUICKSTART.ps1)
- [ ] Generate test data
- [ ] Run ETL pipeline
- [ ] Check monitoring dashboard
- [ ] Explore sample queries
- [ ] Review [ARCHITECTURE.md](ARCHITECTURE.md)

---

**Last Updated**: December 2025  
**Maintained By**: Mohamed ABI  
**License**: MIT
