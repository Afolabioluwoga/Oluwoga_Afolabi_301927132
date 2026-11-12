-- ============================================================================
--  partition_payments.sql — partition the payments table by billing month.
--  Run AFTER P1 has loaded the schema + bulk data.
--
--  Approach: rename the existing `payments` table to `payments_unpartitioned`,
--  create a new partitioned `payments` table with the SAME columns + FKs,
--  create monthly RANGE partitions for the last 24 months + next 2 months
--  plus a DEFAULT partition, then migrate the rows.
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1) Rename the existing payments table out of the way -----------------------
ALTER TABLE payments RENAME TO payments_unpartitioned;

-- 2) Create the partitioned payments table ----------------------------------
--    PRIMARY KEY must include the partition key (paid_at) in PostgreSQL.
CREATE TABLE payments (
    payment_id       BIGSERIAL,
    invoice_id       INTEGER     NOT NULL,
    student_id       INTEGER     NOT NULL,
    amount           NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    currency_code    CHAR(3)     NOT NULL,
    paid_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    method           TEXT        NOT NULL CHECK (method IN ('bank_transfer','card','mobile_money','paypal')),
    PRIMARY KEY (payment_id, paid_at),
    CONSTRAINT fk_pay_invoice_currency_partitioned
        FOREIGN KEY (invoice_id, currency_code)
        REFERENCES invoices(invoice_id, currency_code),
    CONSTRAINT fk_pay_student_partitioned
        FOREIGN KEY (student_id) REFERENCES students(student_id)
) PARTITION BY RANGE (paid_at);

-- 3) Create monthly partitions (last 24 months + current + next 2) ----------
DO $$
DECLARE
    m                INTEGER;
    partition_start  DATE;
    partition_end    DATE;
    partition_name   TEXT;
BEGIN
    FOR m IN -24 .. 2 LOOP
        partition_start := date_trunc('month', CURRENT_DATE + (m || ' months')::interval)::date;
        partition_end   := (partition_start + INTERVAL '1 month')::date;
        partition_name  := 'payments_' || to_char(partition_start, 'YYYYMM');
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF payments FOR VALUES FROM (%L) TO (%L)',
            partition_name, partition_start, partition_end);
    END LOOP;
END $$;

-- DEFAULT partition catches any stragglers outside the monthly range
CREATE TABLE payments_default PARTITION OF payments DEFAULT;

-- 4) Migrate rows from the old (unpartitioned) table ------------------------
INSERT INTO payments (payment_id, invoice_id, student_id, amount, currency_code, paid_at, method)
SELECT payment_id, invoice_id, student_id, amount, currency_code, paid_at, method
  FROM payments_unpartitioned
 ORDER BY paid_at;

-- 5) Re-apply the helpful indexes from P1 (per-partition) -------------------
CREATE INDEX idx_payments_paidat_currency_part  ON payments (paid_at, currency_code);
CREATE INDEX idx_payments_invoice_part          ON payments (invoice_id);
CREATE INDEX idx_payments_paidat_part           ON payments (paid_at);

COMMIT;

-- 6) Show the partition tree ------------------------------------------------
\echo ''
\echo '===== payments partition tree ====='
SELECT t.relid::regclass AS partition, t.isleaf,
       pg_get_expr(c.relpartbound, c.oid) AS partition_bound
  FROM pg_partition_tree('payments') t
  JOIN pg_class c ON c.oid = t.relid
 ORDER BY t.isleaf DESC, 1 DESC
 LIMIT 8;

-- 7) Show partition pruning in action ---------------------------------------
\echo ''
\echo '===== EXPLAIN — partition pruning on payments (last 3 months) ====='
EXPLAIN (COSTS OFF)
SELECT COUNT(*) FROM payments
 WHERE paid_at >= date_trunc('month', CURRENT_DATE) - INTERVAL '3 months'
   AND paid_at <  date_trunc('month', CURRENT_DATE);

-- 8) Exact row counts per partition (DEFAULT partition must be 0) ------------
ANALYZE payments;
\echo ''
\echo '===== Row count per monthly partition (newest 6) + DEFAULT partition ====='
SELECT tableoid::regclass AS partition, COUNT(*) AS rows
  FROM payments
 GROUP BY tableoid
 ORDER BY 1 DESC LIMIT 6;
SELECT 'payments_default (must be 0)' AS check_name, COUNT(*) AS rows FROM payments_default;
SELECT 'total in partitioned table' AS check_name, COUNT(*) AS rows FROM payments
UNION ALL SELECT 'total in old unpartitioned table', COUNT(*) FROM payments_unpartitioned;

-- 9) One-month query: partitioned vs unpartitioned (real timings) ------------
\echo ''
\echo '===== One-month query on the PARTITIONED table ====='
EXPLAIN (ANALYZE, COSTS OFF)
SELECT currency_code, SUM(amount) FROM payments
 WHERE paid_at >= date_trunc('month', CURRENT_DATE) - INTERVAL '3 months'
   AND paid_at <  date_trunc('month', CURRENT_DATE) - INTERVAL '2 months'
 GROUP BY 1;
\echo ''
\echo '===== Same query on the UNPARTITIONED table ====='
ANALYZE payments_unpartitioned;
EXPLAIN (ANALYZE, COSTS OFF)
SELECT currency_code, SUM(amount) FROM payments_unpartitioned
 WHERE paid_at >= date_trunc('month', CURRENT_DATE) - INTERVAL '3 months'
   AND paid_at <  date_trunc('month', CURRENT_DATE) - INTERVAL '2 months'
 GROUP BY 1;

\echo ''
\echo '==> Done. The payments table is now RANGE-partitioned by paid_at.'
