-- =============================================================================
-- File:        03_transaction_trends.sql
-- Project:     Banking Transaction Analysis
-- Description: Transaction trend KPIs — daily/monthly volumes, QoQ growth,
--              peak-hour and day-of-week analysis, channel breakdown,
--              MoM growth rate, and 7-day moving average.
-- Author:      Data Analytics Team
-- Date:        2026-10-28
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Daily Transaction Volume and Amount
-- -----------------------------------------------------------------------------
-- Business Purpose : Gives operations teams a day-by-day view of transaction
--                    load — useful for capacity planning, anomaly detection,
--                    and reconciliation dashboards.
-- Expected Output  : One row per day — txn_date, txn_count, total_amount,
--                    avg_amount.
-- -----------------------------------------------------------------------------

SELECT
    CAST(t.transaction_date AS DATE)         AS txn_date,
    COUNT(t.transaction_id)                  AS txn_count,
    SUM(t.amount)                            AS total_amount,
    ROUND(AVG(t.amount), 2)                  AS avg_amount
FROM
    transactions AS t
GROUP BY
    CAST(t.transaction_date AS DATE)
ORDER BY
    txn_date;


-- -----------------------------------------------------------------------------
-- 2. Monthly Transaction Trend (Count, Total Amount, Avg Amount)
-- -----------------------------------------------------------------------------
-- Business Purpose : Reveals seasonal patterns and long-term growth in
--                    transaction activity, supporting strategic planning
--                    and forecasting.
-- Expected Output  : One row per month — txn_month, txn_count, total_amount,
--                    avg_amount.
-- -----------------------------------------------------------------------------

SELECT
    DATE_TRUNC('month', t.transaction_date)::DATE  AS txn_month,
    COUNT(t.transaction_id)                        AS txn_count,
    SUM(t.amount)                                  AS total_amount,
    ROUND(AVG(t.amount), 2)                        AS avg_amount
FROM
    transactions AS t
GROUP BY
    DATE_TRUNC('month', t.transaction_date)
ORDER BY
    txn_month;


-- -----------------------------------------------------------------------------
-- 3. Quarter-over-Quarter Growth in Transaction Volume
-- -----------------------------------------------------------------------------
-- Business Purpose : Measures quarterly momentum — are we processing more
--                    transactions each quarter? Crucial for investor
--                    reporting and infrastructure scaling decisions.
-- Expected Output  : One row per quarter — txn_quarter, txn_count,
--                    prev_quarter_count, qoq_growth_pct.
-- -----------------------------------------------------------------------------

WITH quarterly_volumes AS (
    SELECT
        DATE_TRUNC('quarter', t.transaction_date)::DATE  AS txn_quarter,
        COUNT(t.transaction_id)                          AS txn_count
    FROM
        transactions AS t
    GROUP BY
        DATE_TRUNC('quarter', t.transaction_date)
)
SELECT
    txn_quarter,
    txn_count,
    LAG(txn_count) OVER (ORDER BY txn_quarter)           AS prev_quarter_count,
    CASE
        WHEN LAG(txn_count) OVER (ORDER BY txn_quarter) IS NULL THEN NULL
        WHEN LAG(txn_count) OVER (ORDER BY txn_quarter) = 0    THEN NULL
        ELSE ROUND(
            (txn_count - LAG(txn_count) OVER (ORDER BY txn_quarter))
            * 100.0
            / LAG(txn_count) OVER (ORDER BY txn_quarter),
            2
        )
    END                                                  AS qoq_growth_pct
FROM
    quarterly_volumes
ORDER BY
    txn_quarter;


-- -----------------------------------------------------------------------------
-- 4. Peak Transaction Hours
-- -----------------------------------------------------------------------------
-- Business Purpose : Identifies the hours of the day with the highest
--                    transaction activity. Helps in scheduling maintenance
--                    windows, staffing branches, and scaling infrastructure.
-- Expected Output  : One row per hour (0–23) — txn_hour, txn_count,
--                    total_amount, hour_rank.
-- -----------------------------------------------------------------------------

SELECT
    EXTRACT(HOUR FROM t.transaction_date)         AS txn_hour,
    COUNT(t.transaction_id)                       AS txn_count,
    SUM(t.amount)                                 AS total_amount,
    RANK() OVER (
        ORDER BY COUNT(t.transaction_id) DESC
    )                                             AS hour_rank
FROM
    transactions AS t
GROUP BY
    EXTRACT(HOUR FROM t.transaction_date)
ORDER BY
    txn_count DESC;


-- -----------------------------------------------------------------------------
-- 5. Day-of-Week Analysis
-- -----------------------------------------------------------------------------
-- Business Purpose : Determines which weekday experiences the most
--                    transactions, enabling resource allocation optimisation
--                    and promotional scheduling.
-- Expected Output  : One row per weekday — day_of_week (1=Mon .. 7=Sun),
--                    day_name, txn_count, total_amount, day_rank.
-- Dialect Note     : EXTRACT(ISODOW …) is PostgreSQL (1=Mon). For MySQL,
--                    use DAYOFWEEK() (1=Sun).
-- -----------------------------------------------------------------------------

SELECT
    EXTRACT(ISODOW FROM t.transaction_date)       AS day_of_week,
    CASE EXTRACT(ISODOW FROM t.transaction_date)
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
        WHEN 7 THEN 'Sunday'
    END                                           AS day_name,
    COUNT(t.transaction_id)                       AS txn_count,
    SUM(t.amount)                                 AS total_amount,
    RANK() OVER (
        ORDER BY COUNT(t.transaction_id) DESC
    )                                             AS day_rank
FROM
    transactions AS t
GROUP BY
    EXTRACT(ISODOW FROM t.transaction_date)
ORDER BY
    txn_count DESC;


-- -----------------------------------------------------------------------------
-- 6. Channel-wise Transaction Breakdown
-- -----------------------------------------------------------------------------
-- Business Purpose : Shows how customers prefer to transact (Online, UPI,
--                    ATM, Mobile, Branch, etc.). Drives digital adoption
--                    strategy and channel investment decisions.
-- Expected Output  : One row per channel — channel, txn_count, total_amount,
--                    avg_amount, pct_of_total_txns.
-- -----------------------------------------------------------------------------

WITH channel_stats AS (
    SELECT
        t.channel                                  AS channel,
        COUNT(t.transaction_id)                    AS txn_count,
        SUM(t.amount)                              AS total_amount,
        ROUND(AVG(t.amount), 2)                    AS avg_amount
    FROM
        transactions AS t
    GROUP BY
        t.channel
)
SELECT
    channel,
    txn_count,
    total_amount,
    avg_amount,
    ROUND(
        txn_count * 100.0 / SUM(txn_count) OVER (), 2
    )                                              AS pct_of_total_txns
FROM
    channel_stats
ORDER BY
    txn_count DESC;


-- -----------------------------------------------------------------------------
-- 7. Month-over-Month Growth Rate Using LAG Window Function
-- -----------------------------------------------------------------------------
-- Business Purpose : Quantifies the monthly momentum of transaction activity.
--                    A declining MoM growth rate may signal customer churn or
--                    a service issue.
-- Expected Output  : One row per month — txn_month, txn_count,
--                    prev_month_count, mom_growth_pct.
-- -----------------------------------------------------------------------------

WITH monthly_counts AS (
    SELECT
        DATE_TRUNC('month', t.transaction_date)::DATE  AS txn_month,
        COUNT(t.transaction_id)                        AS txn_count,
        SUM(t.amount)                                  AS total_amount
    FROM
        transactions AS t
    GROUP BY
        DATE_TRUNC('month', t.transaction_date)
)
SELECT
    txn_month,
    txn_count,
    total_amount,
    LAG(txn_count)    OVER (ORDER BY txn_month)        AS prev_month_count,
    LAG(total_amount) OVER (ORDER BY txn_month)        AS prev_month_amount,
    CASE
        WHEN LAG(txn_count) OVER (ORDER BY txn_month) IS NULL THEN NULL
        WHEN LAG(txn_count) OVER (ORDER BY txn_month) = 0    THEN NULL
        ELSE ROUND(
            (txn_count - LAG(txn_count) OVER (ORDER BY txn_month))
            * 100.0
            / LAG(txn_count) OVER (ORDER BY txn_month),
            2
        )
    END                                                AS mom_growth_pct
FROM
    monthly_counts
ORDER BY
    txn_month;


-- -----------------------------------------------------------------------------
-- 8. 7-Day Moving Average of Transaction Amount
-- -----------------------------------------------------------------------------
-- Business Purpose : Smooths out daily volatility to reveal the underlying
--                    trend in transaction amounts. Useful for dashboards and
--                    anomaly detection (a sudden deviation from the moving
--                    average may indicate fraud or system issues).
-- Expected Output  : One row per day — txn_date, daily_amount,
--                    moving_avg_7d.
-- -----------------------------------------------------------------------------

WITH daily_amounts AS (
    SELECT
        CAST(t.transaction_date AS DATE)             AS txn_date,
        SUM(t.amount)                                AS daily_amount
    FROM
        transactions AS t
    GROUP BY
        CAST(t.transaction_date AS DATE)
)
SELECT
    txn_date,
    daily_amount,
    ROUND(
        AVG(daily_amount) OVER (
            ORDER BY txn_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2
    )                                                AS moving_avg_7d
FROM
    daily_amounts
ORDER BY
    txn_date;
