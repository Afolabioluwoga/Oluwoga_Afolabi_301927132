#!/usr/bin/env bash
# run_p2.sh - Portfolio 2, re-runnable. Run from this folder (P1 must be loaded).
set -euo pipefail
PSQL="sudo runuser -u postgres -- psql -h /var/run/postgresql -d afordchess -v ON_ERROR_STOP=1"
mkdir -p results

echo "==> [1/5] Drop every idx_* index so the BEFORE run is fair, then ANALYZE"
$PSQL -At -c "SELECT 'DROP INDEX IF EXISTS ' || indexname || ';' FROM pg_indexes WHERE schemaname='public' AND indexname LIKE 'idx\_%'" | $PSQL -q
$PSQL -q -c "ANALYZE"

echo "==> [2/5] Run the 7 queries once (sanity check)"
$PSQL -f queries.sql > results/query_results.txt
grep -c . results/query_results.txt | sed 's/^/    result lines: /'

# Build the EXPLAIN ANALYZE version of queries.sql (adds EXPLAIN before each SELECT)
awk '/^SELECT/{print "EXPLAIN (ANALYZE, COSTS OFF)"} {print}' queries.sql > /tmp/p2_explain.sql

echo "==> [3/5] BEFORE plans -> explain_before.txt"
$PSQL -f /tmp/p2_explain.sql > explain_before.txt

echo "==> [4/5] Create the P2 indexes"
$PSQL -f indexes.sql

echo "==> [5/5] AFTER plans -> explain_after.txt, then summary"
$PSQL -f /tmp/p2_explain.sql > explain_after.txt
python3 summarise.py explain_before.txt explain_after.txt

echo ""
echo "==> P2 done. Evidence: explain_before.txt, explain_after.txt, explain_summary.txt"
