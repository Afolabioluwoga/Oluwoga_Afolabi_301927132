# Portfolio 2 - Query Processing & Optimisation (Afordchess Academy)

| File | Purpose |
|---|---|
| `queries.sql` | 7 business queries. Q1, Q3, Q4, Q6, Q7 are selective (one coach, one currency, recent window); Q2 and Q5 are full-history aggregates kept on purpose. |
| `indexes.sql` | The index set created after the BEFORE plans are captured. |
| `summarise.py` | Builds `explain_summary.txt` from the two plan files. |
| `run_p2.sh` | Drops all `idx_*` indexes, ANALYZE, runs queries, BEFORE plans, creates indexes, AFTER plans, summary. Safe to re-run. |

Run: `bash run_p2.sh`. Evidence produced: `explain_before.txt`, `explain_after.txt`, `explain_summary.txt` (times and how each table was read).

## Honest reading of the results
Indexes clearly help the selective queries that read the big tables: Q4 (invoices) and Q3 and Q6 (attendance, 65k rows) change from a Seq Scan to an index or bitmap scan and get several times faster. Q1 and Q7 read only the ~28k-row `payments` table, so the gain is small and can sit inside run-to-run noise. Q2 and Q5 are full-history aggregates: a Seq Scan with a Hash Join is the correct plan there, and any before/after difference is noise because the plan did not change. The exact numbers are in `explain_summary.txt` from your own run.

Suggested commit: `git add portfolio-2-query-optimisation/ && git commit -m "P2: 7 queries, EXPLAIN ANALYZE before/after indexes"`
