# ⚡ Performance & Indexing Notes

## Index Strategy Rationale

### Primary Indexes (in `schema/03_create_indexes.sql`)

| Index | Columns | Justification |
|-------|---------|---------------|
| `idx_txn_account_date_type` | `(account_id, transaction_date, transaction_type)` | **Covering index** for the most common query pattern: "get all transactions for account X between date A and B of type Y". Avoids table lookups for statement generation and balance calculation. |
| `idx_txn_amount` | `(amount)` | Enables fast **range scans** for fraud detection (WHERE amount > 100000). B-tree index supports both equality and range predicates. |
| `idx_txn_channel` | `(channel)` | Channel-wise analytics (GROUP BY channel) benefit from an index scan instead of full table scan on 500+ rows. |
| `idx_loan_cust_status` | `(customer_id, status)` | Composite index for "find all active loans for customer X" — the most common loan lookup pattern. |
| `idx_card_customer` | `(customer_id)` | Supports JOIN between cards and customers in card analytics queries. |
| `idx_txn_desc_fulltext` | `FULLTEXT(description)` | Natural-language search on transaction descriptions ("salary", "UPI transfer"). MySQL-specific. |

### Why These Indexes Matter

```
WITHOUT idx_txn_account_date_type:
  → Full table scan on 500 rows for every account statement
  → O(n) per query × 65 accounts = 32,500 row reads

WITH idx_txn_account_date_type:
  → Index range scan: ~8 rows per account (500/65 avg)
  → O(log n + k) where k = matching rows
  → 95% fewer disk reads
```

### Query Performance Tips

1. **Use EXPLAIN ANALYZE** before every production query:
   ```sql
   EXPLAIN ANALYZE
   SELECT ... FROM transactions WHERE account_id = 101 AND transaction_date > '2024-06-01';
   ```

2. **Avoid SELECT \*** — list only needed columns so MySQL can use covering indexes

3. **Partition large tables** by date if transactions grow beyond 1M rows:
   ```sql
   ALTER TABLE transactions PARTITION BY RANGE (YEAR(transaction_date)) (
       PARTITION p2023 VALUES LESS THAN (2024),
       PARTITION p2024 VALUES LESS THAN (2025),
       PARTITION pmax  VALUES LESS THAN MAXVALUE
   );
   ```

4. **Use views for repeated patterns** — the 7 views in `views/` encapsulate common JOINs so the optimizer can reuse execution plans

5. **Stored procedures reduce round trips** — `sp_get_account_statement` executes a single server-side call instead of multiple client queries
