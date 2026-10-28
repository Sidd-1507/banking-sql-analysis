-- =============================================================================
-- File:        procedures/01_stored_procedures.sql
-- Project:     Banking Transaction Analysis
-- Description: Production-grade stored procedures for account statement
--              generation, customer 360 profiles, daily balance snapshots,
--              fraud flagging, interest calculation, and monthly reporting.
-- Author:      Data Engineering Team
-- Date:        2026-10-28
-- Dialect:     MySQL 8.0+
-- =============================================================================

USE banking_db;

-- =============================================================================
-- PREREQUISITE: Create the alerts table used by sp_flag_suspicious_transactions
-- =============================================================================
CREATE TABLE IF NOT EXISTS fraud_alerts (
    alert_id            INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id      INT          NOT NULL,
    account_id          INT          NOT NULL,
    customer_id         INT          NOT NULL,
    alert_type          VARCHAR(50)  NOT NULL,
    alert_severity      VARCHAR(20)  NOT NULL,
    alert_description   TEXT,
    transaction_amount  DECIMAL(15,2),
    transaction_date    TIMESTAMP,
    flagged_at          TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    reviewed            BOOLEAN      DEFAULT FALSE,
    reviewed_by         VARCHAR(100),
    reviewed_at         TIMESTAMP,
    resolution          VARCHAR(50),
    INDEX idx_fraud_alerts_account (account_id, flagged_at),
    INDEX idx_fraud_alerts_severity (alert_severity, reviewed)
) ENGINE=InnoDB;


-- =============================================================================
-- PREREQUISITE: Create the daily balance snapshot table
-- =============================================================================
CREATE TABLE IF NOT EXISTS daily_balance_snapshot (
    snapshot_id    INT AUTO_INCREMENT PRIMARY KEY,
    account_id     INT            NOT NULL,
    snapshot_date  DATE           NOT NULL,
    balance        DECIMAL(15,2)  NOT NULL,
    captured_at    TIMESTAMP      DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_account_date (account_id, snapshot_date),
    INDEX idx_balance_snapshot_date (snapshot_date, account_id)
) ENGINE=InnoDB;


-- =============================================================================
-- 1. sp_get_account_statement
-- =============================================================================
-- PURPOSE: Generate a formatted account statement for a specified date range,
-- including a running balance after each transaction.
-- PARAMETERS:
--   p_account_id  INT    — Target account ID
--   p_start_date  DATE   — Statement period start (inclusive)
--   p_end_date    DATE   — Statement period end (inclusive)
-- =============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS sp_get_account_statement //
CREATE PROCEDURE sp_get_account_statement(
    IN p_account_id INT,
    IN p_start_date DATE,
    IN p_end_date   DATE
)
BEGIN
    DECLARE v_opening_balance DECIMAL(15,2) DEFAULT 0.00;
    DECLARE v_customer_name   VARCHAR(100);
    DECLARE v_account_type    VARCHAR(50);
    DECLARE v_branch_name     VARCHAR(100);

    -- Fetch account metadata
    SELECT
        CONCAT(c.first_name, ' ', c.last_name),
        a.account_type,
        b.branch_name
    INTO
        v_customer_name,
        v_account_type,
        v_branch_name
    FROM
        accounts a
        JOIN customers c ON a.customer_id = c.customer_id
        JOIN branches  b ON a.branch_id   = b.branch_id
    WHERE
        a.account_id = p_account_id;

    -- Compute opening balance: current balance minus all successful activity from start_date onward
    SELECT
        a.current_balance - COALESCE(
            SUM(CASE
                WHEN t.transaction_type IN ('Deposit', 'Transfer_In', 'Interest_Credit') THEN t.amount
                WHEN t.transaction_type IN ('Withdrawal', 'Transfer_Out', 'Fee_Debit')   THEN -t.amount
                ELSE 0
            END), 0
        )
    INTO v_opening_balance
    FROM
        accounts a
        LEFT JOIN transactions t
            ON  t.account_id = a.account_id
            AND t.status     = 'Success'
            AND t.transaction_date >= p_start_date
    WHERE
        a.account_id = p_account_id
    GROUP BY
        a.current_balance;

    -- Return statement result set
    SELECT
        v_customer_name                            AS customer_name,
        p_account_id                               AS account_id,
        v_account_type                             AS account_type,
        v_branch_name                              AS branch_name,
        p_start_date                               AS statement_period_start,
        p_end_date                                 AS statement_period_end,
        v_opening_balance                          AS opening_balance,
        t.transaction_id,
        t.transaction_date,
        t.transaction_type,
        CASE WHEN t.transaction_type IN ('Deposit', 'Transfer_In', 'Interest_Credit')
             THEN t.amount ELSE NULL END           AS credit,
        CASE WHEN t.transaction_type IN ('Withdrawal', 'Transfer_Out', 'Fee_Debit')
             THEN t.amount ELSE NULL END           AS debit,
        t.channel,
        v_opening_balance + SUM(
            CASE
                WHEN t.transaction_type IN ('Deposit', 'Transfer_In', 'Interest_Credit') THEN  t.amount
                WHEN t.transaction_type IN ('Withdrawal', 'Transfer_Out', 'Fee_Debit')   THEN -t.amount
                ELSE 0
            END
        ) OVER (
            ORDER BY t.transaction_date, t.transaction_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                          AS running_balance,
        t.balance_after                            AS ledger_balance_after
    FROM
        transactions t
    WHERE
        t.account_id = p_account_id
        AND t.status = 'Success'
        AND t.transaction_date >= p_start_date
        AND t.transaction_date < DATE_ADD(p_end_date, INTERVAL 1 DAY)
    ORDER BY
        t.transaction_date,
        t.transaction_id;
END //


-- =============================================================================
-- 2. sp_get_customer_360
-- =============================================================================
-- PURPOSE: Return a comprehensive customer profile in a single call.
-- =============================================================================

DROP PROCEDURE IF EXISTS sp_get_customer_360 //
CREATE PROCEDURE sp_get_customer_360(
    IN p_customer_id INT
)
BEGIN
    SELECT 'Personal Info' AS section, 'Full Name' AS metric_name, CONCAT(c.first_name, ' ', c.last_name) AS metric_value
    FROM customers c WHERE c.customer_id = p_customer_id
    UNION ALL
    SELECT 'Personal Info', 'Email', c.email FROM customers c WHERE c.customer_id = p_customer_id
    UNION ALL
    SELECT 'Personal Info', 'Phone', COALESCE(c.phone, 'N/A') FROM customers c WHERE c.customer_id = p_customer_id
    UNION ALL
    SELECT 'Personal Info', 'City', c.city FROM customers c WHERE c.customer_id = p_customer_id
    UNION ALL
    SELECT 'Personal Info', 'KYC Status', c.kyc_status FROM customers c WHERE c.customer_id = p_customer_id
    UNION ALL
    SELECT 'Personal Info', 'Annual Income (₹)', CAST(c.annual_income AS CHAR) FROM customers c WHERE c.customer_id = p_customer_id
    UNION ALL
    SELECT 'Account Summary', 'Total Accounts', CAST(COUNT(*) AS CHAR) FROM accounts WHERE customer_id = p_customer_id
    UNION ALL
    SELECT 'Account Summary', 'Active Accounts', CAST(COUNT(CASE WHEN status = 'Active' THEN 1 END) AS CHAR) FROM accounts WHERE customer_id = p_customer_id
    UNION ALL
    SELECT 'Account Summary', 'Total Balance (₹)', CAST(COALESCE(SUM(CASE WHEN status = 'Active' THEN current_balance END), 0) AS CHAR) FROM accounts WHERE customer_id = p_customer_id
    UNION ALL
    SELECT 'Transaction Activity', 'Total Transactions', CAST(COUNT(*) AS CHAR)
    FROM transactions t JOIN accounts a ON t.account_id = a.account_id
    WHERE a.customer_id = p_customer_id AND t.status = 'Success'
    UNION ALL
    SELECT 'Transaction Activity', 'Lifetime Deposits (₹)', CAST(COALESCE(SUM(CASE WHEN t.transaction_type = 'Deposit' THEN t.amount END), 0) AS CHAR)
    FROM transactions t JOIN accounts a ON t.account_id = a.account_id
    WHERE a.customer_id = p_customer_id AND t.status = 'Success'
    UNION ALL
    SELECT 'Transaction Activity', 'Lifetime Withdrawals (₹)', CAST(COALESCE(SUM(CASE WHEN t.transaction_type = 'Withdrawal' THEN t.amount END), 0) AS CHAR)
    FROM transactions t JOIN accounts a ON t.account_id = a.account_id
    WHERE a.customer_id = p_customer_id AND t.status = 'Success'
    UNION ALL
    SELECT 'Loan Portfolio', 'Active Loans', CAST(COUNT(CASE WHEN l.status = 'Active' THEN 1 END) AS CHAR)
    FROM loans l WHERE l.customer_id = p_customer_id
    UNION ALL
    SELECT 'Loan Portfolio', 'Total Loan Outstanding (₹)', CAST(COALESCE(SUM(CASE WHEN l.status = 'Active' THEN l.outstanding_amount END), 0) AS CHAR)
    FROM loans l WHERE l.customer_id = p_customer_id
    UNION ALL
    SELECT 'Card Status', 'Active Cards', CAST(COUNT(CASE WHEN cd.status = 'Active' THEN 1 END) AS CHAR)
    FROM cards cd WHERE cd.customer_id = p_customer_id;
END //


-- =============================================================================
-- 3. sp_daily_balance_snapshot
-- =============================================================================
-- PURPOSE: Capture an end-of-day balance snapshot for all active accounts.
-- =============================================================================

DROP PROCEDURE IF EXISTS sp_daily_balance_snapshot //
CREATE PROCEDURE sp_daily_balance_snapshot()
BEGIN
    INSERT INTO daily_balance_snapshot (account_id, snapshot_date, balance)
    SELECT
        a.account_id,
        CURRENT_DATE,
        a.current_balance
    FROM
        accounts a
    WHERE
        a.status = 'Active'
    ON DUPLICATE KEY UPDATE
        balance     = VALUES(balance),
        captured_at = CURRENT_TIMESTAMP;

    SELECT
        CONCAT('Daily balance snapshot completed for ', CURRENT_DATE, '. Rows affected: ', ROW_COUNT()) AS result;
END //


-- =============================================================================
-- 4. sp_flag_suspicious_transactions
-- =============================================================================
-- PURPOSE: Execute all fraud detection rules and insert flagged transactions
-- into the fraud_alerts table.
-- =============================================================================

DROP PROCEDURE IF EXISTS sp_flag_suspicious_transactions //
CREATE PROCEDURE sp_flag_suspicious_transactions()
BEGIN
    -- RULE 1: High-value transactions (> ₹1,00,000)
    INSERT INTO fraud_alerts (
        transaction_id, account_id, customer_id,
        alert_type, alert_severity, alert_description,
        transaction_amount, transaction_date
    )
    SELECT
        t.transaction_id,
        t.account_id,
        a.customer_id,
        'HIGH_VALUE_TRANSACTION',
        CASE
            WHEN t.amount > 500000 THEN 'CRITICAL'
            WHEN t.amount > 200000 THEN 'HIGH'
            ELSE 'MEDIUM'
        END,
        CONCAT('Transaction of ₹', t.amount, ' exceeds ₹1,00,000 threshold'),
        t.amount,
        t.transaction_date
    FROM
        transactions t
        JOIN accounts a ON t.account_id = a.account_id
    WHERE
        t.amount > 100000
        AND t.status = 'Success'
        AND NOT EXISTS (
            SELECT 1 FROM fraud_alerts fa
            WHERE fa.transaction_id = t.transaction_id
            AND   fa.alert_type     = 'HIGH_VALUE_TRANSACTION'
        );

    -- RULE 2: Odd-hour transactions (12 AM – 5 AM)
    INSERT INTO fraud_alerts (
        transaction_id, account_id, customer_id,
        alert_type, alert_severity, alert_description,
        transaction_amount, transaction_date
    )
    SELECT
        t.transaction_id,
        t.account_id,
        a.customer_id,
        'ODD_HOUR_TRANSACTION',
        'HIGH',
        CONCAT('Transaction at ', t.transaction_date, ' — outside normal banking hours'),
        t.amount,
        t.transaction_date
    FROM
        transactions t
        JOIN accounts a ON t.account_id = a.account_id
    WHERE
        HOUR(t.transaction_date) BETWEEN 0 AND 4
        AND t.status = 'Success'
        AND NOT EXISTS (
            SELECT 1 FROM fraud_alerts fa
            WHERE fa.transaction_id = t.transaction_id
            AND   fa.alert_type     = 'ODD_HOUR_TRANSACTION'
        );

    -- RULE 3: Rapid successive transactions (< 5 minutes apart)
    INSERT INTO fraud_alerts (
        transaction_id, account_id, customer_id,
        alert_type, alert_severity, alert_description,
        transaction_amount, transaction_date
    )
    SELECT
        curr.transaction_id,
        curr.account_id,
        a.customer_id,
        'RAPID_SUCCESSION',
        'HIGH',
        CONCAT('Transaction within 5 minutes of previous transaction on same account'),
        curr.amount,
        curr.transaction_date
    FROM (
        SELECT
            t.transaction_id,
            t.account_id,
            t.amount,
            t.transaction_date,
            LAG(t.transaction_date) OVER (
                PARTITION BY t.account_id
                ORDER BY     t.transaction_date
            ) AS prev_date
        FROM
            transactions t
        WHERE
            t.status = 'Success'
    ) curr
    JOIN accounts a ON curr.account_id = a.account_id
    WHERE
        curr.prev_date IS NOT NULL
        AND TIMESTAMPDIFF(MINUTE, curr.prev_date, curr.transaction_date) <= 5
        AND NOT EXISTS (
            SELECT 1 FROM fraud_alerts fa
            WHERE fa.transaction_id = curr.transaction_id
            AND   fa.alert_type     = 'RAPID_SUCCESSION'
        );

    -- Return summary count of active alerts
    SELECT
        alert_type,
        alert_severity,
        COUNT(*) AS total_alerts
    FROM
        fraud_alerts
    GROUP BY
        alert_type,
        alert_severity
    ORDER BY
        total_alerts DESC;
END //


-- =============================================================================
-- 5. sp_calculate_interest
-- =============================================================================
-- PURPOSE: Calculate and credit monthly interest for active Savings accounts.
-- =============================================================================

DROP PROCEDURE IF EXISTS sp_calculate_interest //
CREATE PROCEDURE sp_calculate_interest(
    IN p_annual_rate DECIMAL(5,2)
)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_acc_id INT;
    DECLARE v_bal DECIMAL(15,2);
    DECLARE v_int_amt DECIMAL(15,2);
    DECLARE v_total_credited DECIMAL(15,2) DEFAULT 0.00;
    DECLARE v_count INT DEFAULT 0;

    DECLARE cur CURSOR FOR
        SELECT account_id, current_balance
        FROM accounts
        WHERE account_type = 'Savings' AND status = 'Active' AND current_balance > 0;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    IF p_annual_rate IS NULL THEN
        SET p_annual_rate = 3.50;
    END IF;

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO v_acc_id, v_bal;
        IF done THEN
            LEAVE read_loop;
        END IF;

        SET v_int_amt = ROUND(v_bal * (p_annual_rate / 100.0 / 12.0), 2);

        IF v_int_amt >= 1.00 THEN
            INSERT INTO transactions (
                account_id, transaction_type, amount, balance_after,
                transaction_date, description, channel, status
            ) VALUES (
                v_acc_id, 'Interest_Credit', v_int_amt, v_bal + v_int_amt,
                CURRENT_TIMESTAMP, 'Monthly Savings Interest Credit', 'Branch', 'Success'
            );

            UPDATE accounts
            SET current_balance = current_balance + v_int_amt
            WHERE account_id = v_acc_id;

            SET v_total_credited = v_total_credited + v_int_amt;
            SET v_count = v_count + 1;
        END IF;
    END LOOP;

    CLOSE cur;

    SELECT
        v_count AS accounts_credited,
        v_total_credited AS total_interest_disbursed,
        p_annual_rate AS applied_annual_rate;
END //


-- =============================================================================
-- 6. sp_generate_monthly_report
-- =============================================================================
-- PURPOSE: Generate a comprehensive monthly operations report.
-- =============================================================================

DROP PROCEDURE IF EXISTS sp_generate_monthly_report //
CREATE PROCEDURE sp_generate_monthly_report(
    IN p_month INT,
    IN p_year  INT
)
BEGIN
    DECLARE v_start_date DATE;
    DECLARE v_end_date   DATE;

    SET v_start_date = STR_TO_DATE(CONCAT(p_year, '-', LPAD(p_month, 2, '00'), '-01'), '%Y-%m-%d');
    SET v_end_date   = LAST_DAY(v_start_date);

    SELECT '00. Report Info' AS report_section, 'Report Period' AS metric_name, CONCAT(v_start_date, ' to ', v_end_date) AS metric_value
    UNION ALL
    SELECT '01. Transaction Summary', 'Total Transactions', CAST(COUNT(*) AS CHAR)
    FROM transactions WHERE transaction_date >= v_start_date AND transaction_date < DATE_ADD(v_end_date, INTERVAL 1 DAY)
    UNION ALL
    SELECT '01. Transaction Summary', 'Successful Transactions', CAST(COUNT(CASE WHEN status = 'Success' THEN 1 END) AS CHAR)
    FROM transactions WHERE transaction_date >= v_start_date AND transaction_date < DATE_ADD(v_end_date, INTERVAL 1 DAY)
    UNION ALL
    SELECT '01. Transaction Summary', 'Success Rate (%)', CAST(ROUND(COUNT(CASE WHEN status = 'Success' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS CHAR)
    FROM transactions WHERE transaction_date >= v_start_date AND transaction_date < DATE_ADD(v_end_date, INTERVAL 1 DAY)
    UNION ALL
    SELECT '01. Transaction Summary', 'Total Volume (₹)', CAST(COALESCE(SUM(CASE WHEN status = 'Success' THEN amount END), 0) AS CHAR)
    FROM transactions WHERE transaction_date >= v_start_date AND transaction_date < DATE_ADD(v_end_date, INTERVAL 1 DAY)
    UNION ALL
    SELECT '02. Fund Flow', 'Total Deposits (₹)', CAST(COALESCE(SUM(CASE WHEN transaction_type = 'Deposit' AND status = 'Success' THEN amount END), 0) AS CHAR)
    FROM transactions WHERE transaction_date >= v_start_date AND transaction_date < DATE_ADD(v_end_date, INTERVAL 1 DAY)
    UNION ALL
    SELECT '02. Fund Flow', 'Total Withdrawals (₹)', CAST(COALESCE(SUM(CASE WHEN transaction_type = 'Withdrawal' AND status = 'Success' THEN amount END), 0) AS CHAR)
    FROM transactions WHERE transaction_date >= v_start_date AND transaction_date < DATE_ADD(v_end_date, INTERVAL 1 DAY)
    UNION ALL
    SELECT '03. Channel Performance', 'UPI Volume', CAST(COUNT(CASE WHEN channel = 'UPI' AND status = 'Success' THEN 1 END) AS CHAR)
    FROM transactions WHERE transaction_date >= v_start_date AND transaction_date < DATE_ADD(v_end_date, INTERVAL 1 DAY)
    UNION ALL
    SELECT '03. Channel Performance', 'Online/Mobile Volume', CAST(COUNT(CASE WHEN channel IN ('Online', 'Mobile') AND status = 'Success' THEN 1 END) AS CHAR)
    FROM transactions WHERE transaction_date >= v_start_date AND transaction_date < DATE_ADD(v_end_date, INTERVAL 1 DAY)
    UNION ALL
    SELECT '04. Fraud & Compliance', 'High-Value Txns (> ₹1L)', CAST(COUNT(CASE WHEN amount > 100000 AND status = 'Success' THEN 1 END) AS CHAR)
    FROM transactions WHERE transaction_date >= v_start_date AND transaction_date < DATE_ADD(v_end_date, INTERVAL 1 DAY)
    UNION ALL
    SELECT '04. Fraud & Compliance', 'Odd-Hour Txns', CAST(COUNT(CASE WHEN HOUR(transaction_date) BETWEEN 0 AND 4 AND status = 'Success' THEN 1 END) AS CHAR)
    FROM transactions WHERE transaction_date >= v_start_date AND transaction_date < DATE_ADD(v_end_date, INTERVAL 1 DAY);
END //

DELIMITER ;
