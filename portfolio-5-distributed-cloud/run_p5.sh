#!/usr/bin/env bash
# run_p5.sh - Portfolio 5: partitioning + streaming replica. Run from this folder. Re-runnable.
set -euo pipefail
cd "$(dirname "$0")"
PSQL="sudo runuser -u postgres -- psql -h /var/run/postgresql -p 5432 -d afordchess -v ON_ERROR_STOP=1"

echo "==> [1/3] Partition the payments table by paid_at month"
KIND=$($PSQL -Atc "SELECT relkind FROM pg_class WHERE relname='payments' AND relnamespace='public'::regnamespace")
if [ "$KIND" = "p" ]; then
  echo "    payments is already partitioned - skipping the migration, showing the counts"
  $PSQL -c "SELECT tableoid::regclass AS partition, COUNT(*) FROM payments GROUP BY 1 ORDER BY 1 DESC LIMIT 6"
else
  $PSQL -f partition_payments.sql
fi

echo "==> [2/3] Streaming read-replica on port 5433"
bash replica_setup.sh

echo "==> [3/3] Replica demo (saved to replication_output.log)"
bash replica_demo.sh 2>&1 | tee replication_output.log
echo ""
echo "==> P5 done. See cloud_architecture.md for the multi-country design."
