-- =============================================================================
-- File:        05_insert_loans.sql
-- Description: Insert 15 realistic loan records across diverse customer profiles,
--              covering Home, Personal, Car, Education, Business, and Gold loans.
--              Includes realistic principal amounts, interest rates, tenures, EMIs,
--              and loan repayment statuses (Active, Closed, Defaulted).
-- Project:     Banking Transaction Analysis
-- Author:      SQL Analysis Project
-- Date:        2024-01-01
-- =============================================================================

USE banking_db;

INSERT INTO loans (
    loan_id, customer_id, account_id, loan_type, principal_amount,
    interest_rate, tenure_months, emi_amount, outstanding_amount,
    status, disbursement_date
)
VALUES
    -- 1. Aarav Mehta (Mumbai - Branch 1) - Home Loan
    (1, 1, 1, 'Home', 4500000.00, 8.50, 240, 39050.00, 4120000.00, 'Active', '2022-03-15'),

    -- 2. Vikram Shah (Mumbai - Branch 2) - Business Loan
    (2, 3, 8, 'Business', 2500000.00, 11.25, 60, 54680.00, 1450000.00, 'Active', '2022-06-20'),

    -- 3. Rohan Joshi (Mumbai - Branch 1) - Car Loan
    (3, 5, 4, 'Car', 850000.00, 9.20, 60, 17730.00, 420000.00, 'Active', '2022-08-10'),

    -- 4. Arjun Sharma (Delhi - Branch 3) - Home Loan
    (4, 7, 12, 'Home', 6000000.00, 8.40, 240, 51690.00, 5650000.00, 'Active', '2022-04-01'),

    -- 5. Siddharth Verma (Delhi - Branch 4) - Personal Loan
    (5, 9, 19, 'Personal', 400000.00, 12.50, 36, 13380.00, 110000.00, 'Active', '2023-01-15'),

    -- 6. Rahul Singh (Delhi - Branch 3) - Car Loan (Closed)
    (6, 11, 15, 'Car', 650000.00, 9.50, 36, 20820.00, 0.00, 'Closed', '2021-02-10'),

    -- 7. Karthik Raman (Bangalore - Branch 5) - Home Loan
    (7, 13, 21, 'Home', 5200000.00, 8.35, 180, 50820.00, 4780000.00, 'Active', '2022-09-05'),

    -- 8. Divya Krishnan (Bangalore - Branch 5) - Education Loan
    (8, 14, 23, 'Education', 1200000.00, 7.50, 84, 18420.00, 890000.00, 'Active', '2022-07-20'),

    -- 9. Rajesh Nair (Bangalore - Branch 5) - Business Loan
    (9, 15, 25, 'Business', 1800000.00, 11.50, 48, 46940.00, 950000.00, 'Active', '2023-02-12'),

    -- 10. Aditya Kulkarni (Pune - Branch 6) - Car Loan
    (10, 19, 31, 'Car', 950000.00, 9.10, 60, 19760.00, 680000.00, 'Active', '2023-03-25'),

    -- 11. Suresh Patil (Pune - Branch 6) - Gold Loan (Closed)
    (11, 23, 37, 'Gold', 250000.00, 7.80, 12, 21730.00, 0.00, 'Closed', '2023-01-10'),

    -- 12. Venkat Rao (Hyderabad - Branch 7) - Home Loan
    (12, 25, 41, 'Home', 3800000.00, 8.60, 240, 33240.00, 3580000.00, 'Active', '2022-10-18'),

    -- 13. Harish Kumar (Chennai - Branch 8) - Personal Loan (DEFAULTED - High NPA risk)
    (13, 30, 49, 'Personal', 500000.00, 13.50, 48, 13550.00, 465000.00, 'Defaulted', '2023-04-10'),

    -- 14. Arnab Mukherjee (Kolkata - Branch 9) - Business Loan
    (14, 34, 59, 'Business', 3000000.00, 10.90, 60, 65090.00, 2450000.00, 'Active', '2023-05-15'),

    -- 15. Darshan Patel (Ahmedabad - Branch 10) - Home Loan
    (15, 37, 62, 'Home', 4000000.00, 8.55, 180, 39510.00, 3810000.00, 'Active', '2023-08-01');
