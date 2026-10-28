# 📚 Query Catalog — Banking Transaction Analysis

## Quick Reference

| # | File | Category | Queries | Key Concepts |
|---|------|----------|---------|--------------|
| 1 | `kpis/01_account_balance_analysis.sql` | Balance | 6 | Running SUM, CASE WHEN, Window Functions |
| 2 | `kpis/02_customer_segmentation.sql` | Customers | 6 | RFM, NTILE, CTE, DATEDIFF |
| 3 | `kpis/03_transaction_trends.sql` | Trends | 8 | LAG, Moving Average, EXTRACT, MoM Growth |
| 4 | `kpis/04_branch_performance.sql` | Branch | 6 | GROUP BY, RANK, Multi-table JOIN |
| 5 | `kpis/05_loan_portfolio_analysis.sql` | Loans | 6 | Ratios, NPA, EMI Burden |
| 6 | `kpis/06_card_usage_analytics.sql` | Cards | 5 | Distribution, Utilization, Expiry |
| 7 | `fraud/01_fraud_detection.sql` | Fraud | 10 | LAG/LEAD, Time-window, Velocity |
| 8 | `fraud/02_aml_monitoring.sql` | AML | 5 | Structuring, Smurfing, Risk Scoring |
| 9 | `advanced/01_window_functions_showcase.sql` | Advanced | 8 | All 10 window functions |
| 10 | `advanced/02_cte_and_subqueries.sql` | Advanced | 7 | Recursive CTE, EXISTS, LATERAL |
| 11 | `advanced/03_pivot_and_reporting.sql` | Reporting | 5 | Pivot, YoY, Dashboard, Statement |

**Total: 72 queries across 11 files**

---

## Difficulty Levels

| Level | Queries | Best For |
|-------|---------|----------|
| 🟢 Beginner | Account balances, Card distribution, Branch customer count | Learning JOINs, GROUP BY |
| 🟡 Intermediate | Customer segmentation, Transaction trends, Loan analysis | CTEs, CASE WHEN, Date functions |
| 🔴 Advanced | Fraud detection, AML monitoring, Window function showcase | Window functions, Recursive CTEs, Subqueries |
| ⚫ Expert | Executive dashboard, Pivot tables, Stored procedures | Multi-CTE pipelines, Dynamic SQL |

---

## Interview-Ready Queries

These queries are commonly asked in SQL interviews at banks and fintech companies:

1. **Running Balance** → `kpis/01_account_balance_analysis.sql` (Query 4)
2. **RFM Analysis** → `kpis/02_customer_segmentation.sql` (Query 4)
3. **MoM Growth** → `kpis/03_transaction_trends.sql` (Query 7)
4. **Fraud: Rapid Succession** → `fraud/01_fraud_detection.sql` (Query 2)
5. **Window Functions** → `advanced/01_window_functions_showcase.sql` (All)
6. **Recursive CTE** → `advanced/02_cte_and_subqueries.sql` (Query 1)
7. **Pivot Table** → `advanced/03_pivot_and_reporting.sql` (Query 1)
