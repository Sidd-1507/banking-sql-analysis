-- =============================================================================
-- File:        06_card_usage_analytics.sql
-- Project:     Banking Transaction Analysis
-- Description: Card usage KPIs — type and network distribution, credit
--              utilisation, upcoming expirations, and blocked/inactive cards.
-- Author:      Data Analytics Team
-- Date:        2026-10-28
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Card Type Distribution (Debit vs Credit)
-- -----------------------------------------------------------------------------
-- Business Purpose : Shows the mix of debit and credit cards in the bank's
--                    portfolio. A healthy credit-to-debit ratio indicates
--                    cross-sell success and revenue potential from interchange
--                    and interest income.
-- Expected Output  : One row per card_type — card_type, card_count,
--                    pct_of_total.
-- -----------------------------------------------------------------------------

WITH type_counts AS (
    SELECT
        cd.card_type,
        COUNT(cd.card_id)                                  AS card_count
    FROM
        cards AS cd
    GROUP BY
        cd.card_type
)
SELECT
    card_type,
    card_count,
    ROUND(
        card_count * 100.0 / NULLIF(SUM(card_count) OVER (), 0), 2
    )                                                       AS pct_of_total
FROM
    type_counts
ORDER BY
    card_count DESC;


-- -----------------------------------------------------------------------------
-- 2. Card Network Distribution
-- -----------------------------------------------------------------------------
-- Business Purpose : Breaks down cards by payment network (Visa, Mastercard,
--                    RuPay, Amex, etc.). Helps in negotiating interchange
--                    fees, understanding merchant acceptance, and planning
--                    co-branded card partnerships.
-- Expected Output  : One row per network — card_network, card_count,
--                    pct_of_total.
-- -----------------------------------------------------------------------------

WITH network_counts AS (
    SELECT
        cd.card_network,
        COUNT(cd.card_id)                                  AS card_count
    FROM
        cards AS cd
    GROUP BY
        cd.card_network
)
SELECT
    card_network,
    card_count,
    ROUND(
        card_count * 100.0 / NULLIF(SUM(card_count) OVER (), 0), 2
    )                                                       AS pct_of_total
FROM
    network_counts
ORDER BY
    card_count DESC;


-- -----------------------------------------------------------------------------
-- 3. Credit Utilisation Ratio per Card
-- -----------------------------------------------------------------------------
-- Business Purpose : Measures how much of each credit card's limit is being
--                    used. High utilisation (>75 %) may indicate financial
--                    stress; low utilisation (<10 %) may indicate an
--                    underused product ripe for activation campaigns.
-- Assumption       : The cards table has a `credit_limit` column and the
--                    transactions table tracks card-based spend via a
--                    `card_id` column (or we link via account).
-- Expected Output  : One row per credit card — card_id, customer_name,
--                    credit_limit, total_credit_spend, utilisation_pct,
--                    utilisation_band.
-- -----------------------------------------------------------------------------

WITH credit_spend AS (
    SELECT
        cd.card_id,
        cd.customer_id,
        cd.credit_limit,
        COALESCE(SUM(t.amount), 0)                         AS total_credit_spend
    FROM
        cards        AS cd
        LEFT JOIN accounts     AS a  ON cd.customer_id = a.customer_id
        LEFT JOIN transactions AS t  ON a.account_id   = t.account_id
                                    AND t.transaction_type = 'Withdrawal'
    WHERE
        cd.card_type = 'Credit'
    GROUP BY
        cd.card_id,
        cd.customer_id,
        cd.credit_limit
)
SELECT
    cs.card_id,
    CONCAT(c.first_name, ' ', c.last_name)                 AS customer_name,
    cs.credit_limit,
    cs.total_credit_spend,
    CASE
        WHEN cs.credit_limit = 0 THEN NULL
        ELSE ROUND(
            cs.total_credit_spend * 100.0 / cs.credit_limit, 2
        )
    END                                                     AS utilisation_pct,
    CASE
        WHEN cs.credit_limit = 0 THEN 'N/A'
        WHEN cs.total_credit_spend * 100.0 / cs.credit_limit > 75 THEN 'High (>75%)'
        WHEN cs.total_credit_spend * 100.0 / cs.credit_limit > 50 THEN 'Medium (50-75%)'
        WHEN cs.total_credit_spend * 100.0 / cs.credit_limit > 10 THEN 'Low (10-50%)'
        ELSE 'Very Low (<10%)'
    END                                                     AS utilisation_band
FROM
    credit_spend AS cs
    INNER JOIN customers AS c  ON cs.customer_id = c.customer_id
ORDER BY
    utilisation_pct DESC NULLS LAST;


-- -----------------------------------------------------------------------------
-- 4. Cards Expiring in the Next 3 Months
-- -----------------------------------------------------------------------------
-- Business Purpose : Proactive renewal list — cards about to expire need
--                    replacement cards issued to avoid service disruption and
--                    potential customer churn.
-- Expected Output  : One row per expiring card — card_id, customer_name,
--                    card_type, card_network, expiry_date, days_until_expiry.
-- -----------------------------------------------------------------------------

SELECT
    cd.card_id,
    CONCAT(c.first_name, ' ', c.last_name)                 AS customer_name,
    cd.card_type,
    cd.card_network,
    cd.expiry_date,
    CAST(cd.expiry_date - CURRENT_DATE AS INTEGER)          AS days_until_expiry
FROM
    cards     AS cd
    INNER JOIN customers AS c  ON cd.customer_id = c.customer_id
WHERE
    cd.expiry_date BETWEEN CURRENT_DATE
                       AND (CURRENT_DATE + INTERVAL '3 months')
ORDER BY
    cd.expiry_date;


-- -----------------------------------------------------------------------------
-- 5. Blocked / Inactive Cards Report
-- -----------------------------------------------------------------------------
-- Business Purpose : Lists all cards that are currently blocked or inactive.
--                    Operations teams use this to follow up on fraud cases
--                    (blocked) and to run reactivation campaigns (inactive).
-- Expected Output  : One row per blocked/inactive card — card_id,
--                    customer_name, card_type, card_network, card_status,
--                    issued_date.
-- -----------------------------------------------------------------------------

SELECT
    cd.card_id,
    CONCAT(c.first_name, ' ', c.last_name)                 AS customer_name,
    cd.card_type,
    cd.card_network,
    cd.status                                               AS card_status,
    cd.issued_date
FROM
    cards     AS cd
    INNER JOIN customers AS c  ON cd.customer_id = c.customer_id
WHERE
    cd.status IN ('Blocked', 'Inactive')
ORDER BY
    cd.status,
    cd.issued_date;
