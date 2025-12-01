-- Create Banking Transactions Database
-- Alternative to Amazon Redshift

-- ================================================
-- DATABASE SETUP
-- ================================================

-- Create database
DROP DATABASE IF EXISTS banking_transactions;
CREATE DATABASE banking_transactions
    WITH 
    ENCODING = 'UTF8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

\c banking_transactions

-- Enable extensions for performance and analytics
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS btree_gin;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ================================================
-- FACT TABLE - Transactions
-- ================================================

-- Main transactions fact table (partitioned by date)
CREATE TABLE IF NOT EXISTS transactions_fact (
    transaction_id VARCHAR(50) PRIMARY KEY,
    transaction_date DATE NOT NULL,
    transaction_timestamp TIMESTAMP NOT NULL,
    customer_id VARCHAR(50) NOT NULL,
    transaction_type VARCHAR(50) NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'EUR',
    status VARCHAR(20) NOT NULL,
    merchant_id VARCHAR(50),
    merchant_name VARCHAR(255),
    merchant_category VARCHAR(100),
    country VARCHAR(3),
    channel VARCHAR(20),
    card_type VARCHAR(20),
    is_fraudulent BOOLEAN DEFAULT FALSE,
    processing_time_ms INTEGER,
    -- Derived columns
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    day INTEGER NOT NULL,
    day_of_week INTEGER,
    hour INTEGER,
    amount_category VARCHAR(20),
    time_of_day VARCHAR(20),
    daily_transaction_count INTEGER,
    daily_cumulative_amount DECIMAL(15, 2),
    is_high_risk BOOLEAN DEFAULT FALSE,
    -- ETL metadata
    etl_processed_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    etl_job_id VARCHAR(100)
) PARTITION BY RANGE (transaction_date);

-- Create partitions for last 12 months (extend as needed)
-- This dramatically improves query performance

-- 2024 partitions
CREATE TABLE IF NOT EXISTS transactions_fact_2024_01 PARTITION OF transactions_fact
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE IF NOT EXISTS transactions_fact_2024_02 PARTITION OF transactions_fact
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

CREATE TABLE IF NOT EXISTS transactions_fact_2024_03 PARTITION OF transactions_fact
    FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');

CREATE TABLE IF NOT EXISTS transactions_fact_2024_04 PARTITION OF transactions_fact
    FOR VALUES FROM ('2024-04-01') TO ('2024-05-01');

CREATE TABLE IF NOT EXISTS transactions_fact_2024_05 PARTITION OF transactions_fact
    FOR VALUES FROM ('2024-05-01') TO ('2024-06-01');

CREATE TABLE IF NOT EXISTS transactions_fact_2024_06 PARTITION OF transactions_fact
    FOR VALUES FROM ('2024-06-01') TO ('2024-07-01');

CREATE TABLE IF NOT EXISTS transactions_fact_2024_07 PARTITION OF transactions_fact
    FOR VALUES FROM ('2024-07-01') TO ('2024-08-01');

CREATE TABLE IF NOT EXISTS transactions_fact_2024_08 PARTITION OF transactions_fact
    FOR VALUES FROM ('2024-08-01') TO ('2024-09-01');

CREATE TABLE IF NOT EXISTS transactions_fact_2024_09 PARTITION OF transactions_fact
    FOR VALUES FROM ('2024-09-01') TO ('2024-10-01');

CREATE TABLE IF NOT EXISTS transactions_fact_2024_10 PARTITION OF transactions_fact
    FOR VALUES FROM ('2024-10-01') TO ('2024-11-01');

CREATE TABLE IF NOT EXISTS transactions_fact_2024_11 PARTITION OF transactions_fact
    FOR VALUES FROM ('2024-11-01') TO ('2024-12-01');

CREATE TABLE IF NOT EXISTS transactions_fact_2024_12 PARTITION OF transactions_fact
    FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');

-- 2025 partitions
CREATE TABLE IF NOT EXISTS transactions_fact_2025_01 PARTITION OF transactions_fact
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE IF NOT EXISTS transactions_fact_2025_02 PARTITION OF transactions_fact
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

CREATE TABLE IF NOT EXISTS transactions_fact_2025_03 PARTITION OF transactions_fact
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');

-- ================================================
-- DIMENSION TABLES
-- ================================================

-- Customer dimension
CREATE TABLE IF NOT EXISTS customers_dim (
    customer_id VARCHAR(50) PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(50),
    country VARCHAR(3),
    city VARCHAR(100),
    account_created DATE,
    account_type VARCHAR(20),
    risk_score DECIMAL(5, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Merchant dimension
CREATE TABLE IF NOT EXISTS merchants_dim (
    merchant_id VARCHAR(50) PRIMARY KEY,
    merchant_name VARCHAR(255),
    category VARCHAR(100),
    country VARCHAR(3),
    mcc_code INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Transaction type dimension
CREATE TABLE IF NOT EXISTS transaction_types_dim (
    transaction_type VARCHAR(50) PRIMARY KEY,
    description TEXT,
    category VARCHAR(50),
    risk_level VARCHAR(20)
);

-- ================================================
-- AGGREGATION TABLES (Materialized Views)
-- ================================================

-- Daily summary per customer
CREATE TABLE IF NOT EXISTS daily_transaction_summary (
    customer_id VARCHAR(50) NOT NULL,
    transaction_date DATE NOT NULL,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    day INTEGER NOT NULL,
    transaction_count BIGINT,
    total_amount DECIMAL(15, 2),
    avg_amount DECIMAL(15, 2),
    min_amount DECIMAL(15, 2),
    max_amount DECIMAL(15, 2),
    unique_merchants BIGINT,
    fraud_count BIGINT,
    completed_count BIGINT,
    failed_count BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (customer_id, transaction_date)
) PARTITION BY RANGE (transaction_date);

-- Create partitions for daily summary
CREATE TABLE IF NOT EXISTS daily_summary_2024_12 PARTITION OF daily_transaction_summary
    FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');

CREATE TABLE IF NOT EXISTS daily_summary_2025_01 PARTITION OF daily_transaction_summary
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE IF NOT EXISTS daily_summary_2025_02 PARTITION OF daily_transaction_summary
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

CREATE TABLE IF NOT EXISTS daily_summary_2025_03 PARTITION OF daily_transaction_summary
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');

-- Merchant daily summary
CREATE TABLE IF NOT EXISTS merchant_daily_summary (
    merchant_id VARCHAR(50) NOT NULL,
    transaction_date DATE NOT NULL,
    merchant_name VARCHAR(255),
    merchant_category VARCHAR(100),
    transaction_count BIGINT,
    total_revenue DECIMAL(15, 2),
    avg_transaction DECIMAL(15, 2),
    unique_customers BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (merchant_id, transaction_date)
);

-- ================================================
-- COMMENTS
-- ================================================

COMMENT ON TABLE transactions_fact IS 'Main fact table for banking transactions - partitioned by date for performance';
COMMENT ON TABLE customers_dim IS 'Customer dimension table';
COMMENT ON TABLE merchants_dim IS 'Merchant dimension table';
COMMENT ON TABLE daily_transaction_summary IS 'Daily aggregated transaction metrics per customer';
COMMENT ON TABLE merchant_daily_summary IS 'Daily aggregated revenue metrics per merchant';

-- ================================================
-- GRANT PERMISSIONS
-- ================================================

-- Grant access to postgres user (adjust as needed)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

-- ================================================
-- INSERT REFERENCE DATA
-- ================================================

INSERT INTO transaction_types_dim (transaction_type, description, category, risk_level) VALUES
('PAYMENT', 'Card payment', 'PAYMENT', 'LOW'),
('TRANSFER', 'Bank transfer', 'TRANSFER', 'MEDIUM'),
('WITHDRAWAL', 'ATM withdrawal', 'CASH', 'LOW'),
('DEPOSIT', 'Cash deposit', 'CASH', 'LOW'),
('MOBILE_PAYMENT', 'Mobile payment', 'PAYMENT', 'MEDIUM'),
('DIRECT_DEBIT', 'Direct debit', 'PAYMENT', 'LOW'),
('CHECK', 'Check payment', 'PAYMENT', 'MEDIUM'),
('ONLINE_PURCHASE', 'Online purchase', 'PAYMENT', 'MEDIUM')
ON CONFLICT (transaction_type) DO NOTHING;

-- ================================================
-- COMPLETION MESSAGE
-- ================================================

\echo '========================================='
\echo 'Banking Transactions Database Created!'
\echo '========================================='
\echo 'Tables created:'
\echo '  - transactions_fact (partitioned)'
\echo '  - customers_dim'
\echo '  - merchants_dim'
\echo '  - transaction_types_dim'
\echo '  - daily_transaction_summary (partitioned)'
\echo '  - merchant_daily_summary'
\echo ''
\echo 'Next: Run create_indexes.sql to create indexes'
\echo '========================================='
