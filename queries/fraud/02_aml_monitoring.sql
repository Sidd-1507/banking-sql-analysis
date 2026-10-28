-- =============================================================================
-- File:        queries/fraud/02_aml_monitoring.sql
-- Project:     Banking Transaction Analysis
-- Description: Anti-Money Laundering (AML) monitoring queries implementing
--              suspicious activity detection, smurfing identification,
--              structuring analysis, risk scoring, and cross-account transfer
--              chain detection.
-- Author:      Data Engineering Team
-- Date:        2026-10-28
-- Dialect:     Standard SQL (PostgreSQL-compatible; MySQL notes where needed)
-- =============================================================================


-- =============================================================================
-- 1. SUSPICIOUS ACTIVITY REPORT (SAR): ACCOUNTS RECEIVING AND SENDING LARGE
--    AMOUNTS WITHIN 24 HOURS
-- =============================================================================
-- BUSINESS CONTEXT: A core AML red flag is an account that receives a large
-- deposit and then sends out a comparable amount within 24 hours ("pass-
-- through" or "funnel" account). This suggests the account is being used
-- purely as a layering vehicle to obscure the money trail. Compliance teams
-- must file a SAR with regulators when this pattern is identified. We match
-- inbound deposits against outbound withdrawals/transfers on the same account
-- within a 24-hour window.
-- =============================================================================

WITH inbound AS (
    -- Large deposits or incoming transfers
    SELECT
        transaction_id   AS inbound_txn_id,
        account_id,
        amount           AS inbound_amount,
        transaction_date AS inbound_date,
        channel          AS inbound_channel
    FROM
        transactions
    WHERE
        transaction_type IN ('Deposit', 'Transfer')
        AND amount > 100000
        AND status = 'Success'
),
outbound AS (
    -- Large withdrawals or outgoing transfers
    SELECT
        transaction_id   AS outbound_txn_id,
        account_id,
        amount           AS outbound_amount,
        transaction_date AS outbound_date,
        channel          AS outbound_channel
    FROM
        transactions
    WHERE
        transaction_type IN ('Withdrawal', 'Transfer')
        AND amount > 100000
        AND status = 'Success'
)
SELECT
    i.account_id,
    c.first_name || ' ' || c.last_name            AS customer_name,
    c.customer_id,
    i.inbound_txn_id,
    i.inbound_amount,
    i.inbound_date,
    i.inbound_channel,
    o.outbound_txn_id,
    o.outbound_amount,
    o.outbound_date,
    o.outbound_channel,
    o.outbound_date - i.inbound_date               AS time_between,
    ROUND(
        o.outbound_amount / i.inbound_amount * 100, 2
    )                                              AS outbound_pct_of_inbound,
    'SAR_PASS_THROUGH'                             AS alert_type,
    'Large inbound + outbound within 24 hours — potential layering' AS alert_reason
FROM
    inbound  i
    JOIN outbound o
        ON  o.account_id   = i.account_id
        AND o.outbound_date > i.inbound_date
        AND o.outbound_date <= i.inbound_date + INTERVAL '24 hours'
        AND o.outbound_amount >= i.inbound_amount * 0.70   -- at least 70 % moved out
    JOIN accounts  a ON i.account_id  = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
ORDER BY
    i.inbound_date DESC;


-- =============================================================================
-- 2. SMURFING DETECTION: MANY SMALL DEPOSITS TOTALLING > ₹2,00,000 IN A DAY
-- =============================================================================
-- BUSINESS CONTEXT: "Smurfing" is a layering technique where large sums are
-- broken into many small deposits (each below the reporting threshold of
-- ₹50,000) across the same account in a single day. Individually, each
-- deposit looks innocuous, but the aggregate exceeds what would normally
-- trigger a Currency Transaction Report (CTR). This query groups sub-₹50,000
-- deposits by account and day, flagging days where the total exceeds ₹2,00,000.
-- =============================================================================

SELECT
    t.account_id,
    c.first_name || ' ' || c.last_name            AS customer_name,
    t.transaction_date::date                       AS txn_date,
    COUNT(*)                                       AS num_small_deposits,
    SUM(t.amount)                                  AS total_deposited,
    MIN(t.amount)                                  AS smallest_deposit,
    MAX(t.amount)                                  AS largest_deposit,
    ROUND(AVG(t.amount), 2)                        AS avg_deposit,
    STRING_AGG(
        t.amount::text, ', '
        ORDER BY t.transaction_date
    )                                              AS deposit_amounts,
    'SMURFING_DETECTED'                            AS alert_type,
    'Multiple sub-₹50K deposits totalling > ₹2L in one day' AS alert_reason
FROM
    transactions t
    JOIN accounts  a ON t.account_id  = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
WHERE
    t.transaction_type = 'Deposit'
    AND t.amount < 50000
    AND t.status = 'Success'
GROUP BY
    t.account_id,
    c.first_name,
    c.last_name,
    t.transaction_date::date
HAVING
    SUM(t.amount) > 200000
ORDER BY
    total_deposited DESC;


-- =============================================================================
-- 3. ROUND-AMOUNT TRANSACTION DETECTION (POTENTIAL STRUCTURING)
-- =============================================================================
-- BUSINESS CONTEXT: Legitimate transactions are rarely exact multiples of
-- ₹10,000. A high frequency of perfectly round amounts (₹10,000, ₹20,000,
-- ₹30,000, etc.) on a single account can indicate manufactured transactions
-- designed to circumvent reporting controls or launder funds in neat,
-- pre-planned amounts. We flag accounts with 5+ round-amount transactions
-- in a 30-day window.
-- =============================================================================

WITH round_txns AS (
    SELECT
        t.transaction_id,
        t.account_id,
        t.amount,
        t.transaction_date,
        t.transaction_type,
        t.channel,
        -- Count round-amount transactions in a 30-day rolling window
        COUNT(*) OVER (
            PARTITION BY t.account_id
            ORDER BY     t.transaction_date
            RANGE BETWEEN INTERVAL '30 days' PRECEDING AND CURRENT ROW
        )                                          AS rolling_30d_round_count
    FROM
        transactions t
    WHERE
        t.amount >= 10000
        AND MOD(t.amount::int, 10000) = 0          -- exact multiple of ₹10,000
        AND t.status = 'Success'
)
SELECT
    rt.transaction_id,
    rt.account_id,
    c.first_name || ' ' || c.last_name            AS customer_name,
    rt.amount,
    rt.transaction_date,
    rt.transaction_type,
    rt.channel,
    rt.rolling_30d_round_count,
    'ROUND_AMOUNT_STRUCTURING'                     AS alert_type,
    'Frequent round-amount transactions — potential structuring' AS alert_reason
FROM
    round_txns rt
    JOIN accounts  a ON rt.account_id = a.account_id
    JOIN customers c ON a.customer_id = c.customer_id
WHERE
    rt.rolling_30d_round_count >= 5
ORDER BY
    rt.rolling_30d_round_count DESC,
    rt.account_id,
    rt.transaction_date;


-- =============================================================================
-- 4. CUSTOMER RISK SCORING: MULTI-FACTOR COMPOSITE RISK SCORE
-- =============================================================================
-- BUSINESS CONTEXT: Rather than relying on a single rule, a robust AML program
-- assigns a composite risk score to each customer by combining multiple risk
-- signals. This CTE-based pipeline aggregates individual risk factors (high-
-- value transaction count, odd-hour activity, velocity breaches, structuring
-- indicators, rapid successions, and dormant-account reactivations) into a
-- weighted score. The result feeds compliance dashboards and determines which
-- customers require Enhanced Due Diligence (EDD).
--
-- SCORING WEIGHTS:
--   High-value txns (>₹1L)            : 10 pts each
--   Odd-hour txns (12 AM – 5 AM)      : 15 pts each
--   Velocity breaches (>10 txn/day)   : 20 pts per day
--   Near-threshold txns (₹49K–₹49.9K) : 25 pts each
--   Rapid succession events (<5 min)  : 30 pts each
-- =============================================================================

WITH high_value_risk AS (
    SELECT
        a.customer_id,
        COUNT(*) * 10                              AS risk_points,
        'High-value transactions (> ₹1L)'          AS risk_factor
    FROM
        transactions t
        JOIN accounts a ON t.account_id = a.account_id
    WHERE
        t.amount > 100000
        AND t.status = 'Success'
    GROUP BY
        a.customer_id
),
odd_hour_risk AS (
    SELECT
        a.customer_id,
        COUNT(*) * 15                              AS risk_points,
        'Odd-hour transactions (12 AM – 5 AM)'    AS risk_factor
    FROM
        transactions t
        JOIN accounts a ON t.account_id = a.account_id
    WHERE
        EXTRACT(HOUR FROM t.transaction_date) BETWEEN 0 AND 4
        AND t.status = 'Success'
    GROUP BY
        a.customer_id
),
velocity_risk AS (
    SELECT
        a.customer_id,
        COUNT(*) * 20                              AS risk_points,
        'Velocity breaches (> 10 txns/day)'        AS risk_factor
    FROM (
        SELECT
            account_id,
            transaction_date::date                 AS txn_date,
            COUNT(*)                               AS cnt
        FROM
            transactions
        WHERE
            status = 'Success'
        GROUP BY
            account_id,
            transaction_date::date
        HAVING
            COUNT(*) > 10
    ) daily_vel
    JOIN accounts a ON daily_vel.account_id = a.account_id
    GROUP BY
        a.customer_id
),
structuring_risk AS (
    SELECT
        a.customer_id,
        COUNT(*) * 25                              AS risk_points,
        'Near-threshold transactions (₹49K–₹49.9K)' AS risk_factor
    FROM
        transactions t
        JOIN accounts a ON t.account_id = a.account_id
    WHERE
        t.amount BETWEEN 49000 AND 49999
        AND t.status = 'Success'
    GROUP BY
        a.customer_id
),
rapid_succession_risk AS (
    SELECT
        a.customer_id,
        COUNT(*) * 30                              AS risk_points,
        'Rapid successive transactions (< 5 min)'  AS risk_factor
    FROM (
        SELECT
            account_id,
            transaction_date,
            LAG(transaction_date) OVER (
                PARTITION BY account_id
                ORDER BY     transaction_date
            )                                      AS prev_date
        FROM
            transactions
        WHERE
            status = 'Success'
    ) gaps
    JOIN accounts a ON gaps.account_id = a.account_id
    WHERE
        gaps.prev_date IS NOT NULL
        AND gaps.transaction_date - gaps.prev_date <= INTERVAL '5 minutes'
    GROUP BY
        a.customer_id
),
all_risks AS (
    SELECT customer_id, risk_points, risk_factor FROM high_value_risk
    UNION ALL
    SELECT customer_id, risk_points, risk_factor FROM odd_hour_risk
    UNION ALL
    SELECT customer_id, risk_points, risk_factor FROM velocity_risk
    UNION ALL
    SELECT customer_id, risk_points, risk_factor FROM structuring_risk
    UNION ALL
    SELECT customer_id, risk_points, risk_factor FROM rapid_succession_risk
)
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name            AS customer_name,
    SUM(ar.risk_points)                            AS total_risk_score,
    CASE
        WHEN SUM(ar.risk_points) >= 200 THEN 'CRITICAL'
        WHEN SUM(ar.risk_points) >= 100 THEN 'HIGH'
        WHEN SUM(ar.risk_points) >= 50  THEN 'MEDIUM'
        ELSE                                  'LOW'
    END                                            AS risk_level,
    STRING_AGG(
        ar.risk_factor || ' (' || ar.risk_points || ' pts)',
        ' | ' ORDER BY ar.risk_points DESC
    )                                              AS risk_breakdown,
    COUNT(DISTINCT ar.risk_factor)                 AS num_risk_factors
FROM
    all_risks ar
    JOIN customers c ON ar.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name
ORDER BY
    total_risk_score DESC;


-- =============================================================================
-- 5. CROSS-ACCOUNT SUSPICIOUS TRANSFER CHAINS (A → B → C)
-- =============================================================================
-- BUSINESS CONTEXT: Money launderers often move funds through a chain of
-- accounts (A → B → C → …) to create distance from the source. Each hop adds
-- a layer of obfuscation. By detecting 3-hop (or more) transfer chains where
-- money moves rapidly through intermediary accounts, we can identify potential
-- layering networks. We assume the transactions table has a
-- `destination_account_id` column for transfer-type transactions.
--
-- NOTE: This query looks for A → B → C chains where:
--   - Each transfer is ≥ ₹50,000
--   - B forwards at least 70 % of what it received
--   - Each hop occurs within 48 hours of the previous
-- =============================================================================

WITH transfers AS (
    -- Extract completed transfer transactions with source and destination
    SELECT
        transaction_id,
        account_id           AS source_account_id,
        destination_account_id,
        amount,
        transaction_date
    FROM
        transactions
    WHERE
        transaction_type = 'Transfer'
        AND status = 'Success'
        AND amount >= 50000
        AND destination_account_id IS NOT NULL
),
hop_1 AS (
    -- First hop: A → B
    SELECT
        t1.transaction_id                          AS hop1_txn_id,
        t1.source_account_id                       AS account_a,
        t1.destination_account_id                  AS account_b,
        t1.amount                                  AS hop1_amount,
        t1.transaction_date                        AS hop1_date
    FROM
        transfers t1
),
hop_2 AS (
    -- Second hop: B → C (within 48 hours of hop 1, ≥ 70 % forwarded)
    SELECT
        h1.hop1_txn_id,
        h1.account_a,
        h1.account_b,
        h1.hop1_amount,
        h1.hop1_date,
        t2.transaction_id                          AS hop2_txn_id,
        t2.destination_account_id                  AS account_c,
        t2.amount                                  AS hop2_amount,
        t2.transaction_date                        AS hop2_date
    FROM
        hop_1 h1
        JOIN transfers t2
            ON  t2.source_account_id = h1.account_b
            AND t2.transaction_date  > h1.hop1_date
            AND t2.transaction_date <= h1.hop1_date + INTERVAL '48 hours'
            AND t2.amount           >= h1.hop1_amount * 0.70
    WHERE
        t2.destination_account_id <> h1.account_a  -- avoid circular A→B→A
)
SELECT
    h2.account_a,
    ca.first_name || ' ' || ca.last_name           AS customer_a,
    h2.account_b,
    cb.first_name || ' ' || cb.last_name           AS customer_b,
    h2.account_c,
    cc.first_name || ' ' || cc.last_name           AS customer_c,
    h2.hop1_amount,
    h2.hop1_date,
    h2.hop2_amount,
    h2.hop2_date,
    h2.hop2_date - h2.hop1_date                    AS total_chain_time,
    ROUND(
        h2.hop2_amount / h2.hop1_amount * 100, 2
    )                                              AS pct_forwarded,
    'TRANSFER_CHAIN_A_B_C'                         AS alert_type,
    'Rapid multi-hop transfer chain detected — potential layering network'
                                                   AS alert_reason
FROM
    hop_2 h2
    -- Resolve customer names for each account in the chain
    JOIN accounts  aa ON h2.account_a = aa.account_id
    JOIN customers ca ON aa.customer_id = ca.customer_id
    JOIN accounts  ab ON h2.account_b = ab.account_id
    JOIN customers cb ON ab.customer_id = cb.customer_id
    JOIN accounts  ac ON h2.account_c = ac.account_id
    JOIN customers cc ON ac.customer_id = cc.customer_id
ORDER BY
    h2.hop1_date DESC;


-- =============================================================================
-- END OF FILE: 02_aml_monitoring.sql
-- =============================================================================
