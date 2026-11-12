#!/usr/bin/env bash
# run_p4.sh - Portfolio 4 (MongoDB). Run from this folder. Re-runnable.
set -euo pipefail
cd "$(dirname "$0")"
# Codespaces stops background programs when it sleeps: start mongod if it is off
if ! pgrep -x mongod >/dev/null; then
  sudo mkdir -p /data/db /var/log/mongodb
  sudo chown -R mongodb:mongodb /data/db /var/log/mongodb 2>/dev/null || true
  sudo runuser -u mongodb -- /usr/bin/mongod --dbpath /data/db --logpath /var/log/mongodb/mongod.log --bind_ip 127.0.0.1 --port 27017 --fork >/dev/null
  sleep 3
fi
MONGOSH="mongosh --quiet"
echo "==> [1/4] Create collections with schema validation"
$MONGOSH --file schema_validation.js
echo "==> [2/4] Generate ~42,000 documents"
$MONGOSH --file seed_posts.js
echo "==> Validation tests: 2 bad documents must be REJECTED"
$MONGOSH --file validation_tests.js
echo "==> [3/4] Four aggregation pipelines"
$MONGOSH --file aggregations.js
echo "==> [4/4] COLLSCAN -> IXSCAN demo"
$MONGOSH --file index_demo.js | tee index_demo_summary.txt
echo ""
echo "==> P4 done."
