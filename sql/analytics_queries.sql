-- Sample Analytics Queries for Banking Transactions
-- Demonstrate the power of the optimized data warehouse

\c banking_transactions

-- ================================================
-- TRANSACTION VOLUME ANALYSIS
-- ================================================

-- Daily transaction volume trend
SELECT 
    transaction_date,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    AVG(amount) as avg_amount,
    COUNT(DISTINCT customer_id) as active_customers
FROM transactions_fact
WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY transaction_date
ORDER BY transaction_date DESC;

-- Hourly transaction pattern
SELECT 
    hour,
    COUNT(*) as transaction_count,
    AVG(amount) as avg_amount
FROM transactions_fact
WHERE transaction_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY hour
ORDER BY hour;

-- ================================================
-- CUSTOMER BEHAVIOR ANALYSIS
-- ================================================

-- Top 20 customers by transaction volume
SELECT 
    customer_id,
    COUNT(*) as transaction_count,
    SUM(amount) as total_spent,
    AVG(amount) as avg_transaction,
    COUNT(DISTINCT merchant_id) as unique_merchants,
    MAX(transaction_date) as last_transaction
FROM transactions_fact
WHERE status = 'COMPLETED'
GROUP BY customer_id
ORDER BY total_spent DESC
LIMIT 20;

-- Customer segmentation by spending
SELECT 
    CASE 
        WHEN total_spent < 1000 THEN 'Low Value'
        WHEN total_spent < 10000 THEN 'Medium Value'
        WHEN total_spent < 50000 THEN 'High Value'
        ELSE 'VIP'
    END as customer_segment,
    COUNT(DISTINCT customer_id) as customer_count,
    AVG(total_spent) as avg_total_spent,
    AVG(transaction_count) as avg_transactions
FROM (
    SELECT 
        customer_id,
        SUM(amount) as total_spent,
        COUNT(*) as transaction_count
    FROM transactions_fact
    WHERE status = 'COMPLETED'
    GROUP BY customer_id
) customer_stats
GROUP BY customer_segment
ORDER BY 
    CASE customer_segment
        WHEN 'VIP' THEN 1
        WHEN 'High Value' THEN 2
        WHEN 'Medium Value' THEN 3
        ELSE 4
    END;

-- ================================================
-- MERCHANT ANALYSIS
-- ================================================

-- Top merchants by revenue
SELECT 
    merchant_name,
    merchant_category,
    COUNT(*) as transaction_count,
    SUM(amount) as total_revenue,
    AVG(amount) as avg_transaction,
    COUNT(DISTINCT customer_id) as unique_customers
FROM transactions_fact
WHERE merchant_id IS NOT NULL
  AND status = 'COMPLETED'
GROUP BY merchant_name, merchant_category
ORDER BY total_revenue DESC
LIMIT 20;

-- Merchant category performance
SELECT 
    merchant_category,
    COUNT(*) as transaction_count,
    SUM(amount) as total_revenue,
    AVG(amount) as avg_transaction,
    COUNT(DISTINCT merchant_id) as merchant_count,
    COUNT(DISTINCT customer_id) as customer_count
FROM transactions_fact
WHERE merchant_category IS NOT NULL
  AND status = 'COMPLETED'
GROUP BY merchant_category
ORDER BY total_revenue DESC;

-- ================================================
-- FRAUD DETECTION ANALYSIS
-- ================================================

-- Fraud statistics by transaction type
SELECT 
    transaction_type,
    COUNT(*) as total_transactions,
    SUM(CASE WHEN is_fraudulent THEN 1 ELSE 0 END) as fraud_count,
    ROUND(100.0 * SUM(CASE WHEN is_fraudulent THEN 1 ELSE 0 END) / COUNT(*), 2) as fraud_rate_pct,
    AVG(CASE WHEN is_fraudulent THEN amount END) as avg_fraud_amount
FROM transactions_fact
GROUP BY transaction_type
ORDER BY fraud_count DESC;

-- High risk transactions requiring review
SELECT 
    transaction_id,
    transaction_timestamp,
    customer_id,
    amount,
    transaction_type,
    merchant_name,
    CASE 
        WHEN is_fraudulent THEN 'Confirmed Fraud'
        WHEN amount > 10000 THEN 'High Amount'
        WHEN daily_transaction_count > 20 THEN 'High Frequency'
        ELSE 'Other Risk'
    END as risk_reason
FROM transactions_fact
WHERE is_high_risk = TRUE
  AND transaction_date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY amount DESC
LIMIT 50;

-- ================================================
-- CHANNEL PERFORMANCE
-- ================================================

-- Transaction volume by channel
SELECT 
    channel,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    AVG(amount) as avg_amount,
    SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) as successful,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed,
    ROUND(100.0 * SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) / COUNT(*), 2) as success_rate_pct
FROM transactions_fact
WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY channel
ORDER BY transaction_count DESC;

-- ================================================
-- TIME-BASED PATTERNS
-- ================================================

-- Weekend vs Weekday comparison
SELECT 
    CASE WHEN day_of_week IN (1, 7) THEN 'Weekend' ELSE 'Weekday' END as period_type,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    AVG(amount) as avg_amount,
    COUNT(DISTINCT customer_id) as active_customers
FROM transactions_fact
WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY CASE WHEN day_of_week IN (1, 7) THEN 'Weekend' ELSE 'Weekday' END;

-- Peak transaction hours
SELECT 
    time_of_day,
    COUNT(*) as transaction_count,
    AVG(amount) as avg_amount,
    AVG(processing_time_ms) as avg_processing_ms
FROM transactions_fact
WHERE transaction_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY time_of_day
ORDER BY 
    CASE time_of_day
        WHEN 'MORNING' THEN 1
        WHEN 'AFTERNOON' THEN 2
        WHEN 'EVENING' THEN 3
        WHEN 'NIGHT' THEN 4
    END;

-- ================================================
-- PAYMENT METHOD ANALYSIS
-- ================================================

-- Card type distribution
SELECT 
    card_type,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    AVG(amount) as avg_amount,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as pct_of_total
FROM transactions_fact
WHERE card_type IS NOT NULL
  AND transaction_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY card_type
ORDER BY transaction_count DESC;

-- ================================================
-- GEOGRAPHIC ANALYSIS
-- ================================================

-- Transaction volume by country
SELECT 
    country,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    COUNT(DISTINCT customer_id) as unique_customers,
    AVG(amount) as avg_transaction
FROM transactions_fact
WHERE country IS NOT NULL
GROUP BY country
ORDER BY total_amount DESC
LIMIT 20;

-- ================================================
-- COHORT ANALYSIS
-- ================================================

-- Monthly cohort retention (customers who transact each month)
WITH monthly_customers AS (
    SELECT 
        DATE_TRUNC('month', transaction_date) as month,
        customer_id
    FROM transactions_fact
    WHERE status = 'COMPLETED'
    GROUP BY DATE_TRUNC('month', transaction_date), customer_id
)
SELECT 
    month,
    COUNT(DISTINCT customer_id) as active_customers,
    SUM(COUNT(DISTINCT customer_id)) OVER (ORDER BY month) as cumulative_customers
FROM monthly_customers
GROUP BY month
ORDER BY month DESC
LIMIT 12;

-- ================================================
-- PERFORMANCE BENCHMARKS
-- ================================================

-- Average processing time by transaction type
SELECT 
    transaction_type,
    AVG(processing_time_ms) as avg_processing_ms,
    MIN(processing_time_ms) as min_processing_ms,
    MAX(processing_time_ms) as max_processing_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY processing_time_ms) as p95_processing_ms
FROM transactions_fact
WHERE processing_time_ms IS NOT NULL
GROUP BY transaction_type
ORDER BY avg_processing_ms DESC;

-- ================================================
-- REAL-TIME MONITORING
-- ================================================

-- Transactions in the last hour
SELECT 
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    AVG(amount) as avg_amount,
    SUM(CASE WHEN is_fraudulent THEN 1 ELSE 0 END) as fraud_alerts,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed_transactions
FROM transactions_fact
WHERE transaction_timestamp >= NOW() - INTERVAL '1 hour';

-- Latest transactions
SELECT 
    transaction_id,
    transaction_timestamp,
    customer_id,
    transaction_type,
    amount,
    status,
    merchant_name
FROM transactions_fact
ORDER BY transaction_timestamp DESC
LIMIT 20;

-- ================================================
-- AGGREGATED VIEWS
-- ================================================

-- Use pre-computed daily summaries for faster queries
SELECT 
    customer_id,
    SUM(transaction_count) as total_transactions,
    SUM(total_amount) as total_spent,
    AVG(avg_amount) as avg_transaction,
    MAX(transaction_date) as last_transaction_date
FROM daily_transaction_summary
WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY customer_id
ORDER BY total_spent DESC
LIMIT 50;

\echo ''
\echo '========================================='
\echo 'Sample queries completed!'
\echo '========================================='
\echo 'These queries demonstrate:'
\echo '  ✓ Partitioning benefits (date-based queries)'
\echo '  ✓ Index usage (customer/merchant lookups)'
\echo '  ✓ Aggregation performance'
\echo '  ✓ Complex analytics patterns'
\echo '========================================='
