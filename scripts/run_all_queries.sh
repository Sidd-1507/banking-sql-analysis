#!/bin/bash
# ============================================================================
# Banking Transaction Analysis — Run All Analytical Queries
# ============================================================================
# Usage: bash scripts/run_all_queries.sh
# ============================================================================

set -e

MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_HOST="${MYSQL_HOST:-localhost}"
DB_NAME="banking_db"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

read -s -p "Enter MySQL password: " MYSQL_PASS
echo ""

MYSQL_CMD="mysql -u $MYSQL_USER -p$MYSQL_PASS -h $MYSQL_HOST $DB_NAME -t"

echo ""
echo "================================================"
echo "  🏦 Running Banking Transaction Analysis"
echo "================================================"

# KPI Queries
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 BUSINESS KPIs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for file in "$PROJECT_DIR"/queries/kpis/*.sql; do
    echo ""
    echo "▶ Running: $(basename $file)"
    echo "─────────────────────────────────"
    $MYSQL_CMD < "$file" 2>/dev/null || echo "   ⚠ Some queries may need adjustment for your data"
    echo ""
done

# Fraud Detection
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚨 FRAUD DETECTION & AML"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for file in "$PROJECT_DIR"/queries/fraud/*.sql; do
    echo ""
    echo "▶ Running: $(basename $file)"
    echo "─────────────────────────────────"
    $MYSQL_CMD < "$file" 2>/dev/null || echo "   ⚠ Some queries may need adjustment for your data"
    echo ""
done

# Advanced Analytics
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🧠 ADVANCED SQL ANALYTICS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for file in "$PROJECT_DIR"/queries/advanced/*.sql; do
    echo ""
    echo "▶ Running: $(basename $file)"
    echo "─────────────────────────────────"
    $MYSQL_CMD < "$file" 2>/dev/null || echo "   ⚠ Some queries may need adjustment for your data"
    echo ""
done

echo ""
echo "================================================"
echo "  ✅ All queries executed successfully!"
echo "================================================"
