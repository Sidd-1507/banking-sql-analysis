-- =============================================================================
-- File:        01_account_balance_analysis.sql
-- Project:     Banking Transaction Analysis
-- Description: Account balance KPIs — current balances, deposit vs withdrawal
--              breakdown, net cash flow, running balances, and threshold alerts.
-- Author:      Data Analytics Team
-- Date:        2026-10-28
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Current Balance of Each Account with Customer Name and Account Type
-- -----------------------------------------------------------------------------
-- Business Purpose : Provides a quick snapshot of every account alongside its
--                    owner and type, enabling relationship managers to review
--                    individual account health at a glance.
-- Expected Output  : One row per account — account_id, customer_name,
--                    account_type, current_balance, branch_id.
-- -----------------------------------------------------------------------------

SELECT
    a.account_id                                  AS account_id,
    CONCAT(c.first_name, ' ', c.last_name)        AS customer_name,
    a.account_type                                AS account_type,
    a.balance                                     AS current_balance,
    a.branch_id                                   AS branch_id
FROM
    accounts  AS a
    INNER JOIN customers AS c
        ON a.customer_id = c.customer_id
ORDER BY
    a.balance DESC;


-- -----------------------------------------------------------------------------
-- 2. Total Deposits vs Withdrawals per Account
-- -----------------------------------------------------------------------------
-- Business Purpose : Compares inflows and outflows for each account to
--                    understand customer saving behaviour and spending
--                    patterns.
-- Expected Output  : One row per account — account_id, customer_name,
--                    total_deposits, total_withdrawals, txn_count.
-- -----------------------------------------------------------------------------

SELECT
    a.account_id                                          AS account_id,
    CONCAT(c.first_name, ' ', c.last_name)                AS customer_name,
    COALESCE(SUM(CASE
        WHEN t.transaction_type = 'Deposit' THEN t.amount
    END), 0)                                              AS total_deposits,
    COALESCE(SUM(CASE
        WHEN t.transaction_type = 'Withdrawal' THEN t.amount
    END), 0)                                              AS total_withdrawals,
    COUNT(t.transaction_id)                               AS txn_count
FROM
    accounts     AS a
    INNER JOIN customers    AS c  ON a.customer_id = c.customer_id
    LEFT  JOIN transactions AS t  ON a.account_id  = t.account_id
GROUP BY
    a.account_id,
    c.first_name,
    c.last_name
ORDER BY
    total_deposits DESC;


-- -----------------------------------------------------------------------------
-- 3. Net Cash Flow per Account (Deposits − Withdrawals)
-- -----------------------------------------------------------------------------
-- Business Purpose : Highlights whether an account is accumulating or
--                    depleting funds. Negative net flow may indicate financial
--                    stress and is useful for proactive customer outreach.
-- Expected Output  : One row per account — account_id, customer_name,
--                    total_deposits, total_withdrawals, net_cash_flow,
--                    flow_status (Positive / Negative / Neutral).
-- -----------------------------------------------------------------------------

WITH account_flows AS (
    SELECT
        a.account_id,
        CONCAT(c.first_name, ' ', c.last_name)                AS customer_name,
        COALESCE(SUM(CASE
            WHEN t.transaction_type = 'Deposit' THEN t.amount
        END), 0)                                               AS total_deposits,
        COALESCE(SUM(CASE
            WHEN t.transaction_type = 'Withdrawal' THEN t.amount
        END), 0)                                               AS total_withdrawals
    FROM
        accounts     AS a
        INNER JOIN customers    AS c  ON a.customer_id = c.customer_id
        LEFT  JOIN transactions AS t  ON a.account_id  = t.account_id
    GROUP BY
        a.account_id,
        c.first_name,
        c.last_name
)
SELECT
    account_id,
    customer_name,
    total_deposits,
    total_withdrawals,
    (total_deposits - total_withdrawals)                   AS net_cash_flow,
    CASE
        WHEN (total_deposits - total_withdrawals) > 0 THEN 'Positive'
        WHEN (total_deposits - total_withdrawals) < 0 THEN 'Negative'
        ELSE 'Neutral'
    END                                                    AS flow_status
FROM
    account_flows
ORDER BY
    net_cash_flow DESC;


-- -----------------------------------------------------------------------------
-- 4. Running Balance Using Window Functions
-- -----------------------------------------------------------------------------
-- Business Purpose : Shows the cumulative balance progression for every
--                    account over time — essential for audit trails, fraud
--                    detection, and understanding balance trends.
-- Expected Output  : One row per transaction — account_id, transaction_date,
--                    transaction_type, amount, signed_amount, running_balance.
-- -----------------------------------------------------------------------------

SELECT
    t.account_id                                           AS account_id,
    t.transaction_date                                     AS transaction_date,
    t.transaction_type                                     AS transaction_type,
    t.amount                                               AS amount,
    CASE
        WHEN t.transaction_type = 'Deposit'    THEN  t.amount
        WHEN t.transaction_type = 'Withdrawal' THEN -t.amount
        ELSE 0
    END                                                    AS signed_amount,
    SUM(
        CASE
            WHEN t.transaction_type = 'Deposit'    THEN  t.amount
            WHEN t.transaction_type = 'Withdrawal' THEN -t.amount
            ELSE 0
        END
    ) OVER (
        PARTITION BY t.account_id
        ORDER BY     t.transaction_date, t.transaction_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                      AS running_balance
FROM
    transactions AS t
ORDER BY
    t.account_id,
    t.transaction_date,
    t.transaction_id;


-- -----------------------------------------------------------------------------
-- 5. Average Balance per Account Type
-- -----------------------------------------------------------------------------
-- Business Purpose : Benchmarks account types against each other, informing
--                    product strategy and interest-rate decisions.
-- Expected Output  : One row per account_type — account_type, account_count,
--                    avg_balance, min_balance, max_balance, total_balance.
-- -----------------------------------------------------------------------------

SELECT
    a.account_type                       AS account_type,
    COUNT(a.account_id)                  AS account_count,
    ROUND(AVG(a.balance), 2)             AS avg_balance,
    MIN(a.balance)                       AS min_balance,
    MAX(a.balance)                       AS max_balance,
    SUM(a.balance)                       AS total_balance
FROM
    accounts AS a
GROUP BY
    a.account_type
ORDER BY
    avg_balance DESC;


-- -----------------------------------------------------------------------------
-- 6. Accounts with Balance Below Minimum Threshold
-- -----------------------------------------------------------------------------
-- Business Purpose : Flags accounts whose balances violate minimum-balance
--                    rules (₹10 000 for Savings, ₹25 000 for Current). Useful
--                    for compliance reporting and penalty-fee calculations.
-- Expected Output  : One row per below-threshold account — account_id,
--                    customer_name, account_type, current_balance,
--                    min_threshold, deficit.
-- -----------------------------------------------------------------------------

WITH threshold_rules AS (
    SELECT 'Savings' AS account_type, 10000 AS min_threshold
    UNION ALL
    SELECT 'Current' AS account_type, 25000 AS min_threshold
)
SELECT
    a.account_id                                           AS account_id,
    CONCAT(c.first_name, ' ', c.last_name)                 AS customer_name,
    a.account_type                                         AS account_type,
    a.balance                                              AS current_balance,
    tr.min_threshold                                       AS min_threshold,
    (tr.min_threshold - a.balance)                         AS deficit
FROM
    accounts         AS a
    INNER JOIN customers       AS c   ON a.customer_id  = c.customer_id
    INNER JOIN threshold_rules AS tr  ON a.account_type = tr.account_type
WHERE
    a.balance < tr.min_threshold
ORDER BY
    deficit DESC;
