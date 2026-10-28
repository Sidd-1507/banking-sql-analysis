-- =============================================================================
-- File:        queries/advanced/03_pivot_and_reporting.sql
-- Project:     Banking Transaction Analysis
-- Description: Pivot tables, cross-tabulations, year-over-year comparisons,
--              executive dashboards, and customer statement generation for
--              banking reporting and analytics.
-- Author:      Data Engineering Team
-- Date:        2026-10-28
-- Dialect:     Standard SQL (PostgreSQL-compatible; MySQL notes where needed)
-- =============================================================================


-- =============================================================================
-- 1. MONTHLY TRANSACTION PIVOT: ROWS = MONTHS, COLUMNS = TXN TYPE AMOUNTS
-- =============================================================================
-- BUSINESS CONTEXT: Finance and operations teams need a monthly breakdown of
-- transaction volumes by type (Deposit, Withdrawal, Transfer) in a
-- spreadsheet-friendly format. The CASE WHEN pivot converts row-level
-- transaction types into columns, enabling quick month-over-month comparisons.
-- This is the standard SQL pivot technique that works across all major RDBMS.
-- =============================================================================

SELECT
    TO_CHAR(t.transaction_date, 'YYYY-MM')        AS txn_month,

    -- Deposit metrics
    COUNT(CASE WHEN t.transaction_type = 'Deposit' THEN 1 END)
                                                  AS deposit_count,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'Deposit'
                      THEN t.amount END), 0)      AS deposit_amount,

    -- Withdrawal metrics
    COUNT(CASE WHEN t.transaction_type = 'Withdrawal' THEN 1 END)
                                                  AS withdrawal_count,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'Withdrawal'
                      THEN t.amount END), 0)      AS withdrawal_amount,

    -- Transfer metrics
    COUNT(CASE WHEN t.transaction_type = 'Transfer' THEN 1 END)
                                                  AS transfer_count,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'Transfer'
                      THEN t.amount END), 0)      AS transfer_amount,

    -- Totals
    COUNT(*)                                      AS total_txn_count,
    SUM(t.amount)                                 AS total_amount,

    -- Net flow (deposits - withdrawals)
    COALESCE(SUM(CASE WHEN t.transaction_type = 'Deposit'
                      THEN t.amount END), 0)
    - COALESCE(SUM(CASE WHEN t.transaction_type = 'Withdrawal'
                        THEN t.amount END), 0)    AS net_flow
FROM
    transactions t
WHERE
    t.status = 'Success'
GROUP BY
    TO_CHAR(t.transaction_date, 'YYYY-MM')
ORDER BY
    txn_month;


-- =============================================================================
-- 2. BRANCH × ACCOUNT TYPE CROSS-TAB
-- =============================================================================
-- BUSINESS CONTEXT: This cross-tabulation shows how accounts are distributed
-- across branches and account types. It helps regional managers understand
-- product mix at each branch, identify branches that are under-penetrated
-- for certain account types, and plan resource allocation (e.g., a branch
-- with many Current accounts may need more business banking staff).
-- =============================================================================

SELECT
    b.branch_name,
    b.branch_id,

    -- Account counts by type
    COUNT(CASE WHEN a.account_type = 'Savings' THEN 1 END)
                                                  AS savings_accounts,
    COUNT(CASE WHEN a.account_type = 'Current' THEN 1 END)
                                                  AS current_accounts,
    COUNT(CASE WHEN a.account_type = 'Salary'  THEN 1 END)
                                                  AS salary_accounts,
    COUNT(*)                                      AS total_accounts,

    -- Balance by type
    COALESCE(SUM(CASE WHEN a.account_type = 'Savings'
                      THEN a.balance END), 0)     AS savings_balance,
    COALESCE(SUM(CASE WHEN a.account_type = 'Current'
                      THEN a.balance END), 0)     AS current_balance,
    COALESCE(SUM(CASE WHEN a.account_type = 'Salary'
                      THEN a.balance END), 0)     AS salary_balance,
    SUM(a.balance)                                AS total_balance,

    -- Average balance by type
    ROUND(AVG(CASE WHEN a.account_type = 'Savings'
                   THEN a.balance END), 2)        AS avg_savings_balance,
    ROUND(AVG(CASE WHEN a.account_type = 'Current'
                   THEN a.balance END), 2)        AS avg_current_balance,

    -- Product mix percentage
    ROUND(
        COUNT(CASE WHEN a.account_type = 'Savings' THEN 1 END) * 100.0
        / NULLIF(COUNT(*), 0), 1
    )                                             AS savings_pct
FROM
    branches b
    LEFT JOIN accounts a ON b.branch_id = a.branch_id
WHERE
    a.status = 'Active' OR a.status IS NULL        -- include branches with no accounts
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY
    total_balance DESC;


-- =============================================================================
-- 3. YEAR-OVER-YEAR COMPARISON USING SELF-JOIN
-- =============================================================================
-- BUSINESS CONTEXT: Comparing this year's metrics against the previous year
-- reveals growth trends, seasonal patterns, and areas of concern. This self-
-- join approach pairs each month with the same month from the prior year,
-- computing absolute change and percentage growth. Essential for board reports,
-- investor presentations, and strategic planning.
-- =============================================================================

WITH monthly_metrics AS (
    SELECT
        EXTRACT(YEAR  FROM t.transaction_date)    AS txn_year,
        EXTRACT(MONTH FROM t.transaction_date)    AS txn_month,
        TO_CHAR(t.transaction_date, 'Month')      AS month_name,
        COUNT(*)                                  AS txn_count,
        SUM(t.amount)                             AS total_amount,
        COUNT(DISTINCT t.account_id)              AS active_accounts,
        ROUND(AVG(t.amount), 2)                   AS avg_txn_amount
    FROM
        transactions t
    WHERE
        t.status = 'Success'
    GROUP BY
        EXTRACT(YEAR  FROM t.transaction_date),
        EXTRACT(MONTH FROM t.transaction_date),
        TO_CHAR(t.transaction_date, 'Month')
)
SELECT
    curr.txn_year                                 AS current_year,
    curr.txn_month,
    TRIM(curr.month_name)                         AS month_name,

    -- Current year metrics
    curr.txn_count                                AS curr_txn_count,
    curr.total_amount                             AS curr_total_amount,
    curr.active_accounts                          AS curr_active_accounts,

    -- Previous year metrics
    prev.txn_count                                AS prev_txn_count,
    prev.total_amount                             AS prev_total_amount,
    prev.active_accounts                          AS prev_active_accounts,

    -- Absolute change
    curr.txn_count   - COALESCE(prev.txn_count, 0)
                                                  AS txn_count_change,
    curr.total_amount - COALESCE(prev.total_amount, 0)
                                                  AS amount_change,

    -- Percentage growth (YoY)
    CASE
        WHEN prev.txn_count IS NULL OR prev.txn_count = 0 THEN NULL
        ELSE ROUND(
            (curr.txn_count - prev.txn_count) * 100.0 / prev.txn_count, 2
        )
    END                                           AS txn_count_growth_pct,
    CASE
        WHEN prev.total_amount IS NULL OR prev.total_amount = 0 THEN NULL
        ELSE ROUND(
            (curr.total_amount - prev.total_amount) * 100.0 / prev.total_amount, 2
        )
    END                                           AS amount_growth_pct
FROM
    monthly_metrics curr
    LEFT JOIN monthly_metrics prev
        ON  prev.txn_year  = curr.txn_year - 1
        AND prev.txn_month = curr.txn_month
ORDER BY
    curr.txn_year DESC,
    curr.txn_month;


-- =============================================================================
-- 4. EXECUTIVE DASHBOARD: SINGLE QUERY RETURNING ALL CRITICAL KPIs
-- =============================================================================
-- BUSINESS CONTEXT: The C-suite needs a real-time, single-query snapshot of
-- the bank's operational health. This query computes 15+ KPIs in one pass
-- using subqueries and conditional aggregation — total customers, AUM, loan
-- exposure, card penetration, transaction health, and risk indicators. The
-- output can directly feed an executive BI dashboard.
-- =============================================================================

SELECT
    -- ===== CUSTOMER METRICS =====
    (SELECT COUNT(*)
     FROM   customers)                            AS total_customers,

    (SELECT COUNT(DISTINCT a.customer_id)
     FROM   accounts a
     WHERE  a.status = 'Active')                  AS customers_with_active_accounts,

    -- ===== ACCOUNT METRICS =====
    (SELECT COUNT(*)
     FROM   accounts
     WHERE  status = 'Active')                    AS active_accounts,

    (SELECT SUM(balance)
     FROM   accounts
     WHERE  status = 'Active')                    AS total_aum,
    -- AUM = Assets Under Management

    (SELECT ROUND(AVG(balance), 2)
     FROM   accounts
     WHERE  status = 'Active')                    AS avg_account_balance,

    -- ===== TRANSACTION METRICS (CURRENT MONTH) =====
    (SELECT COUNT(*)
     FROM   transactions
     WHERE  status = 'Success'
     AND    DATE_TRUNC('month', transaction_date) = DATE_TRUNC('month', CURRENT_DATE)
    )                                             AS current_month_txn_count,

    (SELECT COALESCE(SUM(amount), 0)
     FROM   transactions
     WHERE  status = 'Success'
     AND    DATE_TRUNC('month', transaction_date) = DATE_TRUNC('month', CURRENT_DATE)
    )                                             AS current_month_txn_volume,

    -- ===== TRANSACTION HEALTH =====
    (SELECT ROUND(
         COUNT(CASE WHEN status = 'Failed' THEN 1 END) * 100.0
         / NULLIF(COUNT(*), 0), 2
     )
     FROM   transactions
     WHERE  DATE_TRUNC('month', transaction_date) = DATE_TRUNC('month', CURRENT_DATE)
    )                                             AS current_month_failure_rate_pct,

    -- ===== LOAN METRICS =====
    (SELECT COUNT(*)
     FROM   loans
     WHERE  status = 'Active')                    AS active_loans,

    (SELECT COALESCE(SUM(loan_amount), 0)
     FROM   loans
     WHERE  status = 'Active')                    AS total_loan_exposure,

    -- ===== CARD METRICS =====
    (SELECT COUNT(*)
     FROM   cards
     WHERE  status = 'Active')                    AS active_cards,

    -- ===== RISK INDICATORS =====
    (SELECT COUNT(*)
     FROM   transactions
     WHERE  amount > 100000
     AND    status = 'Success'
     AND    transaction_date >= CURRENT_DATE - INTERVAL '7 days'
    )                                             AS high_value_txns_last_7_days,

    (SELECT COUNT(DISTINCT account_id)
     FROM   transactions
     WHERE  EXTRACT(HOUR FROM transaction_date) BETWEEN 0 AND 4
     AND    status = 'Success'
     AND    transaction_date >= CURRENT_DATE - INTERVAL '7 days'
    )                                             AS odd_hour_accounts_last_7_days,

    CURRENT_TIMESTAMP                             AS report_generated_at;


-- =============================================================================
-- 5. CUSTOMER STATEMENT GENERATOR: TRANSACTIONS WITH RUNNING BALANCE
-- =============================================================================
-- BUSINESS CONTEXT: Generate a complete account statement for a given customer
-- and date range, including a running balance after each transaction. This
-- mirrors what customers see in their bank statements. The running balance
-- adds deposits and subtracts withdrawals chronologically, starting from
-- the account's opening balance (or computed from prior transactions).
--
-- Parameters to replace:
--   :p_account_id  → target account ID
--   :p_start_date  → statement start date
--   :p_end_date    → statement end date
-- =============================================================================

WITH account_info AS (
    -- Get account metadata and opening/prior balance
    SELECT
        a.account_id,
        a.account_type,
        a.opening_date,
        a.balance                                 AS current_balance,
        c.first_name || ' ' || c.last_name        AS customer_name,
        c.customer_id,
        b.branch_name,
        -- Compute balance at start of statement period
        -- (current balance minus all txns from start_date onward)
        a.balance - COALESCE(
            (SELECT SUM(
                CASE
                    WHEN t2.transaction_type = 'Deposit'    THEN  t2.amount
                    WHEN t2.transaction_type = 'Withdrawal' THEN -t2.amount
                    ELSE 0
                END
             )
             FROM transactions t2
             WHERE t2.account_id = a.account_id
             AND   t2.status = 'Success'
             AND   t2.transaction_date >= :p_start_date
            ), 0
        )                                         AS opening_balance_for_period
    FROM
        accounts  a
        JOIN customers c ON a.customer_id = c.customer_id
        JOIN branches  b ON a.branch_id   = b.branch_id
    WHERE
        a.account_id = :p_account_id
),
statement_txns AS (
    -- All transactions in the date range
    SELECT
        t.transaction_id,
        t.transaction_date,
        t.transaction_type,
        t.amount,
        t.channel,
        t.status,
        CASE
            WHEN t.transaction_type = 'Deposit'    THEN  t.amount
            WHEN t.transaction_type = 'Withdrawal' THEN -t.amount
            ELSE 0
        END                                       AS signed_amount
    FROM
        transactions t
    WHERE
        t.account_id = :p_account_id
        AND t.status = 'Success'
        AND t.transaction_date BETWEEN :p_start_date AND :p_end_date
)
-- Final statement output
SELECT
    -- Statement header (repeated on every row for simplicity; BI tools can extract)
    ai.customer_name,
    ai.account_id,
    ai.account_type,
    ai.branch_name,
    :p_start_date                                 AS statement_from,
    :p_end_date                                   AS statement_to,
    ai.opening_balance_for_period,

    -- Transaction details
    st.transaction_id,
    st.transaction_date,
    st.transaction_type,
    CASE
        WHEN st.transaction_type = 'Deposit' THEN st.amount
        ELSE NULL
    END                                           AS credit,
    CASE
        WHEN st.transaction_type = 'Withdrawal' THEN st.amount
        ELSE NULL
    END                                           AS debit,
    st.channel,

    -- Running balance
    ai.opening_balance_for_period + SUM(st.signed_amount) OVER (
        ORDER BY st.transaction_date, st.transaction_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                             AS running_balance
FROM
    account_info   ai
    CROSS JOIN statement_txns st
ORDER BY
    st.transaction_date,
    st.transaction_id;


-- =============================================================================
-- END OF FILE: 03_pivot_and_reporting.sql
-- =============================================================================
