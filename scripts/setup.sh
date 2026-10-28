#!/bin/bash
# ============================================================================
# Banking Transaction Analysis — Full Setup Script
# ============================================================================
# Usage: bash scripts/setup.sh
# Prerequisites: MySQL 8.0+ installed and running locally
# ============================================================================

set -e

# Configuration
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_HOST="${MYSQL_HOST:-localhost}"
DB_NAME="banking_db"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "============================================"
echo "  🏦 Banking Transaction Analysis Setup"
echo "============================================"
echo ""

# Prompt for MySQL password
read -s -p "Enter MySQL password for user '$MYSQL_USER': " MYSQL_PASS
echo ""
echo ""

MYSQL_CMD="mysql -u $MYSQL_USER -p$MYSQL_PASS -h $MYSQL_HOST"

# Step 1: Create Database
echo "📂 Step 1/9: Creating database..."
$MYSQL_CMD < "$PROJECT_DIR/schema/01_create_database.sql"
echo "   ✅ Database created"

# Step 2: Create Tables
echo "📂 Step 2/9: Creating tables..."
$MYSQL_CMD $DB_NAME < "$PROJECT_DIR/schema/02_create_tables.sql"
echo "   ✅ Tables created (customers, branches, accounts, transactions, loans, cards)"

# Step 3: Create Indexes
echo "📂 Step 3/9: Creating indexes..."
$MYSQL_CMD $DB_NAME < "$PROJECT_DIR/schema/03_create_indexes.sql"
echo "   ✅ Performance indexes created"

# Step 4: Insert Branches
echo "📊 Step 4/9: Inserting branch data..."
$MYSQL_CMD $DB_NAME < "$PROJECT_DIR/data/01_insert_branches.sql"
echo "   ✅ 10 branches inserted"

# Step 5: Insert Customers
echo "📊 Step 5/9: Inserting customer data..."
$MYSQL_CMD $DB_NAME < "$PROJECT_DIR/data/02_insert_customers.sql"
echo "   ✅ 50 customers inserted"

# Step 6: Insert Accounts
echo "📊 Step 6/9: Inserting account data..."
$MYSQL_CMD $DB_NAME < "$PROJECT_DIR/data/03_insert_accounts.sql"
echo "   ✅ 65 accounts inserted"

# Step 7: Insert Transactions
echo "📊 Step 7/9: Inserting transaction data..."
$MYSQL_CMD $DB_NAME < "$PROJECT_DIR/data/04_insert_transactions.sql"
echo "   ✅ 500+ transactions inserted"

# Step 8: Insert Loans & Cards
echo "📊 Step 8/9: Inserting loans and cards data..."
$MYSQL_CMD $DB_NAME < "$PROJECT_DIR/data/05_insert_loans.sql"
$MYSQL_CMD $DB_NAME < "$PROJECT_DIR/data/06_insert_cards.sql"
echo "   ✅ 15 loans and 40 cards inserted"

# Step 9: Create Views & Procedures
echo "🔧 Step 9/9: Creating views and stored procedures..."
$MYSQL_CMD $DB_NAME < "$PROJECT_DIR/views/01_create_views.sql"
$MYSQL_CMD $DB_NAME < "$PROJECT_DIR/procedures/01_stored_procedures.sql"
echo "   ✅ 7 views and 6 stored procedures created"

echo ""
echo "============================================"
echo "  ✅ Setup Complete!"
echo "============================================"
echo ""
echo "  Database: $DB_NAME"
echo "  Tables:   6 (customers, branches, accounts, transactions, loans, cards)"
echo "  Records:  680+ rows of realistic sample data"
echo "  Views:    7 analytical views"
echo "  Procs:    6 stored procedures"
echo ""
echo "  Connect:  mysql -u $MYSQL_USER -p $DB_NAME"
echo ""
echo "  Run analytics: bash scripts/run_all_queries.sh"
echo "============================================"
