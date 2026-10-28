-- =============================================================================
-- File:        02_customer_segmentation.sql
-- Project:     Banking Transaction Analysis
-- Description: Customer segmentation KPIs — volume-based tiers, top customers,
--              lifetime value, RFM analysis, acquisition trends, and
--              active-vs-dormant classification.
-- Author:      Data Analytics Team
-- Date:        2026-10-28
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Customer Segmentation by Transaction Volume
-- -----------------------------------------------------------------------------
-- Business Purpose : Classifies customers into loyalty tiers (Platinum, Gold,
--                    Silver, Bronze) based on the number of transactions they
--                    have made, supporting targeted marketing campaigns and
--                    personalised service levels.
-- Expected Output  : One row per customer — customer_id, customer_name,
--                    total_transactions, segment.
-- -----------------------------------------------------------------------------

WITH customer_txn_counts AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name)   AS customer_name,
        COUNT(t.transaction_id)                   AS total_transactions
    FROM
        customers    AS c
        LEFT JOIN accounts     AS a  ON c.customer_id = a.customer_id
        LEFT JOIN transactions AS t  ON a.account_id  = t.account_id
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name
)
SELECT
    customer_id,
    customer_name,
    total_transactions,
    CASE
        WHEN total_transactions > 50                     THEN 'Platinum'
        WHEN total_transactions BETWEEN 20 AND 50        THEN 'Gold'
        WHEN total_transactions BETWEEN 5  AND 19        THEN 'Silver'
        ELSE                                                  'Bronze'
    END                                                   AS segment
FROM
    customer_txn_counts
ORDER BY
    total_transactions DESC;


-- -----------------------------------------------------------------------------
-- 2. Top 10 Customers by Total Transaction Value
-- -----------------------------------------------------------------------------
-- Business Purpose : Identifies the most valuable customers by cumulative
--                    transaction amount, enabling priority relationship
--                    management and premium product offerings.
-- Expected Output  : 10 rows — customer_id, customer_name,
--                    total_transaction_value, transaction_count, rank.
-- -----------------------------------------------------------------------------

WITH ranked_customers AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name)       AS customer_name,
        COALESCE(SUM(t.amount), 0)                    AS total_transaction_value,
        COUNT(t.transaction_id)                       AS transaction_count,
        RANK() OVER (
            ORDER BY COALESCE(SUM(t.amount), 0) DESC
        )                                             AS customer_rank
    FROM
        customers    AS c
        LEFT JOIN accounts     AS a  ON c.customer_id = a.customer_id
        LEFT JOIN transactions AS t  ON a.account_id  = t.account_id
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name
)
SELECT
    customer_id,
    customer_name,
    total_transaction_value,
    transaction_count,
    customer_rank
FROM
    ranked_customers
WHERE
    customer_rank <= 10
ORDER BY
    customer_rank;


-- -----------------------------------------------------------------------------
-- 3. Customer Lifetime Value (CLV)
-- -----------------------------------------------------------------------------
-- Business Purpose : Estimates each customer's financial contribution to the
--                    bank as total deposits minus total withdrawals plus
--                    interest earned on loans. A higher CLV justifies greater
--                    retention investment.
-- Expected Output  : One row per customer — customer_id, customer_name,
--                    total_deposits, total_withdrawals, interest_earned,
--                    lifetime_value.
-- -----------------------------------------------------------------------------

WITH deposit_withdrawal AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name)            AS customer_name,
        COALESCE(SUM(CASE
            WHEN t.transaction_type = 'Deposit' THEN t.amount
        END), 0)                                           AS total_deposits,
        COALESCE(SUM(CASE
            WHEN t.transaction_type = 'Withdrawal' THEN t.amount
        END), 0)                                           AS total_withdrawals
    FROM
        customers    AS c
        LEFT JOIN accounts     AS a  ON c.customer_id = a.customer_id
        LEFT JOIN transactions AS t  ON a.account_id  = t.account_id
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name
),
interest AS (
    SELECT
        l.customer_id,
        COALESCE(SUM(
            l.loan_amount * l.interest_rate / 100.0
        ), 0)                                              AS interest_earned
    FROM
        loans AS l
    GROUP BY
        l.customer_id
)
SELECT
    dw.customer_id,
    dw.customer_name,
    dw.total_deposits,
    dw.total_withdrawals,
    COALESCE(i.interest_earned, 0)                         AS interest_earned,
    (dw.total_deposits
     - dw.total_withdrawals
     + COALESCE(i.interest_earned, 0))                     AS lifetime_value
FROM
    deposit_withdrawal AS dw
    LEFT JOIN interest AS i
        ON dw.customer_id = i.customer_id
ORDER BY
    lifetime_value DESC;


-- -----------------------------------------------------------------------------
-- 4. RFM Analysis — Recency, Frequency, Monetary
-- -----------------------------------------------------------------------------
-- Business Purpose : Classic RFM segmentation for marketing. Recency = days
--                    since last transaction, Frequency = total transaction
--                    count, Monetary = total transaction amount. Lower recency
--                    and higher frequency/monetary indicate a more engaged,
--                    valuable customer.
-- Expected Output  : One row per customer — customer_id, customer_name,
--                    last_txn_date, recency_days, frequency, monetary_value,
--                    rfm_segment (High-Value / Medium-Value / Low-Value).
-- -----------------------------------------------------------------------------

WITH rfm_raw AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name)       AS customer_name,
        MAX(t.transaction_date)                       AS last_txn_date,
        -- Days since last transaction (dialect note: use DATEDIFF on MySQL)
        CAST(
            CURRENT_DATE - MAX(t.transaction_date) AS INTEGER
        )                                             AS recency_days,
        COUNT(t.transaction_id)                       AS frequency,
        COALESCE(SUM(t.amount), 0)                    AS monetary_value
    FROM
        customers    AS c
        LEFT JOIN accounts     AS a  ON c.customer_id = a.customer_id
        LEFT JOIN transactions AS t  ON a.account_id  = t.account_id
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name
),
rfm_scored AS (
    SELECT
        *,
        NTILE(4) OVER (ORDER BY recency_days ASC)    AS r_score,   -- lower recency = better
        NTILE(4) OVER (ORDER BY frequency     DESC)  AS f_score,
        NTILE(4) OVER (ORDER BY monetary_value DESC) AS m_score
    FROM
        rfm_raw
    WHERE
        last_txn_date IS NOT NULL
)
SELECT
    customer_id,
    customer_name,
    last_txn_date,
    recency_days,
    frequency,
    monetary_value,
    r_score,
    f_score,
    m_score,
    CASE
        WHEN (r_score + f_score + m_score) <= 5  THEN 'High-Value'
        WHEN (r_score + f_score + m_score) <= 9  THEN 'Medium-Value'
        ELSE                                          'Low-Value'
    END                                               AS rfm_segment
FROM
    rfm_scored
ORDER BY
    (r_score + f_score + m_score),
    monetary_value DESC;


-- -----------------------------------------------------------------------------
-- 5. Customer Acquisition Trend by Month
-- -----------------------------------------------------------------------------
-- Business Purpose : Tracks how many new customers are onboarded each month,
--                    helping management gauge the effectiveness of marketing
--                    campaigns and branch expansion.
-- Expected Output  : One row per month — acquisition_month, new_customers,
--                    cumulative_customers.
-- -----------------------------------------------------------------------------

WITH monthly_acquisition AS (
    SELECT
        DATE_TRUNC('month', c.created_at)::DATE       AS acquisition_month,
        COUNT(c.customer_id)                           AS new_customers
    FROM
        customers AS c
    GROUP BY
        DATE_TRUNC('month', c.created_at)
)
SELECT
    acquisition_month,
    new_customers,
    SUM(new_customers) OVER (
        ORDER BY acquisition_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                  AS cumulative_customers
FROM
    monthly_acquisition
ORDER BY
    acquisition_month;


-- -----------------------------------------------------------------------------
-- 6. Active vs Dormant Customers
-- -----------------------------------------------------------------------------
-- Business Purpose : Customers with no transactions in the last 90 days are
--                    classified as dormant. This report enables the retention
--                    team to trigger reactivation campaigns before accounts
--                    turn inactive permanently.
-- Expected Output  : One row per customer — customer_id, customer_name,
--                    last_txn_date, days_since_last_txn, activity_status.
-- -----------------------------------------------------------------------------

WITH customer_activity AS (
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name)       AS customer_name,
        MAX(t.transaction_date)                       AS last_txn_date,
        CAST(
            CURRENT_DATE - MAX(t.transaction_date) AS INTEGER
        )                                             AS days_since_last_txn
    FROM
        customers    AS c
        LEFT JOIN accounts     AS a  ON c.customer_id = a.customer_id
        LEFT JOIN transactions AS t  ON a.account_id  = t.account_id
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name
)
SELECT
    customer_id,
    customer_name,
    last_txn_date,
    days_since_last_txn,
    CASE
        WHEN last_txn_date IS NULL           THEN 'No Transactions'
        WHEN days_since_last_txn > 90        THEN 'Dormant'
        ELSE                                      'Active'
    END                                       AS activity_status
FROM
    customer_activity
ORDER BY
    days_since_last_txn DESC NULLS LAST;
