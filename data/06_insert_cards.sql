-- =============================================================================
-- File:        06_insert_cards.sql
-- Description: Insert 40 debit and credit cards linked to customers and accounts.
--              Includes Visa, MasterCard, and RuPay across different expiry dates,
--              credit limits, and statuses (Active, Blocked, Expired, Cancelled).
-- Project:     Banking Transaction Analysis
-- Author:      SQL Analysis Project
-- Date:        2024-01-01
-- =============================================================================

USE banking_db;

INSERT INTO cards (
    card_id, customer_id, account_id, card_number, card_type,
    card_network, credit_limit, expiry_date, status
)
VALUES
    -- Mumbai (Branch 1 & 2)
    (1,  1,  1,  '4111222233334401', 'Debit',  'Visa',       NULL,      '2027-05-31', 'Active'),
    (2,  1,  1,  '5222333344445501', 'Credit', 'MasterCard', 250000.00, '2026-11-30', 'Active'),
    (3,  2,  3,  '6071444455556601', 'Debit',  'RuPay',      NULL,      '2028-02-28', 'Active'),
    (4,  3,  7,  '4111222233334402', 'Debit',  'Visa',       NULL,      '2026-08-31', 'Active'),
    (5,  3,  8,  '5222333344445502', 'Credit', 'MasterCard', 500000.00, '2027-03-31', 'Active'),
    (6,  4,  9,  '6071444455556602', 'Debit',  'RuPay',      NULL,      '2027-10-31', 'Active'),
    (7,  5,  4,  '4111222233334403', 'Debit',  'Visa',       NULL,      '2026-04-30', 'Active'),
    (8,  5,  5,  '4111222233334404', 'Credit', 'Visa',       300000.00, '2026-09-30', 'Active'),
    (9,  6,  10, '5222333344445503', 'Debit',  'MasterCard', NULL,      '2025-12-31', 'Active'),

    -- Delhi (Branch 3 & 4)
    (10, 7,  12, '4111222233334405', 'Debit',  'Visa',       NULL,      '2027-01-31', 'Active'),
    (11, 7,  13, '5222333344445504', 'Credit', 'MasterCard', 400000.00, '2027-07-31', 'Active'),
    (12, 8,  14, '6071444455556603', 'Debit',  'RuPay',      NULL,      '2028-03-31', 'Active'),
    (13, 9,  19, '4111222233334406', 'Debit',  'Visa',       NULL,      '2026-06-30', 'Active'),
    (14, 9,  19, '6071444455556604', 'Credit', 'RuPay',      150000.00, '2026-12-31', 'Active'),
    (15, 10, 20, '5222333344445505', 'Debit',  'MasterCard', NULL,      '2027-08-31', 'Active'),
    (16, 11, 15, '4111222233334407', 'Debit',  'Visa',       NULL,      '2025-06-30', 'Active'),
    (17, 12, 22, '6071444455556605', 'Debit',  'RuPay',      NULL,      '2024-01-15', 'Expired'),

    -- Bangalore (Branch 5)
    (18, 13, 21, '4111222233334408', 'Debit',  'Visa',       NULL,      '2027-09-30', 'Active'),
    (19, 13, 21, '5222333344445506', 'Credit', 'MasterCard', 350000.00, '2027-11-30', 'Active'),
    (20, 14, 23, '6071444455556606', 'Debit',  'RuPay',      NULL,      '2028-04-30', 'Active'),
    (21, 15, 25, '4111222233334409', 'Debit',  'Visa',       NULL,      '2026-07-31', 'Active'),
    (22, 16, 27, '5222333344445507', 'Debit',  'MasterCard', NULL,      '2027-02-28', 'Active'),
    (23, 17, 28, '6071444455556607', 'Debit',  'RuPay',      NULL,      '2026-10-31', 'Blocked'),

    -- Pune (Branch 6)
    (24, 19, 31, '4111222233334410', 'Debit',  'Visa',       NULL,      '2027-12-31', 'Active'),
    (25, 19, 31, '5222333344445508', 'Credit', 'MasterCard', 200000.00, '2026-05-31', 'Active'),
    (26, 20, 33, '6071444455556608', 'Debit',  'RuPay',      NULL,      '2028-06-30', 'Active'),
    (27, 21, 34, '4111222233334411', 'Debit',  'Visa',       NULL,      '2026-11-30', 'Active'),
    (28, 22, 35, '5222333344445509', 'Debit',  'MasterCard', NULL,      '2027-04-30', 'Active'),

    -- Hyderabad (Branch 7)
    (29, 25, 41, '4111222233334412', 'Debit',  'Visa',       NULL,      '2027-08-31', 'Active'),
    (30, 25, 41, '5222333344445510', 'Credit', 'MasterCard', 300000.00, '2027-10-31', 'Active'),
    (31, 26, 43, '6071444455556609', 'Debit',  'RuPay',      NULL,      '2028-01-31', 'Active'),
    (32, 27, 44, '4111222233334413', 'Debit',  'Visa',       NULL,      '2026-03-31', 'Active'),
    (33, 28, 46, '5222333344445511', 'Debit',  'MasterCard', NULL,      '2025-11-30', 'Blocked'),

    -- Chennai (Branch 8)
    (34, 29, 47, '4111222233334414', 'Debit',  'Visa',       NULL,      '2027-03-31', 'Active'),
    (35, 30, 49, '6071444455556610', 'Debit',  'RuPay',      NULL,      '2026-07-31', 'Cancelled'),
    (36, 31, 52, '5222333344445512', 'Debit',  'MasterCard', NULL,      '2027-05-31', 'Active'),

    -- Kolkata (Branch 9)
    (37, 32, 57, '4111222233334415', 'Debit',  'Visa',       NULL,      '2027-11-30', 'Active'),
    (38, 34, 59, '5222333344445513', 'Credit', 'MasterCard', 450000.00, '2027-12-31', 'Active'),

    -- Ahmedabad (Branch 10)
    (39, 37, 62, '4111222233334416', 'Debit',  'Visa',       NULL,      '2027-06-30', 'Active'),
    (40, 37, 62, '6071444455556611', 'Credit', 'RuPay',      200000.00, '2028-05-31', 'Active');
