-- =============================================================================
-- File:        05_loan_portfolio_analysis.sql
-- Project:     Banking Transaction Analysis
-- Description: Loan portfolio KPIs — summary by type, loan-to-deposit ratio,
--              NPA identification, EMI burden ratio, status distribution,
--              and tenure/rate analysis.
-- Author:      Data Analytics Team
-- Date:        2026-10-28
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Loan Portfolio Summary by Type
-- -----------------------------------------------------------------------------
-- Business Purpose : Breaks down the entire loan book by loan type, showing
--                    the count, total principal disbursed, total outstanding
--                    balance, and average interest rate. Helps credit teams
--                    understand concentration risk and pricing effectiveness.
-- Expected Output  : One row per loan_type — loan_type, loan_count,
--                    total_principal, total_outstanding, avg_interest_rate,
--                    pct_of_portfolio.
-- -----------------------------------------------------------------------------

WITH loan_summary AS (
    SELECT
        l.loan_type,
        COUNT(l.loan_id)                                  AS loan_count,
        SUM(l.loan_amount)                                AS total_principal,
        SUM(l.outstanding_amount)                         AS total_outstanding,
        ROUND(AVG(l.interest_rate), 2)                    AS avg_interest_rate
    FROM
        loans AS l
    GROUP BY
        l.loan_type
)
SELECT
    loan_type,
    loan_count,
    total_principal,
    total_outstanding,
    avg_interest_rate,
    ROUND(
        total_principal * 100.0
        / NULLIF(SUM(total_principal) OVER (), 0), 2
    )                                                      AS pct_of_portfolio
FROM
    loan_summary
ORDER BY
    total_principal DESC;


-- -----------------------------------------------------------------------------
-- 2. Loan-to-Deposit Ratio per Branch
-- -----------------------------------------------------------------------------
-- Business Purpose : A key banking health metric — a high ratio means the
--                    branch is lending aggressively relative to its deposit
--                    base (liquidity risk). Regulators and treasury teams
--                    monitor this closely.
-- Expected Output  : One row per branch — branch_id, branch_name,
--                    total_deposits, total_loans_disbursed,
--                    loan_to_deposit_ratio.
-- -----------------------------------------------------------------------------

WITH branch_deposits AS (
    SELECT
        a.branch_id,
        COALESCE(SUM(CASE
            WHEN t.transaction_type = 'Deposit' THEN t.amount
        END), 0)                                           AS total_deposits
    FROM
        accounts     AS a
        LEFT JOIN transactions AS t  ON a.account_id = t.account_id
    GROUP BY
        a.branch_id
),
branch_loans AS (
    SELECT
        a.branch_id,
        COALESCE(SUM(l.loan_amount), 0)                    AS total_loans_disbursed
    FROM
        loans    AS l
        INNER JOIN accounts AS a  ON l.customer_id = a.customer_id
    GROUP BY
        a.branch_id
)
SELECT
    b.branch_id,
    b.branch_name,
    COALESCE(bd.total_deposits, 0)                         AS total_deposits,
    COALESCE(bl.total_loans_disbursed, 0)                  AS total_loans_disbursed,
    CASE
        WHEN COALESCE(bd.total_deposits, 0) = 0 THEN NULL
        ELSE ROUND(
            COALESCE(bl.total_loans_disbursed, 0) * 100.0
            / bd.total_deposits, 2
        )
    END                                                    AS loan_to_deposit_ratio_pct
FROM
    branches        AS b
    LEFT JOIN branch_deposits AS bd  ON b.branch_id = bd.branch_id
    LEFT JOIN branch_loans    AS bl  ON b.branch_id = bl.branch_id
ORDER BY
    loan_to_deposit_ratio_pct DESC NULLS LAST;


-- -----------------------------------------------------------------------------
-- 3. Non-Performing Asset (NPA) Identification
-- -----------------------------------------------------------------------------
-- Business Purpose : Flags loans whose status is 'Defaulted' — the most
--                    critical credit-risk indicator. Helps the collections
--                    team prioritise recovery efforts and informs provision
--                    calculations.
-- Expected Output  : One row per defaulted loan — loan_id, customer_name,
--                    loan_type, loan_amount, outstanding_amount,
--                    interest_rate, loan_status.
-- -----------------------------------------------------------------------------

SELECT
    l.loan_id,
    CONCAT(c.first_name, ' ', c.last_name)                 AS customer_name,
    l.loan_type,
    l.loan_amount,
    l.outstanding_amount,
    l.interest_rate,
    l.status                                                AS loan_status,
    ROUND(
        l.outstanding_amount * 100.0
        / NULLIF(l.loan_amount, 0), 2
    )                                                       AS outstanding_pct
FROM
    loans     AS l
    INNER JOIN customers AS c  ON l.customer_id = c.customer_id
WHERE
    l.status = 'Defaulted'
ORDER BY
    l.outstanding_amount DESC;


-- -----------------------------------------------------------------------------
-- 4. EMI Burden Ratio per Customer
-- -----------------------------------------------------------------------------
-- Business Purpose : Estimates the proportion of each customer's annual
--                    income consumed by estimated EMIs. A ratio above 50 %
--                    signals financial stress and should trigger review
--                    before approving additional credit.
-- Formula          : (Total EMI × 12) / Annual Income × 100
-- Assumption       : The loans table contains an `emi` column, and the
--                    customers table has an `annual_income` column.
-- Expected Output  : One row per customer — customer_id, customer_name,
--                    annual_income, total_monthly_emi, emi_burden_ratio_pct,
--                    risk_flag.
-- -----------------------------------------------------------------------------

WITH customer_emi AS (
    SELECT
        l.customer_id,
        SUM(l.emi)                                         AS total_monthly_emi
    FROM
        loans AS l
    WHERE
        l.status IN ('Active', 'Approved')
    GROUP BY
        l.customer_id
)
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name)                 AS customer_name,
    c.annual_income,
    ce.total_monthly_emi,
    ROUND(
        (ce.total_monthly_emi * 12) * 100.0
        / NULLIF(c.annual_income, 0), 2
    )                                                       AS emi_burden_ratio_pct,
    CASE
        WHEN (ce.total_monthly_emi * 12) * 100.0
             / NULLIF(c.annual_income, 0) > 50 THEN 'High Risk'
        WHEN (ce.total_monthly_emi * 12) * 100.0
             / NULLIF(c.annual_income, 0) > 30 THEN 'Moderate Risk'
        ELSE                                             'Low Risk'
    END                                                     AS risk_flag
FROM
    customers    AS c
    INNER JOIN customer_emi AS ce  ON c.customer_id = ce.customer_id
ORDER BY
    emi_burden_ratio_pct DESC;


-- -----------------------------------------------------------------------------
-- 5. Loan Status Distribution
-- -----------------------------------------------------------------------------
-- Business Purpose : Provides a high-level view of the loan book health —
--                    how many loans are Active, Closed, Defaulted, etc.
--                    Informs provisioning and risk dashboards.
-- Expected Output  : One row per status — loan_status, loan_count,
--                    total_amount, pct_of_total.
-- -----------------------------------------------------------------------------

WITH status_summary AS (
    SELECT
        l.status                                           AS loan_status,
        COUNT(l.loan_id)                                   AS loan_count,
        SUM(l.loan_amount)                                 AS total_amount
    FROM
        loans AS l
    GROUP BY
        l.status
)
SELECT
    loan_status,
    loan_count,
    total_amount,
    ROUND(
        loan_count * 100.0 / NULLIF(SUM(loan_count) OVER (), 0), 2
    )                                                       AS pct_of_total
FROM
    status_summary
ORDER BY
    loan_count DESC;


-- -----------------------------------------------------------------------------
-- 6. Average Tenure and Interest Rate by Loan Type
-- -----------------------------------------------------------------------------
-- Business Purpose : Benchmarks product terms across loan types — useful for
--                    pricing reviews, competitive analysis, and product
--                    design.
-- Expected Output  : One row per loan_type — loan_type, loan_count,
--                    avg_tenure_months, min_tenure, max_tenure,
--                    avg_interest_rate, min_interest_rate, max_interest_rate.
-- -----------------------------------------------------------------------------

SELECT
    l.loan_type,
    COUNT(l.loan_id)                                       AS loan_count,
    ROUND(AVG(l.tenure_months), 1)                         AS avg_tenure_months,
    MIN(l.tenure_months)                                   AS min_tenure,
    MAX(l.tenure_months)                                   AS max_tenure,
    ROUND(AVG(l.interest_rate), 2)                         AS avg_interest_rate,
    MIN(l.interest_rate)                                   AS min_interest_rate,
    MAX(l.interest_rate)                                   AS max_interest_rate
FROM
    loans AS l
GROUP BY
    l.loan_type
ORDER BY
    avg_tenure_months DESC;
