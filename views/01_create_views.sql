-- =============================================================================
-- File:        views/01_create_views.sql
-- Project:     Banking Transaction Analysis
-- Description: Reusable database views providing pre-joined, pre-aggregated
--              data layers for dashboards, reporting, fraud monitoring, and
--              360-degree customer analytics.
-- Author:      Data Engineering Team
-- Date:        2026-10-28
-- Dialect:     MySQL 8.0+
-- =============================================================================

USE banking_db;

-- =============================================================================
-- 1. v_account_summary
-- =============================================================================
-- PURPOSE: Single-row-per-account view that enriches raw account data with
-- customer name, branch, and status.
-- =============================================================================

CREATE OR REPLACE VIEW v_account_summary AS
SELECT
    a.account_id,
    a.account_number,
    a.account_type,
    a.current_balance,
    a.status                                      AS account_status,
    a.opened_date,
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name)        AS customer_name,
    c.email                                       AS customer_email,
    c.phone                                       AS customer_phone,
    b.branch_id,
    b.branch_name,
    b.city                                        AS branch_city,
    DATEDIFF(CURRENT_DATE, a.opened_date)         AS account_age_days
FROM
    accounts  a
    JOIN customers c ON a.customer_id = c.customer_id
    JOIN branches  b ON a.branch_id   = b.branch_id;


-- =============================================================================
-- 2. v_transaction_detail
-- =============================================================================
-- PURPOSE: Flattened view of every transaction with account, customer,
-- and branch information.
-- =============================================================================

CREATE OR REPLACE VIEW v_transaction_detail AS
SELECT
    t.transaction_id,
    t.reference_number,
    t.transaction_date,
    t.transaction_type,
    t.amount,
    t.balance_after,
    t.channel,
    t.status                                      AS transaction_status,
    t.description,
    a.account_id,
    a.account_number,
    a.account_type,
    a.current_balance                             AS current_account_balance,
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name)        AS customer_name,
    c.email                                       AS customer_email,
    b.branch_id,
    b.branch_name,
    b.city                                        AS branch_city
FROM
    transactions t
    JOIN accounts  a ON t.account_id  = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
    JOIN branches  b ON a.branch_id   = b.branch_id;


-- =============================================================================
-- 3. v_customer_360
-- =============================================================================
-- PURPOSE: 360-degree customer profile view combining demographics, balances,
-- loan exposure, and transaction activity.
-- =============================================================================

CREATE OR REPLACE VIEW v_customer_360 AS
WITH account_aggregates AS (
    SELECT
        customer_id,
        COUNT(*)                                                  AS total_accounts,
        COUNT(CASE WHEN status = 'Active' THEN 1 END)             AS active_accounts,
        SUM(CASE WHEN status = 'Active' THEN current_balance ELSE 0 END) AS total_balance,
        MIN(opened_date)                                          AS first_account_date,
        MAX(opened_date)                                          AS latest_account_date
    FROM
        accounts
    GROUP BY
        customer_id
),
loan_aggregates AS (
    SELECT
        customer_id,
        COUNT(*)                                                  AS total_loans,
        COUNT(CASE WHEN status = 'Active' THEN 1 END)             AS active_loans,
        SUM(CASE WHEN status = 'Active' THEN outstanding_amount ELSE 0 END) AS total_loan_outstanding
    FROM
        loans
    GROUP BY
        customer_id
),
card_aggregates AS (
    SELECT
        customer_id,
        COUNT(*)                                                  AS total_cards,
        COUNT(CASE WHEN card_type = 'Credit' AND status = 'Active' THEN 1 END) AS active_credit_cards,
        COUNT(CASE WHEN card_type = 'Debit'  AND status = 'Active' THEN 1 END) AS active_debit_cards
    FROM
        cards
    GROUP BY
        customer_id
),
txn_aggregates AS (
    SELECT
        a.customer_id,
        COUNT(t.transaction_id)                                  AS total_transactions,
        SUM(CASE WHEN t.transaction_type = 'Deposit' AND t.status = 'Success'
                 THEN t.amount ELSE 0 END)                       AS total_deposited,
        SUM(CASE WHEN t.transaction_type = 'Withdrawal' AND t.status = 'Success'
                 THEN t.amount ELSE 0 END)                       AS total_withdrawn,
        MAX(t.transaction_date)                                  AS last_transaction_date
    FROM
        accounts a
        JOIN transactions t ON a.account_id = t.account_id
    GROUP BY
        a.customer_id
)
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name)        AS full_name,
    c.email,
    c.phone,
    c.city,
    c.occupation,
    c.annual_income,
    c.kyc_status,
    COALESCE(aa.total_accounts, 0)                AS total_accounts,
    COALESCE(aa.active_accounts, 0)               AS active_accounts,
    COALESCE(aa.total_balance, 0)                 AS total_balance,
    COALESCE(la.total_loans, 0)                   AS total_loans,
    COALESCE(la.total_loan_outstanding, 0)        AS total_loan_outstanding,
    COALESCE(ca.total_cards, 0)                   AS total_cards,
    COALESCE(ca.active_credit_cards, 0)           AS active_credit_cards,
    COALESCE(ta.total_transactions, 0)            AS total_transactions,
    COALESCE(ta.total_deposited, 0)               AS lifetime_deposits,
    COALESCE(ta.total_withdrawn, 0)               AS lifetime_withdrawals,
    ta.last_transaction_date,
    CASE
        WHEN COALESCE(aa.total_balance, 0) >= 1000000 THEN 'HNI'
        WHEN COALESCE(aa.total_balance, 0) >= 500000  THEN 'Premium'
        WHEN COALESCE(aa.total_balance, 0) >= 100000  THEN 'Standard'
        ELSE 'Basic'
    END                                           AS customer_segment
FROM
    customers c
    LEFT JOIN account_aggregates aa ON c.customer_id = aa.customer_id
    LEFT JOIN loan_aggregates    la ON c.customer_id = la.customer_id
    LEFT JOIN card_aggregates    ca ON c.customer_id = ca.customer_id
    LEFT JOIN txn_aggregates     ta ON c.customer_id = ta.customer_id;


-- =============================================================================
-- 4. v_daily_transaction_summary
-- =============================================================================
-- PURPOSE: Day-level transaction aggregates for operational monitoring.
-- =============================================================================

CREATE OR REPLACE VIEW v_daily_transaction_summary AS
SELECT
    DATE(t.transaction_date)                                AS txn_date,
    COUNT(*)                                                AS total_transactions,
    COUNT(CASE WHEN t.status = 'Success' THEN 1 END)        AS successful_txns,
    COUNT(CASE WHEN t.status = 'Failed'  THEN 1 END)        AS failed_txns,
    COALESCE(SUM(CASE WHEN t.status = 'Success'
                      THEN t.amount END), 0)                AS total_volume,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'Deposit' AND t.status = 'Success'
                      THEN t.amount END), 0)                AS total_deposits,
    COALESCE(SUM(CASE WHEN t.transaction_type = 'Withdrawal' AND t.status = 'Success'
                      THEN t.amount END), 0)                AS total_withdrawals,
    COUNT(DISTINCT t.account_id)                            AS active_accounts,
    COUNT(CASE WHEN t.channel = 'Online' THEN 1 END)        AS online_txns,
    COUNT(CASE WHEN t.channel = 'UPI'    THEN 1 END)        AS upi_txns,
    COUNT(CASE WHEN t.channel = 'ATM'    THEN 1 END)        AS atm_txns,
    COUNT(CASE WHEN t.amount > 100000 AND t.status = 'Success' THEN 1 END) AS high_value_txns,
    COUNT(CASE WHEN HOUR(t.transaction_date) BETWEEN 0 AND 4 AND t.status = 'Success' THEN 1 END) AS odd_hour_txns
FROM
    transactions t
GROUP BY
    DATE(t.transaction_date);


-- =============================================================================
-- 5. v_monthly_kpi_dashboard
-- =============================================================================
-- PURPOSE: Month-level KPIs for executive reporting.
-- =============================================================================

CREATE OR REPLACE VIEW v_monthly_kpi_dashboard AS
WITH monthly_txn AS (
    SELECT
        DATE_FORMAT(t.transaction_date, '%Y-%m')    AS report_month,
        COUNT(*)                                   AS total_transactions,
        COUNT(CASE WHEN t.status = 'Success' THEN 1 END) AS successful_txns,
        COALESCE(SUM(CASE WHEN t.status = 'Success' THEN t.amount END), 0) AS total_volume,
        COALESCE(SUM(CASE WHEN t.transaction_type = 'Deposit' AND t.status = 'Success' THEN t.amount END), 0) AS total_deposits,
        COALESCE(SUM(CASE WHEN t.transaction_type = 'Withdrawal' AND t.status = 'Success' THEN t.amount END), 0) AS total_withdrawals,
        COUNT(DISTINCT t.account_id)               AS active_transacting_accounts,
        ROUND(AVG(CASE WHEN t.status = 'Success' THEN t.amount END), 2) AS avg_txn_amount,
        MAX(CASE WHEN t.status = 'Success' THEN t.amount END) AS max_txn_amount,
        COUNT(CASE WHEN t.amount > 100000 AND t.status = 'Success' THEN 1 END) AS high_value_txn_count,
        ROUND(COUNT(CASE WHEN t.status = 'Failed' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS failure_rate_pct
    FROM
        transactions t
    GROUP BY
        DATE_FORMAT(t.transaction_date, '%Y-%m')
),
monthly_new_accounts AS (
    SELECT
        DATE_FORMAT(opened_date, '%Y-%m')          AS report_month,
        COUNT(*)                                   AS new_accounts_opened
    FROM
        accounts
    GROUP BY
        DATE_FORMAT(opened_date, '%Y-%m')
)
SELECT
    mt.report_month,
    mt.total_transactions,
    mt.successful_txns,
    mt.total_volume,
    mt.total_deposits,
    mt.total_withdrawals,
    mt.total_deposits - mt.total_withdrawals       AS net_flow,
    mt.active_transacting_accounts,
    mt.avg_txn_amount,
    mt.max_txn_amount,
    mt.high_value_txn_count,
    mt.failure_rate_pct,
    COALESCE(mna.new_accounts_opened, 0)           AS new_accounts_opened
FROM
    monthly_txn mt
    LEFT JOIN monthly_new_accounts mna ON mt.report_month = mna.report_month
ORDER BY
    mt.report_month;


-- =============================================================================
-- 6. v_fraud_alerts
-- =============================================================================
-- PURPOSE: Unified fraud-alert view that flags transactions matching core
-- fraud rules: high-value, odd-hour, rapid succession, structuring.
-- =============================================================================

CREATE OR REPLACE VIEW v_fraud_alerts AS
WITH rapid_succession AS (
    SELECT
        t.transaction_id,
        t.account_id,
        t.amount,
        t.transaction_date,
        t.transaction_type,
        t.channel,
        LAG(t.transaction_date) OVER (
            PARTITION BY t.account_id
            ORDER BY     t.transaction_date
        ) AS prev_txn_date
    FROM
        transactions t
    WHERE
        t.status = 'Success'
)
SELECT
    rs.transaction_id,
    rs.account_id,
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name)         AS customer_name,
    rs.transaction_type,
    rs.amount,
    rs.transaction_date,
    rs.channel,
    CASE WHEN rs.amount > 100000 THEN 1 ELSE 0 END AS flag_high_value,
    CASE WHEN HOUR(rs.transaction_date) BETWEEN 0 AND 4 THEN 1 ELSE 0 END AS flag_odd_hour,
    CASE WHEN rs.prev_txn_date IS NOT NULL AND TIMESTAMPDIFF(MINUTE, rs.prev_txn_date, rs.transaction_date) <= 5
         THEN 1 ELSE 0 END                         AS flag_rapid_succession,
    CASE WHEN rs.amount BETWEEN 49000 AND 49999 THEN 1 ELSE 0 END AS flag_near_threshold,
    CASE
        WHEN rs.amount > 100000 AND HOUR(rs.transaction_date) BETWEEN 0 AND 4 THEN 'CRITICAL'
        WHEN rs.amount > 100000 OR (rs.prev_txn_date IS NOT NULL AND TIMESTAMPDIFF(MINUTE, rs.prev_txn_date, rs.transaction_date) <= 5) THEN 'HIGH'
        WHEN HOUR(rs.transaction_date) BETWEEN 0 AND 4 OR rs.amount BETWEEN 49000 AND 49999 THEN 'MEDIUM'
        ELSE 'LOW'
    END                                            AS alert_severity,
    CONCAT_WS(' | ',
        CASE WHEN rs.amount > 100000 THEN 'HIGH_VALUE' END,
        CASE WHEN HOUR(rs.transaction_date) BETWEEN 0 AND 4 THEN 'ODD_HOUR' END,
        CASE WHEN rs.prev_txn_date IS NOT NULL AND TIMESTAMPDIFF(MINUTE, rs.prev_txn_date, rs.transaction_date) <= 5 THEN 'RAPID_SUCCESSION' END,
        CASE WHEN rs.amount BETWEEN 49000 AND 49999 THEN 'NEAR_THRESHOLD' END
    )                                              AS triggered_rules
FROM
    rapid_succession rs
    JOIN accounts  a ON rs.account_id  = a.account_id
    JOIN customers c ON a.customer_id  = c.customer_id
WHERE
    rs.amount > 100000
    OR HOUR(rs.transaction_date) BETWEEN 0 AND 4
    OR (rs.prev_txn_date IS NOT NULL AND TIMESTAMPDIFF(MINUTE, rs.prev_txn_date, rs.transaction_date) <= 5)
    OR rs.amount BETWEEN 49000 AND 49999;


-- =============================================================================
-- 7. v_loan_health
-- =============================================================================
-- PURPOSE: Loan portfolio health view showing each loan with customer context,
-- payment status, and outstanding exposure.
-- =============================================================================

CREATE OR REPLACE VIEW v_loan_health AS
SELECT
    l.loan_id,
    l.principal_amount                             AS loan_amount,
    l.outstanding_amount,
    l.interest_rate,
    l.tenure_months,
    l.emi_amount,
    l.loan_type,
    l.disbursement_date,
    l.status                                       AS loan_status,
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name)         AS customer_name,
    c.email                                        AS customer_email,
    c.phone                                        AS customer_phone,
    a.account_id,
    a.account_type,
    a.current_balance                              AS account_balance,
    b.branch_name,
    ROUND((l.outstanding_amount / NULLIF(l.principal_amount, 0)) * 100, 2) AS outstanding_pct,
    CASE
        WHEN l.status = 'Closed'    THEN 'Closed'
        WHEN l.status = 'Defaulted' THEN 'NPA / Defaulted'
        ELSE 'Active - Regular'
    END                                            AS portfolio_category
FROM
    loans     l
    JOIN accounts  a ON l.account_id  = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
    JOIN branches  b ON a.branch_id   = b.branch_id;
