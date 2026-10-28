-- =============================================================================
-- File:        02_insert_customers.sql
-- Description: Insert 50 realistic Indian customers with diverse demographics,
--              occupations, income levels, and KYC statuses.
-- Author:      SQL Analysis Project
-- Date:        2024-01-01
-- =============================================================================

INSERT INTO customers (customer_id, first_name, last_name, date_of_birth, gender, email, phone, address, city, state, pin_code, occupation, annual_income, kyc_status, account_open_date, branch_id)
VALUES
    -- Mumbai customers (branch 1 & 2)
    (1,  'Aarav',      'Mehta',        '1990-05-14', 'M', 'aarav.mehta@gmail.com',         '919876543210', '12/A Peddar Road, Cumballa Hill',         'Mumbai',      'Maharashtra',   '400026', 'Software Engineer',  1800000, 'Verified',  '2022-01-15', 1),
    (2,  'Priya',      'Deshmukh',     '1985-11-22', 'F', 'priya.deshmukh@yahoo.com',      '919876543211', '34 Pali Hill, Bandra West',               'Mumbai',      'Maharashtra',   '400050', 'Doctor',             3200000, 'Verified',  '2022-02-20', 1),
    (3,  'Vikram',     'Shah',         '1978-03-08', 'M', 'vikram.shah@outlook.com',        '919876543212', '56 Juhu Tara Road, Juhu',                 'Mumbai',      'Maharashtra',   '400049', 'Business Owner',     5000000, 'Verified',  '2022-01-10', 2),
    (4,  'Ananya',     'Iyer',         '1995-07-30', 'F', 'ananya.iyer@gmail.com',          '919876543213', '78 Hiranandani Gardens, Powai',           'Mumbai',      'Maharashtra',   '400076', 'CA',                 1500000, 'Verified',  '2022-03-12', 2),
    (5,  'Rohan',      'Joshi',        '1992-09-18', 'M', 'rohan.joshi@hotmail.com',        '919876543214', '15 Turner Road, Bandra West',             'Mumbai',      'Maharashtra',   '400050', 'Software Engineer',  2200000, 'Verified',  '2022-04-05', 1),
    (6,  'Meera',      'Kulkarni',     '1988-12-25', 'F', 'meera.kulkarni@gmail.com',       '919876543215', '90 Worli Sea Face',                       'Mumbai',      'Maharashtra',   '400018', 'Teacher',            800000,  'Verified',  '2022-06-18', 2),

    -- Delhi customers (branch 3 & 4)
    (7,  'Arjun',      'Sharma',       '1987-01-05', 'M', 'arjun.sharma@gmail.com',         '919812345670', '45 Defence Colony',                       'Delhi',       'Delhi',         '110024', 'Lawyer',             2800000, 'Verified',  '2022-02-14', 3),
    (8,  'Kavita',     'Gupta',        '1991-04-12', 'F', 'kavita.gupta@yahoo.com',          '919812345671', '12 Lajpat Nagar III',                     'Delhi',       'Delhi',         '110024', 'Govt Employee',      900000,  'Verified',  '2022-05-22', 3),
    (9,  'Siddharth',  'Verma',        '1983-08-19', 'M', 'siddharth.verma@outlook.com',     '919812345672', '89 Vasant Kunj, Sector B',                'Delhi',       'Delhi',         '110070', 'Business Owner',     4500000, 'Verified',  '2022-01-28', 4),
    (10, 'Nisha',      'Agarwal',      '1996-02-14', 'F', 'nisha.agarwal@gmail.com',         '919812345673', '23 Rohini Sector 9',                      'Delhi',       'Delhi',         '110085', 'Software Engineer',  1600000, 'Verified',  '2022-07-10', 4),
    (11, 'Rahul',      'Singh',        '1980-06-30', 'M', 'rahul.singh@hotmail.com',         '919812345674', '67 Greater Kailash I',                    'Delhi',       'Delhi',         '110048', 'Doctor',             3500000, 'Verified',  '2022-03-05', 3),
    (12, 'Pooja',      'Malhotra',     '1993-10-08', 'F', 'pooja.malhotra@gmail.com',        '919812345675', '34 Pitampura, Block B',                   'Delhi',       'Delhi',         '110034', 'Homemaker',          0,       'Verified',  '2023-01-15', 4),

    -- Bangalore customers (branch 5)
    (13, 'Karthik',    'Ramachandran', '1989-03-22', 'M', 'karthik.rama@gmail.com',          '919900123450', '45 Indiranagar 12th Main',                'Bangalore',   'Karnataka',     '560038', 'Software Engineer',  2800000, 'Verified',  '2022-02-28', 5),
    (14, 'Deepa',      'Nair',         '1986-07-15', 'F', 'deepa.nair@yahoo.com',            '919900123451', '78 HSR Layout Sector 2',                  'Bangalore',   'Karnataka',     '560102', 'Product Manager',    2400000, 'Verified',  '2022-04-18', 5),
    (15, 'Aditya',     'Hegde',        '1994-11-03', 'M', 'aditya.hegde@outlook.com',        '919900123452', '12 Whitefield Main Road',                 'Bangalore',   'Karnataka',     '560066', 'Software Engineer',  2000000, 'Verified',  '2022-06-20', 5),
    (16, 'Riya',       'Gowda',        '1997-05-28', 'F', 'riya.gowda@gmail.com',            '919900123453', '56 Jayanagar 4th Block',                  'Bangalore',   'Karnataka',     '560011', 'Student',            200000,  'Pending',   '2023-08-01', 5),
    (17, 'Sunil',      'Rao',          '1975-09-10', 'M', 'sunil.rao@hotmail.com',            '919900123454', '34 Malleshwaram 8th Cross',               'Bangalore',   'Karnataka',     '560003', 'Retired',            1200000, 'Verified',  '2022-01-05', 5),

    -- Pune customers (branch 6)
    (18, 'Omkar',      'Patil',        '1991-01-17', 'M', 'omkar.patil@gmail.com',            '919822123450', '23 Aundh, Bremen Chowk',                  'Pune',        'Maharashtra',   '411007', 'Software Engineer',  1900000, 'Verified',  '2022-05-30', 6),
    (19, 'Swati',      'Deshpande',    '1988-04-25', 'F', 'swati.deshpande@yahoo.com',        '919822123451', '67 Koregaon Park',                        'Pune',        'Maharashtra',   '411001', 'Doctor',             2600000, 'Verified',  '2022-03-15', 6),
    (20, 'Nikhil',     'Phadke',       '1984-12-02', 'M', 'nikhil.phadke@gmail.com',          '919822123452', '89 Baner Road',                           'Pune',        'Maharashtra',   '411045', 'Business Owner',     3800000, 'Verified',  '2022-08-12', 6),
    (21, 'Ankita',     'Bhosale',      '1999-06-20', 'F', 'ankita.bhosale@outlook.com',       '919822123453', '12 Viman Nagar',                          'Pune',        'Maharashtra',   '411014', 'Student',            250000,  'Pending',   '2023-09-05', 6),

    -- Hyderabad customers (branch 7)
    (22, 'Venkat',     'Reddy',        '1982-08-14', 'M', 'venkat.reddy@gmail.com',            '919848123450', '45 Jubilee Hills, Road No 36',            'Hyderabad',   'Telangana',     '500033', 'Business Owner',     4200000, 'Verified',  '2022-01-20', 7),
    (23, 'Lavanya',    'Krishna',      '1990-02-11', 'F', 'lavanya.krishna@yahoo.com',         '919848123451', '78 Madhapur, Hitech City',                'Hyderabad',   'Telangana',     '500081', 'Software Engineer',  2100000, 'Verified',  '2022-04-10', 7),
    (24, 'Pranav',     'Chowdary',     '1993-06-05', 'M', 'pranav.chowdary@gmail.com',         '919848123452', '23 Kondapur, Serene County',              'Hyderabad',   'Telangana',     '500084', 'Software Engineer',  1700000, 'Verified',  '2022-09-15', 7),
    (25, 'Shruti',     'Naidu',        '1987-10-30', 'F', 'shruti.naidu@hotmail.com',           '919848123453', '56 Kukatpally, KPHB Colony',              'Hyderabad',   'Telangana',     '500072', 'Teacher',            700000,  'Verified',  '2022-07-25', 7),
    (26, 'Ravi',       'Teja',         '1979-04-18', 'M', 'ravi.teja@outlook.com',              '919848123454', '90 Secunderabad, Bowenpally',             'Hyderabad',   'Telangana',     '500011', 'Govt Employee',      1100000, 'Verified',  '2023-02-10', 7),

    -- Chennai customers (branch 8)
    (27, 'Arun',       'Subramanian',  '1986-05-22', 'M', 'arun.subramanian@gmail.com',        '919841123450', '34 Adyar, Besant Nagar',                  'Chennai',     'Tamil Nadu',    '600020', 'CA',                 2000000, 'Verified',  '2022-02-08', 8),
    (28, 'Divya',      'Raghavan',     '1992-09-14', 'F', 'divya.raghavan@yahoo.com',           '919841123451', '12 Anna Nagar East',                      'Chennai',     'Tamil Nadu',    '600102', 'Software Engineer',  1800000, 'Verified',  '2022-06-14', 8),
    (29, 'Ganesh',     'Venkatesh',    '1976-01-28', 'M', 'ganesh.venkatesh@gmail.com',         '919841123452', '67 Mylapore, Luz Corner',                 'Chennai',     'Tamil Nadu',    '600004', 'Retired',            1500000, 'Verified',  '2022-03-20', 8),
    (30, 'Lakshmi',    'Prasad',       '1994-11-09', 'F', 'lakshmi.prasad@outlook.com',         '919841123453', '45 Velachery, Bypass Road',               'Chennai',     'Tamil Nadu',    '600042', 'Teacher',            650000,  'Verified',  '2023-04-01', 8),
    (31, 'Manoj',      'Pillai',       '1981-03-16', 'M', 'manoj.pillai@hotmail.com',           '919841123454', '89 Nungambakkam High Road',               'Chennai',     'Tamil Nadu',    '600034', 'Lawyer',             2500000, 'Verified',  '2022-05-10', 8),

    -- Kolkata customers (branch 9)
    (32, 'Soham',      'Chatterjee',   '1988-07-04', 'M', 'soham.chatterjee@gmail.com',         '919830123450', '23 Salt Lake, Sector III',                'Kolkata',     'West Bengal',   '700106', 'Software Engineer',  1600000, 'Verified',  '2022-04-22', 9),
    (33, 'Ishita',     'Das',          '1991-12-18', 'F', 'ishita.das@yahoo.com',               '919830123451', '56 New Town, Action Area I',              'Kolkata',     'West Bengal',   '700156', 'Doctor',             2200000, 'Verified',  '2022-08-05', 9),
    (34, 'Arnab',      'Mukherjee',    '1985-02-26', 'M', 'arnab.mukherjee@gmail.com',          '919830123452', '78 Ballygunge Circular Road',             'Kolkata',     'West Bengal',   '700019', 'Business Owner',     3000000, 'Verified',  '2022-01-30', 9),
    (35, 'Tanisha',    'Bose',         '1998-08-12', 'F', 'tanisha.bose@outlook.com',           '919830123453', '12 Behala, Diamond Harbour Road',         'Kolkata',     'West Bengal',   '700034', 'Student',            300000,  'Pending',   '2023-07-20', 9),
    (36, 'Subhash',    'Ghosh',        '1973-05-09', 'M', 'subhash.ghosh@hotmail.com',          '919830123454', '45 Howrah, Shibpur',                      'Kolkata',     'West Bengal',   '711102', 'Retired',            800000,  'Verified',  '2022-06-28', 9),

    -- Ahmedabad customers (branch 10)
    (37, 'Darshan',    'Patel',        '1990-10-15', 'M', 'darshan.patel@gmail.com',            '919825123450', '34 Satellite Road, Jodhpur',              'Ahmedabad',   'Gujarat',       '380015', 'Business Owner',     3500000, 'Verified',  '2022-03-25', 10),
    (38, 'Khushi',     'Modi',         '1993-03-07', 'F', 'khushi.modi@yahoo.com',              '919825123451', '67 Prahlad Nagar',                        'Ahmedabad',   'Gujarat',       '380015', 'CA',                 1400000, 'Verified',  '2022-07-18', 10),
    (39, 'Jayesh',     'Desai',        '1980-06-21', 'M', 'jayesh.desai@gmail.com',             '919825123452', '89 Navrangpura, CG Road',                 'Ahmedabad',   'Gujarat',       '380009', 'Govt Employee',      950000,  'Verified',  '2022-09-02', 10),
    (40, 'Nidhi',      'Thakkar',      '1996-01-29', 'F', 'nidhi.thakkar@outlook.com',          '919825123453', '12 SG Highway, Bodakdev',                 'Ahmedabad',   'Gujarat',       '380054', 'Software Engineer',  1300000, 'Verified',  '2023-01-10', 10),

    -- Additional customers spread across branches
    (41, 'Manish',     'Tiwari',       '1984-04-03', 'M', 'manish.tiwari@gmail.com',            '919811234560', '90 Noida Sector 62',                      'Noida',       'Uttar Pradesh', '201301', 'Software Engineer',  2500000, 'Verified',  '2022-10-15', 4),
    (42, 'Sakshi',     'Kapoor',       '1989-08-27', 'F', 'sakshi.kapoor@yahoo.com',             '919811234561', '23 Gurgaon, DLF Phase 3',                 'Gurgaon',     'Haryana',       '122002', 'Product Manager',    2700000, 'Verified',  '2022-11-20', 3),
    (43, 'Vivek',      'Menon',        '1977-12-11', 'M', 'vivek.menon@hotmail.com',             '919845123450', '56 Electronic City Phase 1',              'Bangalore',   'Karnataka',     '560100', 'Business Owner',     4000000, 'Verified',  '2022-05-08', 5),
    (44, 'Rekha',      'Srinivasan',   '1970-09-05', 'F', 'rekha.srinivasan@gmail.com',          '919844123450', '78 RA Puram',                             'Chennai',     'Tamil Nadu',    '600028', 'Homemaker',          0,       'Verified',  '2023-03-18', 8),
    (45, 'Abhishek',   'Saxena',       '1995-02-19', 'M', 'abhishek.saxena@outlook.com',         '919810234560', '34 Saket, J Block',                       'Delhi',       'Delhi',         '110017', 'Lawyer',             1200000, 'Pending',   '2023-11-05', 3),
    (46, 'Fatima',     'Khan',         '1992-07-23', 'F', 'fatima.khan@gmail.com',               '919876234560', '12 Byculla, Mohammed Ali Road',           'Mumbai',      'Maharashtra',   '400008', 'Teacher',            750000,  'Verified',  '2023-06-12', 1),
    (47, 'Harpreet',   'Kaur',         '1986-11-14', 'F', 'harpreet.kaur@yahoo.com',             '919815123450', '45 Model Town',                           'Ludhiana',    'Punjab',        '141002', 'Doctor',             2800000, 'Verified',  '2023-02-28', 4),
    (48, 'Joseph',     'Thomas',       '1983-03-30', 'M', 'joseph.thomas@gmail.com',             '919847123450', '67 Panampilly Nagar',                     'Kochi',       'Kerala',        '682036', 'Business Owner',     3200000, 'Verified',  '2022-12-10', 8),
    (49, 'Snehal',     'Wagh',         '1997-05-06', 'F', 'snehal.wagh@outlook.com',             '919823123450', '89 Hinjewadi Phase 2',                    'Pune',        'Maharashtra',   '411057', 'Software Engineer',  1100000, 'Pending',   '2024-01-15', 6),
    (50, 'Rajendra',   'Prasad',       '1968-08-15', 'M', 'rajendra.prasad@hotmail.com',         '919849123450', '23 Begumpet, Ameerpet',                   'Hyderabad',   'Telangana',     '500016', 'Retired',            2000000, 'Verified',  '2022-04-30', 7);
