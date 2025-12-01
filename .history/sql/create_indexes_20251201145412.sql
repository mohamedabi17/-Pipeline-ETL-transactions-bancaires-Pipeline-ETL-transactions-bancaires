-- Create Indexes for Banking Transactions Database
-- Optimized for analytical queries (Redshift-like optimizations)

\c banking_transactions

-- ================================================
-- TRANSACTIONS FACT TABLE INDEXES
-- ================================================

\echo 'Creating indexes on transactions_fact...'

-- Primary access patterns
CREATE INDEX IF NOT EXISTS idx_transaction_date 
    ON transactions_fact (transaction_date DESC);

CREATE INDEX IF NOT EXISTS idx_customer_id 
    ON transactions_fact (customer_id);

CREATE INDEX IF NOT EXISTS idx_merchant_id 
    ON transactions_fact (merchant_id) 
    WHERE merchant_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_transaction_timestamp 
    ON transactions_fact (transaction_timestamp DESC);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_customer_date 
    ON transactions_fact (customer_id, transaction_date DESC);

CREATE INDEX IF NOT EXISTS idx_merchant_date 
    ON transactions_fact (merchant_id, transaction_date DESC) 
    WHERE merchant_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_date_type 
    ON transactions_fact (transaction_date, transaction_type);

-- Amount-based queries
CREATE INDEX IF NOT EXISTS idx_amount 
    ON transactions_fact (amount DESC);

CREATE INDEX IF NOT EXISTS idx_amount_range 
    ON transactions_fact (transaction_date, amount) 
    WHERE amount > 1000;

-- Status and fraud detection
CREATE INDEX IF NOT EXISTS idx_status 
    ON transactions_fact (status) 
    WHERE status != 'COMPLETED';

CREATE INDEX IF NOT EXISTS idx_fraudulent 
    ON transactions_fact (transaction_date, is_fraudulent) 
    WHERE is_fraudulent = TRUE;

CREATE INDEX IF NOT EXISTS idx_high_risk 
    ON transactions_fact (transaction_date, is_high_risk) 
    WHERE is_high_risk = TRUE;

-- Channel and type analysis
CREATE INDEX IF NOT EXISTS idx_channel 
    ON transactions_fact (channel, transaction_date);

CREATE INDEX IF NOT EXISTS idx_transaction_type 
    ON transactions_fact (transaction_type, transaction_date);

-- Geographic analysis
CREATE INDEX IF NOT EXISTS idx_country 
    ON transactions_fact (country, transaction_date);

-- Time-based analysis
CREATE INDEX IF NOT EXISTS idx_year_month 
    ON transactions_fact (year, month);

CREATE INDEX IF NOT EXISTS idx_hour 
    ON transactions_fact (hour);

-- Partial index for large transactions
CREATE INDEX IF NOT EXISTS idx_large_transactions 
    ON transactions_fact (customer_id, amount, transaction_date) 
    WHERE amount > 5000;

-- GIN index for full-text search on merchant names (if needed)
CREATE INDEX IF NOT EXISTS idx_merchant_name_gin 
    ON transactions_fact USING gin (merchant_name gin_trgm_ops) 
    WHERE merchant_name IS NOT NULL;

-- ================================================
-- DIMENSION TABLES INDEXES
-- ================================================

\echo 'Creating indexes on dimension tables...'

-- Customers
CREATE INDEX IF NOT EXISTS idx_customer_email 
    ON customers_dim (email);

CREATE INDEX IF NOT EXISTS idx_customer_country 
    ON customers_dim (country);

CREATE INDEX IF NOT EXISTS idx_customer_type 
    ON customers_dim (account_type);

CREATE INDEX IF NOT EXISTS idx_customer_risk 
    ON customers_dim (risk_score DESC);

CREATE INDEX IF NOT EXISTS idx_customer_created 
    ON customers_dim (account_created DESC);

-- Merchants
CREATE INDEX IF NOT EXISTS idx_merchant_name 
    ON merchants_dim (merchant_name);

CREATE INDEX IF NOT EXISTS idx_merchant_category 
    ON merchants_dim (category);

CREATE INDEX IF NOT EXISTS idx_merchant_country 
    ON merchants_dim (country);

CREATE INDEX IF NOT EXISTS idx_merchant_mcc 
    ON merchants_dim (mcc_code);

-- Full-text search on merchant names
CREATE INDEX IF NOT EXISTS idx_merchant_name_trgm 
    ON merchants_dim USING gin (merchant_name gin_trgm_ops);

-- ================================================
-- AGGREGATION TABLES INDEXES
-- ================================================

\echo 'Creating indexes on aggregation tables...'

-- Daily summary
CREATE INDEX IF NOT EXISTS idx_daily_summary_date 
    ON daily_transaction_summary (transaction_date DESC);

CREATE INDEX IF NOT EXISTS idx_daily_summary_customer 
    ON daily_transaction_summary (customer_id, transaction_date DESC);

CREATE INDEX IF NOT EXISTS idx_daily_summary_amount 
    ON daily_transaction_summary (total_amount DESC);

CREATE INDEX IF NOT EXISTS idx_daily_summary_year_month 
    ON daily_transaction_summary (year, month);

-- Merchant summary
CREATE INDEX IF NOT EXISTS idx_merchant_summary_date 
    ON merchant_daily_summary (transaction_date DESC);

CREATE INDEX IF NOT EXISTS idx_merchant_summary_revenue 
    ON merchant_daily_summary (total_revenue DESC);

CREATE INDEX IF NOT EXISTS idx_merchant_summary_merchant 
    ON merchant_daily_summary (merchant_id, transaction_date DESC);

-- ================================================
-- CLUSTERING (similar to Redshift sort keys)
-- ================================================

\echo 'Setting table clustering...'

-- Cluster tables for better query performance
CLUSTER transactions_fact USING idx_transaction_date;
CLUSTER customers_dim USING customers_dim_pkey;
CLUSTER merchants_dim USING merchants_dim_pkey;
CLUSTER daily_transaction_summary USING idx_daily_summary_date;
CLUSTER merchant_daily_summary USING idx_merchant_summary_date;

-- ================================================
-- STATISTICS UPDATE
-- ================================================

\echo 'Updating table statistics...'

-- Update statistics for query planner
ANALYZE transactions_fact;
ANALYZE customers_dim;
ANALYZE merchants_dim;
ANALYZE transaction_types_dim;
ANALYZE daily_transaction_summary;
ANALYZE merchant_daily_summary;

-- ================================================
-- VACUUM
-- ================================================

\echo 'Running VACUUM...'

-- Reclaim space and update visibility map
VACUUM ANALYZE transactions_fact;
VACUUM ANALYZE customers_dim;
VACUUM ANALYZE merchants_dim;
VACUUM ANALYZE daily_transaction_summary;
VACUUM ANALYZE merchant_daily_summary;

-- ================================================
-- PERFORMANCE SETTINGS
-- ================================================

\echo 'Applying performance settings...'

-- Set parallel workers for large scans
ALTER TABLE transactions_fact SET (parallel_workers = 4);
ALTER TABLE daily_transaction_summary SET (parallel_workers = 2);

-- Set fillfactor for tables with updates
ALTER TABLE customers_dim SET (fillfactor = 90);
ALTER TABLE merchants_dim SET (fillfactor = 90);

-- Enable auto-vacuum for all tables
ALTER TABLE transactions_fact SET (
    autovacuum_enabled = true,
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

ALTER TABLE daily_transaction_summary SET (
    autovacuum_enabled = true,
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

-- ================================================
-- INDEX SUMMARY
-- ================================================

\echo ''
\echo '========================================='
\echo 'Indexes Created Successfully!'
\echo '========================================='

-- Show all indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_indexes 
JOIN pg_class ON indexname = relname
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

\echo ''
\echo 'Performance Optimizations Applied:'
\echo '  ✓ B-tree indexes on primary access columns'
\echo '  ✓ Composite indexes for common query patterns'
\echo '  ✓ Partial indexes for filtered queries'
\echo '  ✓ GIN indexes for full-text search'
\echo '  ✓ Table clustering for sequential access'
\echo '  ✓ Statistics updated for query planner'
\echo '  ✓ Parallel workers configured'
\echo '  ✓ Auto-vacuum enabled'
\echo ''
\echo 'Database is now optimized for analytical queries!'
\echo '========================================='
