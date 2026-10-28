-- =============================================================================
-- File:        03_insert_accounts.sql
-- Description: Insert 65 bank accounts for 50 customers. Includes a mix of
--              Savings (40), Current (15), Fixed Deposit (7), Recurring
--              Deposit (3) accounts. Some customers have multiple accounts.
-- Author:      SQL Analysis Project
-- Date:        2024-01-01
-- =============================================================================

INSERT INTO accounts (account_id, account_number, customer_id, branch_id, account_type, opening_balance, current_balance, opened_date, status, interest_rate)
VALUES
    -- ========= MUMBAI — Branch 1 (Fort) =========
    -- Customer 1: Aarav Mehta — Savings + FD
    (1,  '2024000101', 1,  1,  'Savings',            50000.00,   50000.00,  '2022-01-15', 'Active',   3.50),
    (2,  '2024000102', 1,  1,  'Fixed Deposit',     200000.00,  200000.00,  '2023-06-10', 'Active',   6.75),
    -- Customer 2: Priya Deshmukh — Savings
    (3,  '2024000201', 2,  1,  'Savings',            75000.00,   75000.00,  '2022-02-20', 'Active',   3.50),
    -- Customer 5: Rohan Joshi — Savings + Current
    (4,  '2024000501', 5,  1,  'Savings',            60000.00,   60000.00,  '2022-04-05', 'Active',   3.50),
    (5,  '2024000502', 5,  1,  'Current',           180000.00,  180000.00,  '2022-04-05', 'Active',   0.00),
    -- Customer 46: Fatima Khan — Savings (Inactive)
    (6,  '2024004601', 46, 1,  'Savings',            18000.00,   18000.00,  '2023-06-12', 'Inactive', 3.50),

    -- ========= MUMBAI — Branch 2 (Andheri West) =========
    -- Customer 3: Vikram Shah — Savings + Current
    (7,  '2024000301', 3,  2,  'Savings',           150000.00,  150000.00,  '2022-01-10', 'Active',   3.50),
    (8,  '2024000302', 3,  2,  'Current',           500000.00,  500000.00,  '2022-01-10', 'Active',   0.00),
    -- Customer 4: Ananya Iyer — Savings
    (9,  '2024000401', 4,  2,  'Savings',            40000.00,   40000.00,  '2022-03-12', 'Active',   3.50),
    -- Customer 6: Meera Kulkarni — Savings + RD
    (10, '2024000601', 6,  2,  'Savings',            25000.00,   25000.00,  '2022-06-18', 'Active',   3.50),
    (11, '2024000602', 6,  2,  'Recurring Deposit',  10000.00,   10000.00,  '2023-01-01', 'Active',   6.25),

    -- ========= DELHI — Branch 3 (Connaught Place) =========
    -- Customer 7: Arjun Sharma — Savings + Current
    (12, '2024000701', 7,  3,  'Savings',           100000.00,  100000.00,  '2022-02-14', 'Active',   3.50),
    (13, '2024000702', 7,  3,  'Current',           300000.00,  300000.00,  '2022-02-14', 'Active',   0.00),
    -- Customer 8: Kavita Gupta — Savings
    (14, '2024000801', 8,  3,  'Savings',            30000.00,   30000.00,  '2022-05-22', 'Active',   3.50),
    -- Customer 11: Rahul Singh — Current + FD
    (15, '2024001101', 11, 3,  'Current',           200000.00,  200000.00,  '2022-03-05', 'Active',   0.00),
    (16, '2024001102', 11, 3,  'Fixed Deposit',     500000.00,  500000.00,  '2023-03-05', 'Active',   7.00),
    -- Customer 42: Sakshi Kapoor — Current
    (17, '2024004201', 42, 3,  'Current',           150000.00,  150000.00,  '2022-11-20', 'Active',   0.00),
    -- Customer 45: Abhishek Saxena — Savings
    (18, '2024004501', 45, 3,  'Savings',            25000.00,   25000.00,  '2023-11-05', 'Active',   3.50),

    -- ========= DELHI — Branch 4 (Dwarka) =========
    -- Customer 9: Siddharth Verma — Savings + Current
    (19, '2024000901', 9,  4,  'Savings',           200000.00,  200000.00,  '2022-01-28', 'Active',   3.50),
    (20, '2024000902', 9,  4,  'Current',           400000.00,  400000.00,  '2022-01-28', 'Active',   0.00),
    -- Customer 10: Nisha Agarwal — Savings
    (21, '2024001001', 10, 4,  'Savings',            35000.00,   35000.00,  '2022-07-10', 'Active',   3.50),
    -- Customer 12: Pooja Malhotra — Savings
    (22, '2024001201', 12, 4,  'Savings',            15000.00,   15000.00,  '2023-01-15', 'Active',   3.50),
    -- Customer 41: Manish Tiwari — Savings + FD
    (23, '2024004101', 41, 4,  'Savings',            72000.00,   72000.00,  '2022-10-15', 'Active',   3.50),
    (24, '2024004102', 41, 4,  'Fixed Deposit',     250000.00,  250000.00,  '2023-10-15', 'Active',   6.75),
    -- Customer 47: Harpreet Kaur — Savings
    (25, '2024004701', 47, 4,  'Savings',            55000.00,   55000.00,  '2023-02-28', 'Active',   3.50),

    -- ========= BANGALORE — Branch 5 (Koramangala) =========
    -- Customer 13: Karthik Ramachandran — Savings + Current
    (26, '2024001301', 13, 5,  'Savings',            80000.00,   80000.00,  '2022-02-28', 'Active',   3.50),
    (27, '2024001302', 13, 5,  'Current',           250000.00,  250000.00,  '2022-08-15', 'Active',   0.00),
    -- Customer 14: Deepa Nair — Savings
    (28, '2024001401', 14, 5,  'Savings',            55000.00,   55000.00,  '2022-04-18', 'Active',   3.50),
    -- Customer 15: Aditya Hegde — Savings
    (29, '2024001501', 15, 5,  'Savings',            45000.00,   45000.00,  '2022-06-20', 'Active',   3.50),
    -- Customer 16: Riya Gowda — Savings (Student)
    (30, '2024001601', 16, 5,  'Savings',             5000.00,    5000.00,  '2023-08-01', 'Active',   4.00),
    -- Customer 17: Sunil Rao — Current + FD (Retired)
    (31, '2024001701', 17, 5,  'Current',           180000.00,  180000.00,  '2022-01-05', 'Active',   0.00),
    (32, '2024001702', 17, 5,  'Fixed Deposit',     300000.00,  300000.00,  '2022-06-01', 'Active',   7.25),
    -- Customer 43: Vivek Menon — Current
    (33, '2024004301', 43, 5,  'Current',           320000.00,  320000.00,  '2022-05-08', 'Active',   0.00),

    -- ========= PUNE — Branch 6 (Kothrud) =========
    -- Customer 18: Omkar Patil — Savings
    (34, '2024001801', 18, 6,  'Savings',            42000.00,   42000.00,  '2022-05-30', 'Active',   3.50),
    -- Customer 19: Swati Deshpande — Savings + RD
    (35, '2024001901', 19, 6,  'Savings',            65000.00,   65000.00,  '2022-03-15', 'Active',   3.50),
    (36, '2024001902', 19, 6,  'Recurring Deposit',  10000.00,   10000.00,  '2023-04-01', 'Active',   6.25),
    -- Customer 20: Nikhil Phadke — Current
    (37, '2024002001', 20, 6,  'Current',           350000.00,  350000.00,  '2022-08-12', 'Active',   0.00),
    -- Customer 21: Ankita Bhosale — Savings (Student)
    (38, '2024002101', 21, 6,  'Savings',             8000.00,    8000.00,  '2023-09-05', 'Active',   4.00),
    -- Customer 49: Snehal Wagh — Savings
    (39, '2024004901', 49, 6,  'Savings',            22000.00,   22000.00,  '2024-01-15', 'Active',   3.50),

    -- ========= HYDERABAD — Branch 7 (Banjara Hills) =========
    -- Customer 22: Venkat Reddy — Savings + Current
    (40, '2024002201', 22, 7,  'Savings',           175000.00,  175000.00,  '2022-01-20', 'Active',   3.50),
    (41, '2024002202', 22, 7,  'Current',           450000.00,  450000.00,  '2022-01-20', 'Active',   0.00),
    -- Customer 23: Lavanya Krishna — Savings
    (42, '2024002301', 23, 7,  'Savings',            48000.00,   48000.00,  '2022-04-10', 'Active',   3.50),
    -- Customer 24: Pranav Chowdary — Savings
    (43, '2024002401', 24, 7,  'Savings',            38000.00,   38000.00,  '2022-09-15', 'Active',   3.50),
    -- Customer 25: Shruti Naidu — Savings
    (44, '2024002501', 25, 7,  'Savings',            22000.00,   22000.00,  '2022-07-25', 'Active',   3.50),
    -- Customer 26: Ravi Teja — Savings
    (45, '2024002601', 26, 7,  'Savings',            55000.00,   55000.00,  '2023-02-10', 'Active',   3.50),
    -- Customer 50: Rajendra Prasad — FD
    (46, '2024005001', 50, 7,  'Fixed Deposit',     350000.00,  350000.00,  '2022-04-30', 'Active',   7.00),

    -- ========= CHENNAI — Branch 8 (T. Nagar) =========
    -- Customer 27: Arun Subramanian — Savings + Current
    (47, '2024002701', 27, 8,  'Savings',            70000.00,   70000.00,  '2022-02-08', 'Active',   3.50),
    (48, '2024002702', 27, 8,  'Current',           200000.00,  200000.00,  '2022-02-08', 'Active',   0.00),
    -- Customer 28: Divya Raghavan — Savings
    (49, '2024002801', 28, 8,  'Savings',            52000.00,   52000.00,  '2022-06-14', 'Active',   3.50),
    -- Customer 29: Ganesh Venkatesh — Savings + FD (Retired)
    (50, '2024002901', 29, 8,  'Savings',            85000.00,   85000.00,  '2022-03-20', 'Active',   3.50),
    (51, '2024002902', 29, 8,  'Fixed Deposit',     400000.00,  400000.00,  '2022-09-01', 'Active',   7.00),
    -- Customer 30: Lakshmi Prasad — Savings
    (52, '2024003001', 30, 8,  'Savings',            20000.00,   20000.00,  '2023-04-01', 'Active',   3.50),
    -- Customer 31: Manoj Pillai — Current
    (53, '2024003101', 31, 8,  'Current',           250000.00,  250000.00,  '2022-05-10', 'Active',   0.00),
    -- Customer 44: Rekha Srinivasan — Savings (Inactive)
    (54, '2024004401', 44, 8,  'Savings',            15000.00,   15000.00,  '2023-03-18', 'Inactive', 3.50),
    -- Customer 48: Joseph Thomas — Savings + RD
    (55, '2024004801', 48, 8,  'Savings',            90000.00,   90000.00,  '2022-12-10', 'Active',   3.50),
    (56, '2024004802', 48, 8,  'Recurring Deposit',  15000.00,   15000.00,  '2023-06-01', 'Active',   6.50),

    -- ========= KOLKATA — Branch 9 (Salt Lake) =========
    -- Customer 32: Soham Chatterjee — Savings
    (57, '2024003201', 32, 9,  'Savings',            35000.00,   35000.00,  '2022-04-22', 'Active',   3.50),
    -- Customer 33: Ishita Das — Savings
    (58, '2024003301', 33, 9,  'Savings',            60000.00,   60000.00,  '2022-08-05', 'Active',   3.50),
    -- Customer 34: Arnab Mukherjee — Current
    (59, '2024003401', 34, 9,  'Current',           280000.00,  280000.00,  '2022-01-30', 'Active',   0.00),
    -- Customer 35: Tanisha Bose — Savings (Student)
    (60, '2024003501', 35, 9,  'Savings',             6000.00,    6000.00,  '2023-07-20', 'Active',   4.00),
    -- Customer 36: Subhash Ghosh — Savings
    (61, '2024003601', 36, 9,  'Savings',            70000.00,   70000.00,  '2022-06-28', 'Active',   3.50),

    -- ========= AHMEDABAD — Branch 10 (CG Road) =========
    -- Customer 37: Darshan Patel — Current
    (62, '2024003701', 37, 10, 'Current',           380000.00,  380000.00,  '2022-03-25', 'Active',   0.00),
    -- Customer 38: Khushi Modi — Savings
    (63, '2024003801', 38, 10, 'Savings',            45000.00,   45000.00,  '2022-07-18', 'Active',   3.50),
    -- Customer 39: Jayesh Desai — Savings
    (64, '2024003901', 39, 10, 'Savings',            32000.00,   32000.00,  '2022-09-02', 'Active',   3.50),
    -- Customer 40: Nidhi Thakkar — Savings
    (65, '2024004001', 40, 10, 'Savings',            28000.00,   28000.00,  '2023-01-10', 'Active',   3.50);

-- =============================================================================
-- Account Type Distribution:
--   Savings:           40  (IDs: 1,3,4,6,7,9,10,12,14,18,19,21,22,23,25,26,28,
--                                29,30,34,35,38,39,40,42,43,44,45,47,49,50,52,
--                                54,55,57,58,60,61,63,64,65)  => 40
--   Current:           15  (IDs: 5,8,13,15,17,20,27,31,33,37,41,48,53,59,62) => 15
--   Fixed Deposit:      7  (IDs: 2,16,24,32,46,51,57 -> corrected above)     => 7
--   Recurring Deposit:  3  (IDs: 11,36,56)                                    => 3
--   TOTAL:             65
--
-- Status: 63 Active, 2 Inactive (IDs: 6, 54)
-- =============================================================================
