-- =============================================================================
-- File:        queries/advanced/01_window_functions_showcase.sql
-- Project:     Banking Transaction Analysis
-- Description: Comprehensive demonstration of all major SQL window functions
--              applied to banking scenarios — ranking, partitioning, running
--              aggregates, percentiles, and frame-based calculations.
-- Author:      Data Engineering Team
-- Date:        2026-10-28
-- Dialect:     Standard SQL (PostgreSQL-compatible; MySQL notes where needed)
-- =============================================================================


-- =============================================================================
-- 1. ROW_NUMBER: RANK TRANSACTIONS PER ACCOUNT BY AMOUNT
-- =============================================================================
-- BUSINESS CONTEXT: Assign a unique sequential rank to each transaction within
-- an account, ordered by amount descending. Useful for identifying the top-N
-- transactions per account (e.g., "show me each account's 3 largest txns").
-- Unlike RANK, ROW_NUMBER never produces ties — each row gets a distinct number.
-- =============================================================================

SELECT
    t.account_id,
    c.first_name || ' ' || c.last_name           AS customer_name,
    t.transaction_id,
    t.transaction_type,
    t.amount,
    t.transaction_date,
    ROW_NUMBER() OVER (
        PARTITION BY t.account_id
        ORDER BY     t.amount DESC
    )                                             AS txn_rank_by_amount
FROM
    transactions t
    JOIN accounts  a ON t.account_id  = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
WHERE
    t.status = 'Success'
ORDER BY
    t.account_id,
    txn_rank_by_amount;


-- =============================================================================
-- 2. RANK & DENSE_RANK: CUSTOMER RANKING BY TOTAL DEPOSITS (WITH TIES)
-- =============================================================================
-- BUSINESS CONTEXT: Rank customers by their total deposit volume to identify
-- top depositors for relationship management or AML review.
--   - RANK:       Leaves gaps after ties (1, 2, 2, 4)
--   - DENSE_RANK: No gaps (1, 2, 2, 3)
-- Both are shown side-by-side so analysts can choose the appropriate metric.
-- =============================================================================

WITH customer_deposits AS (
    SELECT
        c.customer_id,
        c.first_name || ' ' || c.last_name       AS customer_name,
        SUM(t.amount)                             AS total_deposits,
        COUNT(*)                                  AS deposit_count
    FROM
        transactions t
        JOIN accounts  a ON t.account_id  = a.account_id
        JOIN customers c ON a.customer_id = c.customer_id
    WHERE
        t.transaction_type = 'Deposit'
        AND t.status = 'Success'
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name
)
SELECT
    customer_id,
    customer_name,
    total_deposits,
    deposit_count,
    RANK()       OVER (ORDER BY total_deposits DESC) AS deposit_rank,
    DENSE_RANK() OVER (ORDER BY total_deposits DESC) AS deposit_dense_rank
FROM
    customer_deposits
ORDER BY
    deposit_rank;


-- =============================================================================
-- 3. NTILE: DIVIDE CUSTOMERS INTO QUARTILES BY ACCOUNT BALANCE
-- =============================================================================
-- BUSINESS CONTEXT: Segment the customer base into 4 equal groups (quartiles)
-- by their total account balance. This powers wealth-tier segmentation —
-- Q1 = top 25 % (high-net-worth), Q4 = bottom 25 %. Marketing, relationship
-- management, and risk teams use these tiers for targeted strategies.
-- =============================================================================

WITH customer_balances AS (
    SELECT
        c.customer_id,
        c.first_name || ' ' || c.last_name       AS customer_name,
        SUM(a.balance)                            AS total_balance,
        COUNT(a.account_id)                       AS num_accounts
    FROM
        customers c
        JOIN accounts a ON c.customer_id = a.customer_id
    WHERE
        a.status = 'Active'
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name
)
SELECT
    customer_id,
    customer_name,
    total_balance,
    num_accounts,
    NTILE(4) OVER (ORDER BY total_balance DESC)   AS balance_quartile,
    CASE NTILE(4) OVER (ORDER BY total_balance DESC)
        WHEN 1 THEN 'Platinum (Top 25%)'
        WHEN 2 THEN 'Gold (25-50%)'
        WHEN 3 THEN 'Silver (50-75%)'
        WHEN 4 THEN 'Bronze (Bottom 25%)'
    END                                           AS wealth_tier
FROM
    customer_balances
ORDER BY
    total_balance DESC;


-- =============================================================================
-- 4. LAG / LEAD: COMPARE EACH TRANSACTION WITH PREVIOUS AND NEXT
-- =============================================================================
-- BUSINESS CONTEXT: For each transaction on an account, show the previous and
-- next transaction amounts and dates. This enables:
--   - Detecting sudden spikes (current >> previous)
--   - Measuring inter-transaction gaps (time between successive txns)
--   - Identifying behavioural shifts for fraud or churn prediction
-- =============================================================================

SELECT
    t.account_id,
    t.transaction_id,
    t.transaction_type,
    t.amount                                      AS current_amount,
    t.transaction_date                            AS current_date,

    -- Previous transaction
    LAG(t.amount) OVER w                          AS prev_amount,
    LAG(t.transaction_date) OVER w                AS prev_date,
    t.amount - LAG(t.amount) OVER w               AS change_from_prev,

    -- Next transaction
    LEAD(t.amount) OVER w                         AS next_amount,
    LEAD(t.transaction_date) OVER w               AS next_date,

    -- Time gap to previous transaction
    t.transaction_date - LAG(t.transaction_date) OVER w
                                                  AS gap_from_prev
FROM
    transactions t
WHERE
    t.status = 'Success'
WINDOW
    w AS (PARTITION BY t.account_id ORDER BY t.transaction_date)
ORDER BY
    t.account_id,
    t.transaction_date;


-- =============================================================================
-- 5. FIRST_VALUE / LAST_VALUE: FIRST AND LAST TRANSACTION PER ACCOUNT
-- =============================================================================
-- BUSINESS CONTEXT: Knowing an account's first-ever and most recent
-- transaction helps with tenure analysis, dormancy detection, and lifecycle
-- understanding. FIRST_VALUE grabs the earliest; LAST_VALUE grabs the latest
-- (requires ROWS BETWEEN … to avoid the default frame ending at CURRENT ROW).
-- =============================================================================

SELECT DISTINCT
    t.account_id,
    c.first_name || ' ' || c.last_name           AS customer_name,

    -- First transaction details
    FIRST_VALUE(t.transaction_id) OVER w          AS first_txn_id,
    FIRST_VALUE(t.amount)         OVER w          AS first_txn_amount,
    FIRST_VALUE(t.transaction_date) OVER w        AS first_txn_date,
    FIRST_VALUE(t.transaction_type) OVER w        AS first_txn_type,

    -- Last transaction details (need full frame)
    LAST_VALUE(t.transaction_id)  OVER w_full     AS last_txn_id,
    LAST_VALUE(t.amount)          OVER w_full     AS last_txn_amount,
    LAST_VALUE(t.transaction_date) OVER w_full    AS last_txn_date,
    LAST_VALUE(t.transaction_type) OVER w_full    AS last_txn_type
FROM
    transactions t
    JOIN accounts  a ON t.account_id  = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
WHERE
    t.status = 'Success'
WINDOW
    w      AS (PARTITION BY t.account_id ORDER BY t.transaction_date),
    w_full AS (
        PARTITION BY t.account_id
        ORDER BY     t.transaction_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )
ORDER BY
    t.account_id;


-- =============================================================================
-- 6. SUM / AVG / COUNT OVER: RUNNING TOTALS AND MOVING AVERAGES
-- =============================================================================
-- BUSINESS CONTEXT: Running totals show cumulative balance impact over time.
-- Moving averages (e.g., 5-txn rolling average) smooth out noise to reveal
-- spending or deposit trends. These are essential for financial reporting,
-- statement generation, and trend analysis dashboards.
-- =============================================================================

SELECT
    t.account_id,
    t.transaction_id,
    t.transaction_type,
    t.amount,
    t.transaction_date,

    -- Running total of transaction amounts per account
    SUM(t.amount) OVER (
        PARTITION BY t.account_id
        ORDER BY     t.transaction_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                             AS running_total,

    -- Running count of transactions
    COUNT(*) OVER (
        PARTITION BY t.account_id
        ORDER BY     t.transaction_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                             AS running_count,

    -- 5-transaction moving average
    ROUND(
        AVG(t.amount) OVER (
            PARTITION BY t.account_id
            ORDER BY     t.transaction_date
            ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
        ), 2
    )                                             AS moving_avg_5txn,

    -- Cumulative average (expanding window)
    ROUND(
        AVG(t.amount) OVER (
            PARTITION BY t.account_id
            ORDER BY     t.transaction_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 2
    )                                             AS cumulative_avg
FROM
    transactions t
WHERE
    t.status = 'Success'
ORDER BY
    t.account_id,
    t.transaction_date;


-- =============================================================================
-- 7. PERCENT_RANK / CUME_DIST: PERCENTILE OF TRANSACTION AMOUNTS
-- =============================================================================
-- BUSINESS CONTEXT: Understanding where a transaction falls in the overall
-- distribution helps flag outliers.
--   - PERCENT_RANK: Relative rank as a percentage (0 to 1). A value of 0.95
--     means the amount is larger than 95 % of all transactions.
--   - CUME_DIST: Cumulative distribution — the fraction of rows with values
--     ≤ the current row's value.
-- Together they power percentile-based alerting (e.g., flag the top 1 %).
-- =============================================================================

SELECT
    t.transaction_id,
    t.account_id,
    t.transaction_type,
    t.amount,
    t.transaction_date,
    ROUND(
        PERCENT_RANK() OVER (ORDER BY t.amount)::numeric, 4
    )                                             AS pct_rank,
    ROUND(
        CUME_DIST()    OVER (ORDER BY t.amount)::numeric, 4
    )                                             AS cume_dist,
    CASE
        WHEN PERCENT_RANK() OVER (ORDER BY t.amount) >= 0.99
            THEN 'Top 1% — Review'
        WHEN PERCENT_RANK() OVER (ORDER BY t.amount) >= 0.95
            THEN 'Top 5%'
        WHEN PERCENT_RANK() OVER (ORDER BY t.amount) >= 0.75
            THEN 'Top 25%'
        ELSE 'Normal'
    END                                           AS percentile_tier
FROM
    transactions t
WHERE
    t.status = 'Success'
ORDER BY
    t.amount DESC;


-- =============================================================================
-- 8. RUNNING TOTAL WITH ROWS BETWEEN: CUMULATIVE DEPOSITS & WITHDRAWALS
-- =============================================================================
-- BUSINESS CONTEXT: A directional running total — cumulative deposits minus
-- cumulative withdrawals — effectively reconstructs the account balance over
-- time from the transaction log. This is invaluable for reconciliation,
-- statement generation, and detecting discrepancies between the computed
-- balance and the stored balance.
-- =============================================================================

SELECT
    t.account_id,
    t.transaction_id,
    t.transaction_type,
    t.amount,
    t.transaction_date,

    -- Signed amount: positive for deposits, negative for withdrawals
    CASE
        WHEN t.transaction_type = 'Deposit'    THEN  t.amount
        WHEN t.transaction_type = 'Withdrawal' THEN -t.amount
        ELSE 0
    END                                           AS signed_amount,

    -- Running balance from transaction history
    SUM(
        CASE
            WHEN t.transaction_type = 'Deposit'    THEN  t.amount
            WHEN t.transaction_type = 'Withdrawal' THEN -t.amount
            ELSE 0
        END
    ) OVER (
        PARTITION BY t.account_id
        ORDER BY     t.transaction_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                             AS computed_running_balance,

    -- Cumulative deposits only
    SUM(
        CASE WHEN t.transaction_type = 'Deposit' THEN t.amount ELSE 0 END
    ) OVER (
        PARTITION BY t.account_id
        ORDER BY     t.transaction_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                             AS cumulative_deposits,

    -- Cumulative withdrawals only
    SUM(
        CASE WHEN t.transaction_type = 'Withdrawal' THEN t.amount ELSE 0 END
    ) OVER (
        PARTITION BY t.account_id
        ORDER BY     t.transaction_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                             AS cumulative_withdrawals
FROM
    transactions t
WHERE
    t.status = 'Success'
ORDER BY
    t.account_id,
    t.transaction_date;


-- =============================================================================
-- END OF FILE: 01_window_functions_showcase.sql
-- =============================================================================
