-- =============================================================================
-- File:        01_insert_branches.sql
-- Description: Insert sample Indian bank branches for Banking Transaction
--              Analysis project. 10 branches across major metro cities.
-- Author:      SQL Analysis Project
-- Date:        2024-01-01
-- =============================================================================

INSERT INTO branches (branch_id, branch_name, branch_code, ifsc_code, city, state, address, phone, manager_name, opened_date, is_active)
VALUES
    (1,  'Fort Branch',              'FORT01',   'BKNG0001001', 'Mumbai',     'Maharashtra',  '23 D.N. Road, Fort, Mumbai 400001',                    '912222654321', 'Rajesh Kulkarni',    '2018-03-15', TRUE),
    (2,  'Andheri West Branch',      'ANDW02',   'BKNG0001002', 'Mumbai',     'Maharashtra',  '114 Linking Road, Andheri West, Mumbai 400058',         '912226543210', 'Sneha Patil',        '2019-07-22', TRUE),
    (3,  'Connaught Place Branch',   'CP03',     'BKNG0001003', 'Delhi',      'Delhi',        'Block F, Connaught Place, New Delhi 110001',            '911123456789', 'Arun Sharma',        '2017-01-10', TRUE),
    (4,  'Dwarka Branch',            'DWK04',    'BKNG0001004', 'Delhi',      'Delhi',        'Sector 6, Dwarka, New Delhi 110075',                    '911125678901', 'Neha Gupta',         '2020-05-18', TRUE),
    (5,  'Koramangala Branch',       'KOR05',    'BKNG0001005', 'Bangalore',  'Karnataka',    '80 Feet Road, Koramangala, Bangalore 560034',           '918041234567', 'Suresh Reddy',       '2019-11-30', TRUE),
    (6,  'Kothrud Branch',           'KOT06',    'BKNG0001006', 'Pune',       'Maharashtra',  'Karve Road, Kothrud, Pune 411038',                      '912025678901', 'Amit Joshi',         '2020-02-14', TRUE),
    (7,  'Banjara Hills Branch',     'BH07',     'BKNG0001007', 'Hyderabad',  'Telangana',    'Road No. 12, Banjara Hills, Hyderabad 500034',          '914023456789', 'Lakshmi Rao',        '2018-08-25', TRUE),
    (8,  'T. Nagar Branch',          'TN08',     'BKNG0001008', 'Chennai',    'Tamil Nadu',   '15 Usman Road, T. Nagar, Chennai 600017',               '914428901234', 'Karthik Sundaram',   '2017-06-05', TRUE),
    (9,  'Salt Lake Branch',         'SL09',     'BKNG0001009', 'Kolkata',    'West Bengal',  'Block AE, Sector 1, Salt Lake City, Kolkata 700064',    '913323456789', 'Debashish Banerjee', '2019-04-12', TRUE),
    (10, 'CG Road Branch',           'CG10',     'BKNG0001010', 'Ahmedabad',  'Gujarat',      'CG Road, Navrangpura, Ahmedabad 380009',                '917926543210', 'Hiren Patel',        '2021-01-20', TRUE);
