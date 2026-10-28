# Banking Transaction Analysis & Fraud Detection

[![SQL](https://img.shields.io/badge/SQL-MySQL%208.0-blue?logo=mysql)](https://dev.mysql.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

I built this project to practice real-world SQL — not just `SELECT * FROM`, but the kind of queries you'd actually run at a bank: account statements, fraud flags, monthly KPI reports, the works.

The idea was simple: model a small Indian bank from scratch (customers, branches, accounts, transactions, loans, cards), fill it with realistic-looking data, and then write every analytical query I could think of.

---

## What's in here

**6 core tables** — `customers`, `branches`, `accounts`, `transactions`, `loans`, `cards` — all properly normalized with foreign keys, check constraints, and indexes.

**705 sample records** covering 50 customers across 10 branches, 65 accounts, 525 transactions (Jan–Dec 2024), 15 loans, and 40 cards.

**193 analytical queries** organized into three buckets:

- **KPIs** — account balances, customer segmentation (RFM tiers), transaction trends (MoM growth, peak hours, channel split), branch performance, loan portfolio health, card usage
- **Fraud & AML** — high-value threshold flags, rapid-fire transaction detection (using LAG/LEAD), off-hours activity, structuring/smurfing patterns, dormant account reactivation, money laundering ring detection
- **Advanced SQL** — window functions showcase, recursive CTEs, pivot reporting, correlated subqueries

Plus **7 views**, **6 stored procedures** (account statements, interest calculation, monthly reports with proper error handling), and a **Docker Compose** setup that spins up MySQL and seeds everything automatically.

---

## Schema overview

```
customers ──┐
             ├── accounts ── transactions
branches ───┘      │
                   ├── loans
cards ─────────────┘
```

Each table has the constraints you'd expect — `UNIQUE` on email/account numbers, `CHECK` on amounts and rates, `ENUM` for status fields, and composite indexes on the columns that actually get queried (account + date range, transaction type, channel, etc).

---

## Getting started

### Docker (easiest)

```bash
git clone https://github.com/Sidd-1507/banking-sql-analysis.git
cd banking-sql-analysis

docker compose up -d

# connect
docker exec -it banking-mysql mysql -u root -pbanking123 banking_db
```

This pulls MySQL 8.0, creates the database, runs all schema/data/view/procedure scripts in order, and you're ready to query.

### Local MySQL

```bash
bash scripts/setup.sh
```

Or run the files manually in order — schema first, then data, then views, then procedures.

---

## Project structure

```
banking-sql-analysis/
├── schema/              # DDL — database, tables, indexes
├── data/                # DML — sample data inserts
├── queries/
│   ├── kpis/            # business KPI queries
│   ├── fraud/           # fraud detection & AML
│   └── advanced/        # window functions, CTEs, pivots
├── views/               # 7 reusable views
├── procedures/          # 6 stored procedures
├── docker/              # Docker Compose config
├── scripts/             # setup and runner scripts
└── docs/                # query catalog & performance notes
```

---

## Query highlights

Here are a few queries I found interesting to write:

**Customer segmentation (RFM)** — assigns each customer a Platinum/Gold/Silver/Bronze tier based on recency, frequency, and monetary value of their transactions. Uses `NTILE()` and a scoring CTE.

**Fraud: rapid succession detection** — uses `LAG()` to find transactions happening within 5 minutes of each other on the same account. Surprisingly common pattern banks actually watch for.

**Monthly KPI dashboard** — a single query (via the `v_monthly_kpi_dashboard` view) that returns total volume, deposits, withdrawals, net flow, active accounts, failure rate, and new accounts opened — one row per month. Built it as a view so it's always up to date.

**AML ring detection** — identifies accounts that receive large deposits and immediately transfer similar amounts out, a classic layering pattern. Uses self-joins and time-window analysis.

**Interest calculation procedure** — `sp_calculate_interest` loops through active savings accounts and credits quarterly interest. Handles the math, updates balances, and logs transactions — all inside a transaction block with rollback on error.

---

## SQL concepts covered

The project touches most of what you'd need for a data analyst or backend role:

- Joins (inner, left, self), subqueries, correlated subqueries
- Window functions — `ROW_NUMBER`, `RANK`, `LAG`, `LEAD`, `NTILE`, `SUM OVER`, `PERCENT_RANK`
- CTEs (including recursive ones for date series generation)
- `CASE WHEN`, `GROUP BY` + `HAVING`, `EXISTS` / `NOT EXISTS`
- Stored procedures with cursors, handlers, and transaction control
- Index design — composite, covering, full-text, and the reasoning behind each one

---

## Performance notes

I wrote up the indexing rationale in [`docs/PERFORMANCE_NOTES.md`](docs/PERFORMANCE_NOTES.md). The short version: the most-queried pattern is "all transactions for account X between date A and B", so there's a composite index on `(account_id, transaction_date, transaction_type)` that covers it. Fraud queries benefit from the `amount` and `channel` indexes. Everything else is documented in there.

---

## Connecting to BI tools

The database works out of the box with any tool that speaks MySQL:

- **Python** — `mysql-connector-python` + pandas + matplotlib/plotly
- **Metabase** — point it at `localhost:3306`, it auto-discovers tables and views
- **Grafana / Power BI / Tableau** — standard MySQL connector

---

## License

MIT — see [LICENSE](LICENSE).

---

Suggestions and PRs welcome. If you spot a bug in any query or have ideas for new fraud patterns, open an issue.
