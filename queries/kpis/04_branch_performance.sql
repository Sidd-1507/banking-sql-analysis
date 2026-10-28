-- =============================================================================
-- File:        04_branch_performance.sql
-- Project:     Banking Transaction Analysis
-- Description: Branch performance KPIs — deposit/withdrawal totals, volume
--              rankings, customer counts, average balances, net deposits,
--              and loan portfolio per branch.
-- Author:      Data Analytics Team
-- Date:        2026-10-28
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Branch-wise Total Deposits and Withdrawals
-- -----------------------------------------------------------------------------
-- Business Purpose : Compares fund inflows and outflows across branches so
--                    regional managers can spot branches that are primarily
--                    deposit-gatherers vs high-withdrawal outlets.
-- Expected Output  : One row per branch — branch_id, branch_name,
--                    total_deposits, total_withdrawals, net_deposits.
-- -----------------------------------------------------------------------------

SELECT
    b.branch_id,
    b.branch_name,
    COALESCE(SUM(CASE
        WHEN t.transaction_type = 'Deposit' THEN t.amount
    END), 0)                                               AS total_deposits,
    COALESCE(SUM(CASE
        WHEN t.transaction_type = 'Withdrawal' THEN t.amount
    END), 0)                                               AS total_withdrawals,
    COALESCE(SUM(CASE
        WHEN t.transaction_type = 'Deposit'    THEN  t.amount
        WHEN t.transaction_type = 'Withdrawal' THEN -t.amount
        ELSE 0
    END), 0)                                               AS net_deposits
FROM
    branches     AS b
    LEFT JOIN accounts     AS a  ON b.branch_id   = a.branch_id
    LEFT JOIN transactions AS t  ON a.account_id  = t.account_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY
    net_deposits DESC;


-- -----------------------------------------------------------------------------
-- 2. Branch Ranking by Total Transaction Volume
-- -----------------------------------------------------------------------------
-- Business Purpose : Ranks branches by the number of transactions processed,
--                    indicating workload distribution and helping justify
--                    staffing and infrastructure spend.
-- Expected Output  : One row per branch — branch_id, branch_name, txn_count,
--                    total_amount, branch_rank.
-- -----------------------------------------------------------------------------

SELECT
    b.branch_id,
    b.branch_name,
    COUNT(t.transaction_id)                                AS txn_count,
    COALESCE(SUM(t.amount), 0)                             AS total_amount,
    RANK() OVER (
        ORDER BY COUNT(t.transaction_id) DESC
    )                                                      AS branch_rank
FROM
    branches     AS b
    LEFT JOIN accounts     AS a  ON b.branch_id   = a.branch_id
    LEFT JOIN transactions AS t  ON a.account_id  = t.account_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY
    branch_rank;


-- -----------------------------------------------------------------------------
-- 3. Branch-wise Customer Count
-- -----------------------------------------------------------------------------
-- Business Purpose : Measures each branch's customer base size, supporting
--                    market-share analysis and new-branch feasibility studies.
-- Expected Output  : One row per branch — branch_id, branch_name,
--                    customer_count, pct_of_total_customers.
-- -----------------------------------------------------------------------------

WITH branch_customers AS (
    SELECT
        b.branch_id,
        b.branch_name,
        COUNT(DISTINCT a.customer_id)                     AS customer_count
    FROM
        branches AS b
        LEFT JOIN accounts AS a  ON b.branch_id = a.branch_id
    GROUP BY
        b.branch_id,
        b.branch_name
)
SELECT
    branch_id,
    branch_name,
    customer_count,
    ROUND(
        customer_count * 100.0 / NULLIF(SUM(customer_count) OVER (), 0), 2
    )                                                      AS pct_of_total_customers
FROM
    branch_customers
ORDER BY
    customer_count DESC;


-- -----------------------------------------------------------------------------
-- 4. Branch-wise Average Account Balance
-- -----------------------------------------------------------------------------
-- Business Purpose : Indicates the financial health and customer wealth
--                    profile of each branch — higher averages may indicate
--                    a premium-client branch.
-- Expected Output  : One row per branch — branch_id, branch_name,
--                    account_count, avg_balance, total_balance.
-- -----------------------------------------------------------------------------

SELECT
    b.branch_id,
    b.branch_name,
    COUNT(a.account_id)                                   AS account_count,
    ROUND(AVG(a.balance), 2)                              AS avg_balance,
    SUM(a.balance)                                        AS total_balance
FROM
    branches AS b
    LEFT JOIN accounts AS a  ON b.branch_id = a.branch_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY
    avg_balance DESC;


-- -----------------------------------------------------------------------------
-- 5. Top Performing Branch by Net Deposits
-- -----------------------------------------------------------------------------
-- Business Purpose : Identifies the single best-performing branch measured by
--                    net fund inflow. Useful for award programmes and best-
--                    practice benchmarking.
-- Expected Output  : One row per branch — branch_id, branch_name,
--                    total_deposits, total_withdrawals, net_deposits,
--                    performance_rank.
-- -----------------------------------------------------------------------------

WITH branch_flows AS (
    SELECT
        b.branch_id,
        b.branch_name,
        COALESCE(SUM(CASE
            WHEN t.transaction_type = 'Deposit' THEN t.amount
        END), 0)                                           AS total_deposits,
        COALESCE(SUM(CASE
            WHEN t.transaction_type = 'Withdrawal' THEN t.amount
        END), 0)                                           AS total_withdrawals
    FROM
        branches     AS b
        LEFT JOIN accounts     AS a  ON b.branch_id   = a.branch_id
        LEFT JOIN transactions AS t  ON a.account_id  = t.account_id
    GROUP BY
        b.branch_id,
        b.branch_name
)
SELECT
    branch_id,
    branch_name,
    total_deposits,
    total_withdrawals,
    (total_deposits - total_withdrawals)                    AS net_deposits,
    ROW_NUMBER() OVER (
        ORDER BY (total_deposits - total_withdrawals) DESC
    )                                                      AS performance_rank
FROM
    branch_flows
ORDER BY
    performance_rank;


-- -----------------------------------------------------------------------------
-- 6. Branch-wise Loan Portfolio (Total Disbursed, Outstanding)
-- -----------------------------------------------------------------------------
-- Business Purpose : Provides a snapshot of each branch's lending book —
--                    total loans disbursed, amounts still outstanding, and
--                    average interest rate. Supports credit-risk monitoring
--                    at the branch level.
-- Expected Output  : One row per branch — branch_id, branch_name,
--                    total_loans, total_disbursed, total_outstanding,
--                    avg_interest_rate.
-- -----------------------------------------------------------------------------

SELECT
    b.branch_id,
    b.branch_name,
    COUNT(l.loan_id)                                       AS total_loans,
    COALESCE(SUM(l.loan_amount), 0)                        AS total_disbursed,
    COALESCE(SUM(l.outstanding_amount), 0)                 AS total_outstanding,
    ROUND(AVG(l.interest_rate), 2)                         AS avg_interest_rate
FROM
    branches AS b
    LEFT JOIN accounts AS a  ON b.branch_id   = a.branch_id
    LEFT JOIN loans    AS l  ON a.customer_id = l.customer_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY
    total_disbursed DESC;
