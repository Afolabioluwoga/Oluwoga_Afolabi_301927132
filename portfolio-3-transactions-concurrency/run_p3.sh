#!/usr/bin/env bash
# run_p3.sh - Portfolio 3 (transactions and concurrency). Run from this folder after P1.
set -euo pipefail
cd "$(dirname "$0")"
PSQL="sudo runuser -u postgres -- psql -h /var/run/postgresql -d afordchess -v ON_ERROR_STOP=1"
python3 -c 'import psycopg2' 2>/dev/null || {
  echo "==> psycopg2 missing - installing"
  pip install psycopg2-binary 2>/dev/null || pip install --user psycopg2-binary 2>/dev/null \
   || pip install --break-system-packages psycopg2-binary 2>/dev/null \
   || pip install --user --break-system-packages psycopg2-binary 2>/dev/null \
   || sudo apt-get install -y python3-psycopg2
  python3 -c 'import psycopg2'
}
echo "==> [1/2] Load the booking functions"
$PSQL -f book_session.sql
echo "==> [2/2] Run all race, isolation and deadlock demos with two real sessions"
python3 run_race_demos.py 2>&1 | tee race_demos_output.log
echo "==> P3 done. Evidence: race_demos_output.log"
