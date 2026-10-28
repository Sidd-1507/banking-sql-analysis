-- =============================================================================
-- File:        03_create_indexes.sql
-- Description: Additional performance indexes beyond the baseline set defined
--              in 02_create_tables.sql. These cover composite lookups, range
--              scans, channel analytics, loan/card queries, and full-text
--              search on transaction narrations.
-- Project:     Banking Transaction Analysis
-- Author:      SQL Developer
-- Date:        2026-10-28
-- Dialect:     MySQL 8.0+  (FULLTEXT index is MySQL-specific; see note below)
-- =============================================================================

USE banking_db;

-- -----------------------------------------------------------------------------
-- 1. COMPOSITE INDEX – transactions(account_id, transaction_date, transaction_type)
--
--    WHY:  The most common analytical query pattern is:
--          "Show all <type> transactions for account X between date A and B."
--          A three-column composite index lets MySQL satisfy the WHERE clause
--          entirely from the B-Tree without a table scan, and the column order
--          matches the selectivity hierarchy (account → date range → type).
-- -----------------------------------------------------------------------------
CREATE INDEX idx_txn_acct_date_type
    ON transactions (account_id, transaction_date, transaction_type);

-- -----------------------------------------------------------------------------
-- 2. INDEX – transactions(amount)
--
--    WHY:  Range queries such as "find all transactions above ₹1,00,000" or
--          aggregate queries (SUM, AVG) that filter by amount benefit from a
--          B-Tree index that supports efficient range scans (>, <, BETWEEN).
-- -----------------------------------------------------------------------------
CREATE INDEX idx_txn_amount
    ON transactions (amount);

-- -----------------------------------------------------------------------------
-- 3. INDEX – transactions(channel)
--
--    WHY:  Channel-level analytics (e.g. "% of transactions via UPI vs ATM")
--          and fraud detection rules that flag unusual channel usage need fast
--          grouping and filtering by channel.
-- -----------------------------------------------------------------------------
CREATE INDEX idx_txn_channel
    ON transactions (channel);

-- -----------------------------------------------------------------------------
-- 4. COMPOSITE INDEX – loans(customer_id, status)
--
--    WHY:  Loan portfolio dashboards frequently query "all active loans for
--          customer X" or "all defaulted loans across customers." The composite
--          index covers both single-customer lookups and status-only scans via
--          an index skip-scan (MySQL 8.0+).
-- -----------------------------------------------------------------------------
CREATE INDEX idx_loans_cust_status
    ON loans (customer_id, status);

-- -----------------------------------------------------------------------------
-- 5. INDEX – cards(customer_id)
--
--    WHY:  Customer profile pages and support screens need to list all cards
--          belonging to a customer. This index avoids a full table scan on the
--          cards table for such lookups.
-- -----------------------------------------------------------------------------
CREATE INDEX idx_cards_customer
    ON cards (customer_id);

-- -----------------------------------------------------------------------------
-- 6. FULL-TEXT INDEX – transactions(description)       *** MySQL-specific ***
--
--    WHY:  Free-text search on the transaction narration field (e.g. searching
--          for "salary" or "rent" across millions of rows) is not efficiently
--          served by a B-Tree index. A FULLTEXT index enables natural-language
--          and boolean-mode searches directly inside the database.
--
--    NOTE: This syntax is MySQL-specific. For PostgreSQL, use a GIN index on
--          a tsvector column instead:
--
--          ALTER TABLE transactions
--              ADD COLUMN description_tsv tsvector
--              GENERATED ALWAYS AS (to_tsvector('english', description)) STORED;
--          CREATE INDEX idx_txn_desc_fts ON transactions USING GIN (description_tsv);
-- -----------------------------------------------------------------------------
CREATE FULLTEXT INDEX idx_txn_description_ft
    ON transactions (description);
