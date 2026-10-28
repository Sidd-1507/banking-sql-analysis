-- =============================================================================
-- File:        queries/advanced/02_cte_and_subqueries.sql
-- Project:     Banking Transaction Analysis
-- Description: Advanced CTE patterns (recursive, chained, multi-level),
--              correlated subqueries, EXISTS/NOT EXISTS checks, lateral joins,
--              and UNION-based dashboard queries for banking analytics.
-- Author:      Data Engineering Team
-- Date:        2026-10-28
-- Dialect:     Standard SQL (PostgreSQL-compatible; MySQL notes where needed)
-- =============================================================================


-- =============================================================================
-- 1. RECURSIVE CTE: GENERATE A DATE CALENDAR FOR GAP ANALYSIS
-- =============================================================================
-- BUSINESS CONTEXT: Many reports require a continuous date spine so that days
-- with zero transactions still appear (showing 0 rather than a missing row).
-- This recursive CTE generates every date in a given range. We then LEFT JOIN
-- transactions to it to identify "gap days" where no activity occurred —
-- critical for dormancy detection and SLA compliance reporting.
-- =============================================================================

WITH RECURSIVE date_calendar AS (
    -- Anchor: start of the desired date range
    SELECT DATE '2024-01-01' AS cal_date

    UNION ALL

    -- Recursive member: add one day until we reach the end date
    SELECT cal_date + INTERVAL '1 day'
    FROM   date_calendar
    WHERE  cal_date < DATE '2024-12-31'
)
SELECT
    dc.cal_date,
    EXTRACT(DOW  FROM dc.cal_date)                AS day_of_week,
    -- 0 = Sunday, 6 = Saturday (PostgreSQL)
    CASE
        WHEN EXTRACT(DOW FROM dc.cal_date) IN (0, 6) THEN 'Weekend'
        ELSE 'Weekday'
    END                                           AS day_type,
    COALESCE(txn_summary.txn_count, 0)            AS transaction_count,
    COALESCE(txn_summary.total_amount, 0)         AS total_amount,
    CASE
        WHEN txn_summary.txn_count IS NULL THEN 'NO ACTIVITY'
        ELSE 'ACTIVE'
    END                                           AS activity_status
FROM
    date_calendar dc
    LEFT JOIN (
        SELECT
            transaction_date::date                AS txn_date,
            COUNT(*)                              AS txn_count,
            SUM(amount)                           AS total_amount
        FROM
            transactions
        WHERE
            status = 'Success'
        GROUP BY
            transaction_date::date
    ) txn_summary ON txn_summary.txn_date = dc.cal_date
ORDER BY
    dc.cal_date;


-- =============================================================================
-- 2. MULTIPLE CTEs CHAINED: CUSTOMER → ACCOUNT → TRANSACTION SUMMARY PIPELINE
-- =============================================================================
-- BUSINESS CONTEXT: Build a multi-level analytical pipeline that progressively
-- enriches data. Starting from customers, we join accounts, aggregate
-- transactions, and compute derived KPIs. Each CTE is a logical step that
-- can be independently tested and understood. The final output is a rich
-- customer-level report for the RM (Relationship Manager) dashboard.
-- =============================================================================

WITH customer_base AS (
    -- Step 1: All active customers with basic info
    SELECT
        c.customer_id,
        c.first_name || ' ' || c.last_name       AS customer_name,
        c.email,
        c.phone,
        c.date_of_birth,
        -- Customer tenure in years
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, c.date_of_birth)) AS age
    FROM
        customers c
),
account_summary AS (
    -- Step 2: Aggregate account-level data per customer
    SELECT
        a.customer_id,
        COUNT(a.account_id)                       AS total_accounts,
        SUM(CASE WHEN a.account_type = 'Savings' THEN 1 ELSE 0 END) AS savings_count,
        SUM(CASE WHEN a.account_type = 'Current' THEN 1 ELSE 0 END) AS current_count,
        SUM(a.balance)                            AS total_balance,
        MIN(a.opening_date)                       AS earliest_account_date,
        MAX(a.opening_date)                       AS latest_account_date
    FROM
        accounts a
    WHERE
        a.status = 'Active'
    GROUP BY
        a.customer_id
),
transaction_summary AS (
    -- Step 3: Aggregate transaction-level data per customer
    SELECT
        a.customer_id,
        COUNT(t.transaction_id)                   AS total_transactions,
        SUM(CASE WHEN t.transaction_type = 'Deposit'    THEN t.amount ELSE 0 END) AS total_deposits,
        SUM(CASE WHEN t.transaction_type = 'Withdrawal' THEN t.amount ELSE 0 END) AS total_withdrawals,
        SUM(CASE WHEN t.transaction_type = 'Transfer'   THEN t.amount ELSE 0 END) AS total_transfers,
        ROUND(AVG(t.amount), 2)                   AS avg_transaction_amount,
        MAX(t.transaction_date)                   AS last_transaction_date,
        MAX(t.amount)                             AS largest_transaction
    FROM
        transactions t
        JOIN accounts a ON t.account_id = a.account_id
    WHERE
        t.status = 'Success'
    GROUP BY
        a.customer_id
)
-- Step 4: Final enriched output
SELECT
    cb.customer_id,
    cb.customer_name,
    cb.email,
    cb.age,
    asumm.total_accounts,
    asumm.savings_count,
    asumm.current_count,
    asumm.total_balance,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, asumm.earliest_account_date))
                                                  AS tenure_years,
    ts.total_transactions,
    ts.total_deposits,
    ts.total_withdrawals,
    ts.total_transfers,
    ts.avg_transaction_amount,
    ts.largest_transaction,
    ts.last_transaction_date,
    CURRENT_DATE - ts.last_transaction_date::date AS days_since_last_txn,
    CASE
        WHEN CURRENT_DATE - ts.last_transaction_date::date > 90 THEN 'Dormant'
        WHEN CURRENT_DATE - ts.last_transaction_date::date > 30 THEN 'Inactive'
        ELSE 'Active'
    END                                           AS activity_status
FROM
    customer_base        cb
    LEFT JOIN account_summary     asumm ON cb.customer_id = asumm.customer_id
    LEFT JOIN transaction_summary ts    ON cb.customer_id = ts.customer_id
ORDER BY
    asumm.total_balance DESC NULLS LAST;


-- =============================================================================
-- 3. CORRELATED SUBQUERY: CUSTOMERS WITH ABOVE-AVERAGE BALANCE
-- =============================================================================
-- BUSINESS CONTEXT: Identify customers whose total balance exceeds the overall
-- customer average. This is a classic correlated-subquery pattern — the
-- subquery references the outer query's table. Useful for segmenting high-
-- value customers for premium services or targeted offers.
-- =============================================================================

SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name           AS customer_name,
    SUM(a.balance)                                AS total_balance,
    (SELECT ROUND(AVG(total_bal), 2)
     FROM (
         SELECT SUM(balance) AS total_bal
         FROM   accounts
         WHERE  status = 'Active'
         GROUP BY customer_id
     ) avg_calc
    )                                             AS overall_avg_balance,
    ROUND(
        SUM(a.balance) / NULLIF(
            (SELECT AVG(total_bal)
             FROM (
                 SELECT SUM(balance) AS total_bal
                 FROM   accounts
                 WHERE  status = 'Active'
                 GROUP BY customer_id
             ) avg_calc2
            ), 0
        ), 2
    )                                             AS balance_vs_avg_ratio
FROM
    customers c
    JOIN accounts a ON c.customer_id = a.customer_id
WHERE
    a.status = 'Active'
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name
HAVING
    SUM(a.balance) > (
        SELECT AVG(total_bal)
        FROM (
            SELECT SUM(balance) AS total_bal
            FROM   accounts
            WHERE  status = 'Active'
            GROUP BY customer_id
        ) avg_balances
    )
ORDER BY
    total_balance DESC;


-- =============================================================================
-- 4. EXISTS: CUSTOMERS WHO HAVE BOTH SAVINGS AND CURRENT ACCOUNTS
-- =============================================================================
-- BUSINESS CONTEXT: Customers with diversified account relationships (both
-- Savings and Current) tend to be more engaged and have higher lifetime value.
-- Identifying them supports cross-selling, retention strategies, and
-- relationship deepening campaigns. EXISTS is more performant than IN for
-- this pattern because it short-circuits as soon as a match is found.
-- =============================================================================

SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name           AS customer_name,
    c.email,
    c.phone
FROM
    customers c
WHERE
    -- Has at least one active Savings account
    EXISTS (
        SELECT 1
        FROM   accounts a_sav
        WHERE  a_sav.customer_id  = c.customer_id
        AND    a_sav.account_type = 'Savings'
        AND    a_sav.status       = 'Active'
    )
    -- AND has at least one active Current account
    AND EXISTS (
        SELECT 1
        FROM   accounts a_cur
        WHERE  a_cur.customer_id  = c.customer_id
        AND    a_cur.account_type = 'Current'
        AND    a_cur.status       = 'Active'
    )
ORDER BY
    c.customer_id;


-- =============================================================================
-- 5. NOT EXISTS: CUSTOMERS WHO HAVE NEVER MADE A WITHDRAWAL
-- =============================================================================
-- BUSINESS CONTEXT: Customers who have never withdrawn funds may be:
--   (a) New customers who haven't fully engaged yet (onboarding opportunity)
--   (b) Dormant/abandoned accounts (cleanup candidates)
--   (c) Savings-only customers (potential cross-sell for debit cards)
-- NOT EXISTS is efficient for anti-join patterns where we need rows from one
-- table that have NO matching rows in another.
-- =============================================================================

SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name           AS customer_name,
    c.email,
    STRING_AGG(
        a.account_type || ' (' || a.account_id::text || ')',
        ', '
    )                                             AS accounts,
    SUM(a.balance)                                AS total_balance,
    MIN(a.opening_date)                           AS first_account_opened
FROM
    customers c
    JOIN accounts a ON c.customer_id = a.customer_id
WHERE
    a.status = 'Active'
    AND NOT EXISTS (
        SELECT 1
        FROM   transactions t
        WHERE  t.account_id       = a.account_id
        AND    t.transaction_type  = 'Withdrawal'
        AND    t.status            = 'Success'
    )
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email
ORDER BY
    total_balance DESC;


-- =============================================================================
-- 6. LATERAL JOIN: TOP 3 TRANSACTIONS PER ACCOUNT
-- =============================================================================
-- BUSINESS CONTEXT: A common reporting need is "show the N largest
-- transactions for each account." LATERAL (or CROSS APPLY in SQL Server)
-- enables a per-row subquery that references the outer row. This is more
-- expressive and often more efficient than window-function alternatives
-- for top-N-per-group queries.
--
-- NOTE: MySQL 8.0.14+ supports LATERAL. For older MySQL, use the ROW_NUMBER
-- window function approach shown in the alternative below.
-- =============================================================================

-- PostgreSQL / MySQL 8.0.14+ (LATERAL)
SELECT
    a.account_id,
    a.account_type,
    c.first_name || ' ' || c.last_name           AS customer_name,
    top3.transaction_id,
    top3.transaction_type,
    top3.amount,
    top3.transaction_date,
    top3.txn_rank
FROM
    accounts a
    JOIN customers c ON a.customer_id = c.customer_id
    CROSS JOIN LATERAL (
        SELECT
            t.transaction_id,
            t.transaction_type,
            t.amount,
            t.transaction_date,
            ROW_NUMBER() OVER (ORDER BY t.amount DESC) AS txn_rank
        FROM
            transactions t
        WHERE
            t.account_id = a.account_id
            AND t.status = 'Success'
        ORDER BY
            t.amount DESC
        LIMIT 3
    ) top3
WHERE
    a.status = 'Active'
ORDER BY
    a.account_id,
    top3.txn_rank;

-- ALTERNATIVE (universal): ROW_NUMBER window function approach
-- Works on all major databases without LATERAL support
/*
WITH ranked_txns AS (
    SELECT
        t.account_id,
        t.transaction_id,
        t.transaction_type,
        t.amount,
        t.transaction_date,
        ROW_NUMBER() OVER (
            PARTITION BY t.account_id
            ORDER BY     t.amount DESC
        ) AS txn_rank
    FROM
        transactions t
    WHERE
        t.status = 'Success'
)
SELECT
    a.account_id,
    a.account_type,
    c.first_name || ' ' || c.last_name           AS customer_name,
    rt.transaction_id,
    rt.transaction_type,
    rt.amount,
    rt.transaction_date,
    rt.txn_rank
FROM
    ranked_txns rt
    JOIN accounts  a ON rt.account_id = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
WHERE
    rt.txn_rank <= 3
    AND a.status = 'Active'
ORDER BY
    a.account_id,
    rt.txn_rank;
*/


-- =============================================================================
-- 7. UNION FOR COMPREHENSIVE DASHBOARD KPI ROW
-- =============================================================================
-- BUSINESS CONTEXT: Executive dashboards often require a single result set
-- containing heterogeneous KPIs (total customers, total balance, average
-- transaction, etc.) as rows. UNION ALL stacks these individual metric queries
-- into one output that can be directly consumed by BI tools or API endpoints.
-- Each row is a named KPI with its computed value.
-- =============================================================================

SELECT 'Total Active Customers'        AS kpi_name,
       COUNT(DISTINCT customer_id)::text AS kpi_value,
       'count'                          AS kpi_unit
FROM   customers

UNION ALL

SELECT 'Total Active Accounts',
       COUNT(*)::text,
       'count'
FROM   accounts
WHERE  status = 'Active'

UNION ALL

SELECT 'Total Assets Under Management',
       TO_CHAR(SUM(balance), 'FM₹99,99,99,999.00'),
       'currency'
FROM   accounts
WHERE  status = 'Active'

UNION ALL

SELECT 'Average Account Balance',
       TO_CHAR(ROUND(AVG(balance), 2), 'FM₹99,99,999.00'),
       'currency'
FROM   accounts
WHERE  status = 'Active'

UNION ALL

SELECT 'Total Successful Transactions (This Year)',
       COUNT(*)::text,
       'count'
FROM   transactions
WHERE  status = 'Success'
AND    EXTRACT(YEAR FROM transaction_date) = EXTRACT(YEAR FROM CURRENT_DATE)

UNION ALL

SELECT 'Total Transaction Volume (This Year)',
       TO_CHAR(SUM(amount), 'FM₹99,99,99,99,999.00'),
       'currency'
FROM   transactions
WHERE  status = 'Success'
AND    EXTRACT(YEAR FROM transaction_date) = EXTRACT(YEAR FROM CURRENT_DATE)

UNION ALL

SELECT 'Active Loans Outstanding',
       COUNT(*)::text,
       'count'
FROM   loans
WHERE  status = 'Active'

UNION ALL

SELECT 'Total Loan Portfolio Value',
       TO_CHAR(SUM(loan_amount), 'FM₹99,99,99,999.00'),
       'currency'
FROM   loans
WHERE  status = 'Active'

UNION ALL

SELECT 'Active Cards Issued',
       COUNT(*)::text,
       'count'
FROM   cards
WHERE  status = 'Active';


-- =============================================================================
-- END OF FILE: 02_cte_and_subqueries.sql
-- =============================================================================
