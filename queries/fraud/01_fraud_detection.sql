-- =============================================================================
-- File:        queries/fraud/01_fraud_detection.sql
-- Project:     Banking Transaction Analysis
-- Description: Comprehensive fraud detection queries using pattern recognition,
--              window functions, and temporal analysis to identify suspicious
--              banking activity across multiple fraud vectors.
-- Author:      Data Engineering Team
-- Date:        2026-10-28
-- Dialect:     Standard SQL (PostgreSQL-compatible; MySQL notes where needed)
-- =============================================================================


-- =============================================================================
-- 1. HIGH-VALUE TRANSACTION FLAGGING
-- =============================================================================
-- BUSINESS CONTEXT: Transactions above a defined threshold (₹1,00,000) are
-- flagged for manual review by the compliance team. Regulatory guidelines
-- (e.g., RBI / FinCEN) require financial institutions to monitor and report
-- large cash transactions. This query surfaces them with customer context so
-- reviewers can quickly assess legitimacy.
-- =============================================================================

SELECT
    t.transaction_id,
    t.account_id,
    c.first_name || ' ' || c.last_name          AS customer_name,
    c.customer_id,
    a.account_type,
    t.transaction_type,
    t.amount,
    t.transaction_date,
    t.channel,
    b.branch_name,
    'HIGH_VALUE_TRANSACTION'                     AS fraud_flag,
    'Amount exceeds ₹1,00,000 reporting threshold' AS flag_reason
FROM
    transactions t
    JOIN accounts   a ON t.account_id   = a.account_id
    JOIN customers  c ON a.customer_id  = c.customer_id
    JOIN branches   b ON a.branch_id    = b.branch_id
WHERE
    t.amount > 100000
    AND t.status = 'Success'
ORDER BY
    t.amount DESC,
    t.transaction_date DESC;


-- =============================================================================
-- 2. RAPID SUCCESSIVE TRANSACTIONS (WITHIN 5 MINUTES)
-- =============================================================================
-- BUSINESS CONTEXT: Legitimate customers rarely perform multiple transactions
-- within a 5-minute window. This pattern is commonly associated with card
-- cloning, compromised credentials, or automated fraudulent scripts that drain
-- accounts quickly before the customer notices. The LAG window function
-- compares each transaction timestamp with the immediately preceding one on
-- the same account to detect rapid-fire activity.
-- =============================================================================

WITH transaction_gaps AS (
    SELECT
        t.transaction_id,
        t.account_id,
        c.first_name || ' ' || c.last_name      AS customer_name,
        t.transaction_type,
        t.amount,
        t.transaction_date,
        t.channel,
        LAG(t.transaction_date) OVER (
            PARTITION BY t.account_id
            ORDER BY     t.transaction_date
        )                                         AS prev_transaction_date,
        t.transaction_date - LAG(t.transaction_date) OVER (
            PARTITION BY t.account_id
            ORDER BY     t.transaction_date
        )                                         AS time_gap
        -- MySQL alternative: TIMESTAMPDIFF(MINUTE, LAG(...), t.transaction_date)
    FROM
        transactions t
        JOIN accounts  a ON t.account_id  = a.account_id
        JOIN customers c ON a.customer_id = c.customer_id
)
SELECT
    transaction_id,
    account_id,
    customer_name,
    transaction_type,
    amount,
    transaction_date,
    prev_transaction_date,
    time_gap,
    channel,
    'RAPID_SUCCESSIVE_TRANSACTION'               AS fraud_flag,
    'Multiple transactions within 5-minute window' AS flag_reason
FROM
    transaction_gaps
WHERE
    time_gap IS NOT NULL
    -- PostgreSQL interval comparison:
    AND time_gap <= INTERVAL '5 minutes'
    -- MySQL alternative: AND time_gap <= 5
ORDER BY
    account_id,
    transaction_date;


-- =============================================================================
-- 3. TRANSACTIONS AT UNUSUAL HOURS (12 AM – 5 AM)
-- =============================================================================
-- BUSINESS CONTEXT: While digital banking enables 24/7 transactions, activity
-- between midnight and 5 AM is statistically uncommon for most retail banking
-- customers. Fraudsters often exploit this window because victims are asleep
-- and less likely to notice real-time alerts. High-value transactions during
-- these hours warrant additional scrutiny, especially via ATM or online
-- channels.
-- =============================================================================

SELECT
    t.transaction_id,
    t.account_id,
    c.first_name || ' ' || c.last_name          AS customer_name,
    t.transaction_type,
    t.amount,
    t.transaction_date,
    EXTRACT(HOUR FROM t.transaction_date)        AS transaction_hour,
    t.channel,
    'ODD_HOUR_TRANSACTION'                       AS fraud_flag,
    'Transaction occurred between 12 AM and 5 AM' AS flag_reason
FROM
    transactions t
    JOIN accounts  a ON t.account_id  = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
WHERE
    EXTRACT(HOUR FROM t.transaction_date) BETWEEN 0 AND 4
    -- Covers 00:00:00 through 04:59:59 (i.e., midnight to just before 5 AM)
    AND t.status = 'Success'
ORDER BY
    t.transaction_date DESC;


-- =============================================================================
-- 4. SUDDEN SPIKE IN TRANSACTION FREQUENCY
-- =============================================================================
-- BUSINESS CONTEXT: A legitimate account typically has a stable transaction
-- pattern. If the current month's transaction count exceeds 3× the average of
-- the prior three months, it may indicate account takeover, money-mule
-- activity, or compromised credentials being exploited at scale. This query
-- uses calendar-month bucketing to compute the historical baseline and flags
-- anomalies.
-- =============================================================================

WITH monthly_counts AS (
    -- Count transactions per account per calendar month
    SELECT
        account_id,
        DATE_TRUNC('month', transaction_date)    AS txn_month,
        COUNT(*)                                  AS txn_count
    FROM
        transactions
    WHERE
        status = 'Success'
    GROUP BY
        account_id,
        DATE_TRUNC('month', transaction_date)
),
current_vs_historical AS (
    SELECT
        mc.account_id,
        mc.txn_month                              AS current_month,
        mc.txn_count                              AS current_month_count,
        AVG(prev.txn_count)                       AS avg_prev_3_months
    FROM
        monthly_counts mc
        LEFT JOIN monthly_counts prev
            ON  prev.account_id = mc.account_id
            AND prev.txn_month >= mc.txn_month - INTERVAL '3 months'
            AND prev.txn_month <  mc.txn_month
    GROUP BY
        mc.account_id,
        mc.txn_month,
        mc.txn_count
)
SELECT
    cvh.account_id,
    c.first_name || ' ' || c.last_name           AS customer_name,
    cvh.current_month,
    cvh.current_month_count,
    ROUND(cvh.avg_prev_3_months, 2)              AS avg_prev_3_months,
    ROUND(
        cvh.current_month_count
        / NULLIF(cvh.avg_prev_3_months, 0), 2
    )                                             AS spike_multiplier,
    'FREQUENCY_SPIKE'                             AS fraud_flag,
    'Current month txn count > 3× prior 3-month avg' AS flag_reason
FROM
    current_vs_historical cvh
    JOIN accounts  a ON cvh.account_id = a.account_id
    JOIN customers c ON a.customer_id  = c.customer_id
WHERE
    cvh.avg_prev_3_months > 0
    AND cvh.current_month_count > 3 * cvh.avg_prev_3_months
ORDER BY
    spike_multiplier DESC;


-- =============================================================================
-- 5. LARGE WITHDRAWAL IMMEDIATELY AFTER LARGE DEPOSIT (MONEY LAUNDERING)
-- =============================================================================
-- BUSINESS CONTEXT: A classic money-laundering red flag is depositing a large
-- sum and withdrawing a similar amount shortly after. This "pass-through"
-- pattern suggests the account is being used to layer illicit funds — the
-- deposit introduces dirty money, and the quick withdrawal moves it onward.
-- We look for withdrawals ≥80 % of a preceding deposit within 24 hours.
-- =============================================================================

WITH deposits AS (
    SELECT
        transaction_id   AS deposit_txn_id,
        account_id,
        amount           AS deposit_amount,
        transaction_date AS deposit_date
    FROM
        transactions
    WHERE
        transaction_type = 'Deposit'
        AND amount > 50000
        AND status = 'Success'
),
withdrawals AS (
    SELECT
        transaction_id   AS withdrawal_txn_id,
        account_id,
        amount           AS withdrawal_amount,
        transaction_date AS withdrawal_date
    FROM
        transactions
    WHERE
        transaction_type = 'Withdrawal'
        AND amount > 50000
        AND status = 'Success'
)
SELECT
    d.deposit_txn_id,
    w.withdrawal_txn_id,
    d.account_id,
    c.first_name || ' ' || c.last_name           AS customer_name,
    d.deposit_amount,
    w.withdrawal_amount,
    d.deposit_date,
    w.withdrawal_date,
    w.withdrawal_date - d.deposit_date            AS time_between,
    ROUND(
        w.withdrawal_amount / d.deposit_amount * 100, 2
    )                                             AS withdrawal_pct_of_deposit,
    'DEPOSIT_WITHDRAWAL_PATTERN'                  AS fraud_flag,
    'Large withdrawal within 24 hrs of large deposit (layering)' AS flag_reason
FROM
    deposits    d
    JOIN withdrawals w
        ON  w.account_id     = d.account_id
        AND w.withdrawal_date > d.deposit_date
        AND w.withdrawal_date <= d.deposit_date + INTERVAL '24 hours'
        AND w.withdrawal_amount >= d.deposit_amount * 0.80
    JOIN accounts  a ON d.account_id  = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
ORDER BY
    d.deposit_date DESC;


-- =============================================================================
-- 6. FAILED TRANSACTIONS FOLLOWED BY SUCCESSFUL ONES (BRUTE FORCE ATTEMPT)
-- =============================================================================
-- BUSINESS CONTEXT: A sequence of failed attempts (wrong PIN, incorrect OTP)
-- followed by a successful transaction is a hallmark of credential brute-
-- forcing or card-testing attacks. Legitimate customers may fail once or
-- twice, but a pattern of 3+ failures immediately followed by success is
-- highly suspicious and suggests the attacker eventually guessed or obtained
-- the correct credentials.
-- =============================================================================

WITH ordered_txns AS (
    SELECT
        transaction_id,
        account_id,
        status,
        transaction_date,
        amount,
        channel,
        LEAD(status) OVER (
            PARTITION BY account_id
            ORDER BY     transaction_date
        )                                         AS next_status,
        LEAD(transaction_date) OVER (
            PARTITION BY account_id
            ORDER BY     transaction_date
        )                                         AS next_txn_date,
        LEAD(amount) OVER (
            PARTITION BY account_id
            ORDER BY     transaction_date
        )                                         AS next_amount
    FROM
        transactions
),
failure_streaks AS (
    -- Count consecutive failures before each successful transaction
    SELECT
        account_id,
        next_txn_date                             AS success_date,
        next_amount                               AS success_amount,
        COUNT(*)                                  AS consecutive_failures,
        MIN(transaction_date)                     AS first_failure_date,
        MAX(transaction_date)                     AS last_failure_date
    FROM
        ordered_txns
    WHERE
        status      = 'Failed'
        AND next_status = 'Success'
    GROUP BY
        account_id,
        next_txn_date,
        next_amount
)
SELECT
    fs.account_id,
    c.first_name || ' ' || c.last_name           AS customer_name,
    fs.consecutive_failures,
    fs.first_failure_date,
    fs.last_failure_date,
    fs.success_date,
    fs.success_amount,
    'BRUTE_FORCE_PATTERN'                         AS fraud_flag,
    'Multiple failed attempts followed by success' AS flag_reason
FROM
    failure_streaks fs
    JOIN accounts  a ON fs.account_id = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
WHERE
    fs.consecutive_failures >= 3
ORDER BY
    fs.consecutive_failures DESC,
    fs.success_date DESC;


-- =============================================================================
-- 7. DORMANT ACCOUNT SUDDENLY ACTIVE WITH HIGH-VALUE TRANSACTIONS
-- =============================================================================
-- BUSINESS CONTEXT: Dormant accounts (no activity for 90+ days) that suddenly
-- process high-value transactions are a major red flag. Fraudsters target
-- dormant accounts because owners rarely monitor them, providing a window for
-- unauthorized activity. This could also indicate a money-mule scheme where
-- old unused accounts are reactivated to move illicit funds.
-- =============================================================================

WITH account_activity AS (
    SELECT
        account_id,
        MAX(transaction_date)                     AS last_txn_before,
        MIN(transaction_date) FILTER (
            WHERE transaction_date > CURRENT_DATE - INTERVAL '7 days'
        )                                         AS first_recent_txn
        -- MySQL alternative: use a CASE inside MIN instead of FILTER
    FROM
        transactions
    WHERE
        status = 'Success'
    GROUP BY
        account_id
),
recent_high_value AS (
    SELECT
        t.account_id,
        t.transaction_id,
        t.amount,
        t.transaction_date,
        t.transaction_type,
        t.channel
    FROM
        transactions t
    WHERE
        t.transaction_date > CURRENT_DATE - INTERVAL '7 days'
        AND t.amount > 50000
        AND t.status = 'Success'
)
SELECT
    rhv.transaction_id,
    rhv.account_id,
    c.first_name || ' ' || c.last_name           AS customer_name,
    aa.last_txn_before                            AS last_activity_before_reactivation,
    CURRENT_DATE - aa.last_txn_before::date       AS days_dormant,
    rhv.transaction_type,
    rhv.amount,
    rhv.transaction_date,
    rhv.channel,
    'DORMANT_REACTIVATION'                        AS fraud_flag,
    'Account dormant 90+ days, now processing high-value txns' AS flag_reason
FROM
    recent_high_value rhv
    JOIN account_activity aa
        ON  rhv.account_id = aa.account_id
        AND aa.last_txn_before < CURRENT_DATE - INTERVAL '90 days'
    JOIN accounts  a ON rhv.account_id = a.account_id
    JOIN customers c ON a.customer_id  = c.customer_id
ORDER BY
    days_dormant DESC,
    rhv.amount DESC;


-- =============================================================================
-- 8. MULTIPLE HIGH-VALUE TRANSACTIONS ACROSS DIFFERENT CHANNELS ON SAME DAY
-- =============================================================================
-- BUSINESS CONTEXT: Fraudsters often test stolen credentials across multiple
-- channels (ATM, Online, Branch, Mobile) to maximise extraction before the
-- account is frozen. A legitimate customer rarely uses 3+ distinct channels
-- in a single day for high-value operations. This cross-channel pattern is
-- a strong indicator of coordinated fraud.
-- =============================================================================

WITH daily_channel_activity AS (
    SELECT
        t.account_id,
        t.transaction_date::date                  AS txn_date,
        COUNT(DISTINCT t.channel)                 AS distinct_channels,
        COUNT(*)                                  AS total_txns,
        SUM(t.amount)                             AS total_amount,
        STRING_AGG(DISTINCT t.channel, ', '
            ORDER BY t.channel
        )                                         AS channels_used
        -- MySQL alternative: GROUP_CONCAT(DISTINCT t.channel ORDER BY t.channel)
    FROM
        transactions t
    WHERE
        t.amount > 25000
        AND t.status = 'Success'
    GROUP BY
        t.account_id,
        t.transaction_date::date
)
SELECT
    dca.account_id,
    c.first_name || ' ' || c.last_name           AS customer_name,
    dca.txn_date,
    dca.distinct_channels,
    dca.channels_used,
    dca.total_txns,
    dca.total_amount,
    'MULTI_CHANNEL_FRAUD'                         AS fraud_flag,
    'High-value txns across 3+ channels in single day' AS flag_reason
FROM
    daily_channel_activity dca
    JOIN accounts  a ON dca.account_id = a.account_id
    JOIN customers c ON a.customer_id  = c.customer_id
WHERE
    dca.distinct_channels >= 3
ORDER BY
    dca.distinct_channels DESC,
    dca.total_amount DESC;


-- =============================================================================
-- 9. VELOCITY CHECK: MORE THAN 10 TRANSACTIONS PER DAY
-- =============================================================================
-- BUSINESS CONTEXT: Most retail banking customers perform fewer than 5
-- transactions per day. A velocity of 10+ transactions signals automated
-- fraud (bot-driven transfers), card testing, or account misuse. Banks
-- typically enforce velocity limits; this query identifies breaches for
-- investigation and potential temporary account freezing.
-- =============================================================================

SELECT
    t.account_id,
    c.first_name || ' ' || c.last_name           AS customer_name,
    a.account_type,
    t.transaction_date::date                      AS txn_date,
    COUNT(*)                                      AS daily_txn_count,
    SUM(t.amount)                                 AS daily_total_amount,
    MIN(t.transaction_date)                       AS first_txn_time,
    MAX(t.transaction_date)                       AS last_txn_time,
    MAX(t.transaction_date) - MIN(t.transaction_date)
                                                  AS activity_window,
    'VELOCITY_BREACH'                             AS fraud_flag,
    'More than 10 transactions in a single day'   AS flag_reason
FROM
    transactions t
    JOIN accounts  a ON t.account_id  = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
WHERE
    t.status = 'Success'
GROUP BY
    t.account_id,
    c.first_name,
    c.last_name,
    a.account_type,
    t.transaction_date::date
HAVING
    COUNT(*) > 10
ORDER BY
    daily_txn_count DESC;


-- =============================================================================
-- 10. STRUCTURING DETECTION: TRANSACTIONS JUST BELOW REPORTING THRESHOLD
-- =============================================================================
-- BUSINESS CONTEXT: "Structuring" (also called "smurfing") is the deliberate
-- splitting of transactions to stay just below regulatory reporting thresholds
-- (e.g., ₹50,000). If a customer consistently transacts in the ₹49,000–
-- ₹49,999 range, they may be intentionally evading Currency Transaction
-- Reports (CTRs). This is a federal crime in most jurisdictions. We flag
-- accounts with 3+ such transactions within a 7-day rolling window.
-- =============================================================================

WITH near_threshold_txns AS (
    SELECT
        t.transaction_id,
        t.account_id,
        t.amount,
        t.transaction_date,
        t.transaction_type,
        t.channel,
        COUNT(*) OVER (
            PARTITION BY t.account_id
            ORDER BY     t.transaction_date
            RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW
        )                                         AS rolling_7d_count,
        SUM(t.amount) OVER (
            PARTITION BY t.account_id
            ORDER BY     t.transaction_date
            RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW
        )                                         AS rolling_7d_total
    FROM
        transactions t
    WHERE
        t.amount BETWEEN 49000 AND 49999
        AND t.status = 'Success'
)
SELECT
    ntt.transaction_id,
    ntt.account_id,
    c.first_name || ' ' || c.last_name           AS customer_name,
    ntt.amount,
    ntt.transaction_date,
    ntt.transaction_type,
    ntt.channel,
    ntt.rolling_7d_count,
    ntt.rolling_7d_total,
    'STRUCTURING_SUSPECTED'                       AS fraud_flag,
    'Multiple transactions just below ₹50,000 threshold (structuring)'
                                                  AS flag_reason
FROM
    near_threshold_txns ntt
    JOIN accounts  a ON ntt.account_id = a.account_id
    JOIN customers c ON a.customer_id  = c.customer_id
WHERE
    ntt.rolling_7d_count >= 3
ORDER BY
    ntt.rolling_7d_count DESC,
    ntt.account_id,
    ntt.transaction_date;


-- =============================================================================
-- END OF FILE: 01_fraud_detection.sql
-- =============================================================================
