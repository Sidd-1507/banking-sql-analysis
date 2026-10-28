-- =============================================================================
-- File:        02_create_tables.sql
-- Description: Creates all core tables for the Banking Transaction Analysis
--              system — customers, branches, accounts, transactions, loans,
--              and cards — with full constraint definitions, foreign keys,
--              check constraints, and performance indexes.
-- Project:     Banking Transaction Analysis
-- Author:      SQL Developer
-- Date:        2026-10-28
-- Dialect:     MySQL 8.0+
-- =============================================================================

USE banking_db;

-- -----------------------------------------------------------------------------
-- 1. CUSTOMERS
--    Stores KYC-verified customer profiles with demographic and income data.
-- -----------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id     INT             PRIMARY KEY AUTO_INCREMENT,
    first_name      VARCHAR(50)     NOT NULL        COMMENT 'Customer first / given name',
    last_name       VARCHAR(50)     NOT NULL        COMMENT 'Customer surname',
    email           VARCHAR(100)    NOT NULL UNIQUE COMMENT 'Primary email – used for login',
    phone           VARCHAR(15)                     COMMENT 'Mobile or landline with country code',
    date_of_birth   DATE                            COMMENT 'DOB for age verification',
    gender          ENUM('Male','Female','Other')   COMMENT 'Self-declared gender',
    address         VARCHAR(255)                    COMMENT 'Street address line',
    city            VARCHAR(50)     NOT NULL        COMMENT 'City of residence',
    state           VARCHAR(50)                     COMMENT 'State / province',
    pin_code        VARCHAR(10)                     COMMENT 'Postal / ZIP code',
    occupation      VARCHAR(50)                     COMMENT 'Current occupation',
    annual_income   DECIMAL(15,2)                   COMMENT 'Declared annual income (INR)',
    kyc_status      ENUM('Verified','Pending','Rejected')
                                    DEFAULT 'Pending'
                                                    COMMENT 'KYC verification state',
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    is_active       BOOLEAN         DEFAULT TRUE    COMMENT 'Soft-delete flag'
) ENGINE=InnoDB
  COMMENT='Master table for bank customers';

-- -----------------------------------------------------------------------------
-- 2. BRANCHES
--    Physical or virtual branch locations with unique IFSC codes.
-- -----------------------------------------------------------------------------
CREATE TABLE branches (
    branch_id       INT             PRIMARY KEY AUTO_INCREMENT,
    branch_name     VARCHAR(100)    NOT NULL        COMMENT 'Human-readable branch name',
    branch_code     VARCHAR(10)     NOT NULL UNIQUE COMMENT 'Internal short code',
    city            VARCHAR(50)     NOT NULL        COMMENT 'City where branch operates',
    state           VARCHAR(50)                     COMMENT 'State / province',
    ifsc_code       VARCHAR(11)     NOT NULL UNIQUE COMMENT 'Indian Financial System Code',
    manager_name    VARCHAR(100)                    COMMENT 'Current branch manager',
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB
  COMMENT='Bank branch directory';

-- -----------------------------------------------------------------------------
-- 3. ACCOUNTS
--    Customer bank accounts linked to a branch. Tracks balances and status.
-- -----------------------------------------------------------------------------
CREATE TABLE accounts (
    account_id      INT             PRIMARY KEY AUTO_INCREMENT,
    customer_id     INT             NOT NULL        COMMENT 'FK → customers',
    branch_id       INT             NOT NULL        COMMENT 'FK → branches',
    account_number  VARCHAR(20)     NOT NULL UNIQUE COMMENT 'Public-facing account number',
    account_type    ENUM('Savings','Current','Fixed Deposit','Recurring Deposit')
                                    NOT NULL        COMMENT 'Product category',
    opening_balance DECIMAL(15,2)   NOT NULL DEFAULT 0.00,
    current_balance DECIMAL(15,2)   NOT NULL DEFAULT 0.00,
    balance         DECIMAL(15,2)   GENERATED ALWAYS AS (current_balance) VIRTUAL COMMENT 'Synonym for current_balance',
    interest_rate   DECIMAL(5,2)    DEFAULT 4.00    COMMENT 'Annual interest rate (%)',
    status          ENUM('Active','Inactive','Frozen','Closed')
                                    DEFAULT 'Active',
    opened_date     DATE            NOT NULL        COMMENT 'Date the account was opened',
    opening_date    DATE            GENERATED ALWAYS AS (opened_date) VIRTUAL COMMENT 'Synonym for opened_date',
    closed_date     DATE            DEFAULT NULL    COMMENT 'NULL while account is open',
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_accounts_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    CONSTRAINT fk_accounts_branch
        FOREIGN KEY (branch_id) REFERENCES branches (branch_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    -- Check constraints
    CONSTRAINT chk_accounts_opening_balance
        CHECK (opening_balance >= 0),
    CONSTRAINT chk_accounts_interest_rate
        CHECK (interest_rate >= 0)
) ENGINE=InnoDB
  COMMENT='Customer bank accounts';

-- -----------------------------------------------------------------------------
-- 4. TRANSACTIONS
--    Immutable ledger of every debit / credit against an account.
-- -----------------------------------------------------------------------------
CREATE TABLE transactions (
    transaction_id      INT             PRIMARY KEY AUTO_INCREMENT,
    account_id          INT             NOT NULL        COMMENT 'FK → accounts',
    transaction_type    ENUM('Deposit','Withdrawal','Transfer_In','Transfer_Out',
                             'Interest_Credit','Fee_Debit')
                                        NOT NULL,
    amount              DECIMAL(15,2)   NOT NULL        COMMENT 'Always positive',
    balance_after       DECIMAL(15,2)   NOT NULL        COMMENT 'Running balance post-txn',
    transaction_date    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    description         VARCHAR(255)                    COMMENT 'Free-text narration',
    reference_number    VARCHAR(30)     UNIQUE          COMMENT 'Bank reference / UTR',
    channel             ENUM('Branch','ATM','Online','Mobile','UPI',
                             'NEFT','RTGS','IMPS')
                                        DEFAULT 'Branch',
    status              ENUM('Success','Failed','Pending','Reversed')
                                        DEFAULT 'Success',
    related_account_id  INT             DEFAULT NULL    COMMENT 'Counter-party account for transfers',
    created_at          TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_transactions_account
        FOREIGN KEY (account_id) REFERENCES accounts (account_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    CONSTRAINT fk_transactions_related_account
        FOREIGN KEY (related_account_id) REFERENCES accounts (account_id)
        ON UPDATE CASCADE ON DELETE SET NULL,

    -- Check constraints
    CONSTRAINT chk_transactions_amount_positive
        CHECK (amount > 0)
) ENGINE=InnoDB
  COMMENT='Immutable transaction ledger';

-- -----------------------------------------------------------------------------
-- 5. LOANS
--    Tracks loan products issued to customers against a linked account.
-- -----------------------------------------------------------------------------
CREATE TABLE loans (
    loan_id             INT             PRIMARY KEY AUTO_INCREMENT,
    customer_id         INT             NOT NULL        COMMENT 'FK → customers',
    account_id          INT             NOT NULL        COMMENT 'FK → accounts (disbursement acct)',
    loan_type           ENUM('Home','Personal','Car','Education','Business','Gold')
                                        NOT NULL,
    principal_amount    DECIMAL(15,2)   NOT NULL,
    loan_amount         DECIMAL(15,2)   GENERATED ALWAYS AS (principal_amount) VIRTUAL COMMENT 'Synonym for principal_amount',
    interest_rate       DECIMAL(5,2)    NOT NULL        COMMENT 'Annual interest rate (%)',
    tenure_months       INT             NOT NULL        COMMENT 'Repayment period in months',
    emi_amount          DECIMAL(15,2)   NOT NULL,
    outstanding_amount  DECIMAL(15,2)   NOT NULL,
    status              ENUM('Active','Closed','Defaulted','Restructured')
                                        DEFAULT 'Active',
    disbursement_date   DATE            NOT NULL,
    created_at          TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_loans_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    CONSTRAINT fk_loans_account
        FOREIGN KEY (account_id) REFERENCES accounts (account_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    -- Check constraints
    CONSTRAINT chk_loans_principal_positive
        CHECK (principal_amount > 0),
    CONSTRAINT chk_loans_interest_rate
        CHECK (interest_rate >= 0),
    CONSTRAINT chk_loans_tenure
        CHECK (tenure_months > 0),
    CONSTRAINT chk_loans_emi
        CHECK (emi_amount > 0),
    CONSTRAINT chk_loans_outstanding
        CHECK (outstanding_amount >= 0)
) ENGINE=InnoDB
  COMMENT='Loan products issued to customers';

-- -----------------------------------------------------------------------------
-- 6. CARDS
--    Debit and credit cards linked to customer accounts.
-- -----------------------------------------------------------------------------
CREATE TABLE cards (
    card_id         INT             PRIMARY KEY AUTO_INCREMENT,
    customer_id     INT             NOT NULL        COMMENT 'FK → customers',
    account_id      INT             NOT NULL        COMMENT 'FK → accounts',
    card_number     VARCHAR(16)     NOT NULL UNIQUE COMMENT 'PAN (store hashed in prod)',
    card_type       ENUM('Debit','Credit')
                                    NOT NULL,
    card_network    ENUM('Visa','MasterCard','RuPay')
                                    NOT NULL,
    credit_limit    DECIMAL(15,2)   DEFAULT NULL    COMMENT 'NULL for debit cards',
    expiry_date     DATE            NOT NULL,
    status          ENUM('Active','Blocked','Expired','Cancelled')
                                    DEFAULT 'Active',
    created_at      TIMESTAMP       DEFAULT CURRENT_TIMESTAMP,

    -- Foreign keys
    CONSTRAINT fk_cards_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,

    CONSTRAINT fk_cards_account
        FOREIGN KEY (account_id) REFERENCES accounts (account_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB
  COMMENT='Customer debit and credit cards';

-- =============================================================================
-- INDEXES – Baseline performance indexes requested in the schema specification
-- =============================================================================

-- Transactions: most queries filter by account + date range
CREATE INDEX idx_txn_account_date
    ON transactions (account_id, transaction_date);

-- Transactions: analytics often group or filter by type
CREATE INDEX idx_txn_type
    ON transactions (transaction_type);

-- Transactions: dashboards filter by status (e.g. failed / pending)
CREATE INDEX idx_txn_status
    ON transactions (status);

-- Accounts: lookup all accounts for a given customer
CREATE INDEX idx_acct_customer
    ON accounts (customer_id);

-- Accounts: filter active vs closed accounts
CREATE INDEX idx_acct_status
    ON accounts (status);

-- Customers: regional analytics and branch assignment queries
CREATE INDEX idx_cust_city
    ON customers (city);

-- Customers: compliance dashboards filter by KYC status
CREATE INDEX idx_cust_kyc
    ON customers (kyc_status);
