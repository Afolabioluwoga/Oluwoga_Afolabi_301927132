#!/usr/bin/env bash
# run_p1.sh — Portfolio 1 end-to-end. Run from this folder.
set -euo pipefail
PSQL="sudo runuser -u postgres -- psql -h /var/run/postgresql -d afordchess -v ON_ERROR_STOP=1"

$PSQL -c "ALTER DATABASE afordchess SET timezone TO 'Africa/Lagos'" >/dev/null
echo "==> [1/5] Create 14-table schema"
$PSQL -f schema.sql
echo "==> [2/5] Create triggers (capacity + enrolment)"
$PSQL -f triggers.sql
echo "==> [3/5] Seed reference data"
$PSQL -f seed_data.sql
echo "==> [4/5] Generate bulk data (60k+ attendance rows, ~15k payments)"
$PSQL -f bulk_generator.sql
echo "==> [5/5] Run constraint tests (5 expected PASS)"
$PSQL -f constraint_tests.sql

echo ""
echo "==> P1 done. Take the screenshots listed in README.md and commit:"
echo "    git add portfolio-1-database-design/ && git commit -m 'P1: schema, ER, triggers, bulk data, constraint tests'"
