-- =============================================================================
-- File:        01_create_database.sql
-- Description: Creates the banking_db database with UTF-8 character set and
--              Unicode collation for full internationalization support.
-- Project:     Banking Transaction Analysis
-- Author:      SQL Developer
-- Date:        2026-10-28
-- Dialect:     MySQL 8.0+
-- =============================================================================

-- Drop the database if it already exists (use with caution in production)
DROP DATABASE IF EXISTS banking_db;

-- Create the database with UTF-8 multibyte support
CREATE DATABASE banking_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- Switch context to the newly created database
USE banking_db;

-- Enable standard SQL pipes for concatenation (ANSI standard compliance)
SET sql_mode = 'PIPES_AS_CONCAT,STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';
