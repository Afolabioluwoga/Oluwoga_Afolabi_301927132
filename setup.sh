#!/usr/bin/env bash
# setup.sh - PostgreSQL 16 + MongoDB + Python driver for the Afordchess portfolio (GitHub Codespaces / Ubuntu).
# Run from the repo root:  bash setup.sh        (safe to re-run)
set -euo pipefail
trap 'echo "!!! setup.sh stopped at line $LINENO - send Joseph the last 30 lines" >&2' ERR

echo "==> [1/7] Remove the stale yarn apt source (its expired key breaks apt-get update)"
sudo rm -f /etc/apt/sources.list.d/yarn.list
timeout 180 sudo apt-get update -y || echo "    (apt-get update had warnings, carrying on)"

echo "==> [2/7] PostgreSQL 16"
if ! pg_lsclusters 2>/dev/null | grep -q '^16 '; then
  sudo apt-get install -y curl gnupg ca-certificates lsb-release wget
  sudo install -d /usr/share/postgresql-common/pgdg
  sudo curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc
  echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
    | sudo tee /etc/apt/sources.list.d/pgdg.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y postgresql-16 postgresql-contrib-16
fi
sudo apt-get install -y postgresql-client libpq-dev build-essential >/dev/null 2>&1 || true
sudo pg_ctlcluster 16 main start 2>/dev/null || true
for i in $(seq 1 20); do sudo runuser -u postgres -- pg_isready -q -h /var/run/postgresql && break; sleep 1; done

echo "==> [3/7] Trust local socket logins (line goes at the TOP of pg_hba.conf)"
PG_HBA=/etc/postgresql/16/main/pg_hba.conf
if ! sudo grep -q '^# afordchess-trust' "$PG_HBA"; then
  sudo cp "$PG_HBA" "$PG_HBA.bak.afordchess"
  sudo sed -i '1i # afordchess-trust\nlocal   all             all                                     trust\nhost    all             all             127.0.0.1/32            trust' "$PG_HBA"
fi
sudo pg_ctlcluster 16 main reload

echo "==> [4/7] MongoDB"
if ! command -v mongod >/dev/null 2>&1; then
  curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | sudo gpg --yes -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/8.0 multiverse" \
    | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y mongodb-org
fi
sudo mkdir -p /data/db /var/log/mongodb
sudo chown -R mongodb:mongodb /data/db /var/log/mongodb 2>/dev/null || true
if ! pgrep -x mongod >/dev/null; then
  sudo runuser -u mongodb -- "$(command -v mongod)" --dbpath /data/db --logpath /var/log/mongodb/mongod.log --bind_ip 127.0.0.1 --port 27017 --fork >/dev/null
fi
for i in $(seq 1 20); do mongosh --quiet --eval 'db.runCommand({ping:1}).ok' 2>/dev/null | grep -q 1 && break; sleep 1; done

echo "==> [5/7] Databases and role"
PSQL="sudo runuser -u postgres -- psql -h /var/run/postgresql -v ON_ERROR_STOP=1"
$PSQL -c "DROP DATABASE IF EXISTS afordchess;"
$PSQL -c "CREATE DATABASE afordchess;"
$PSQL -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='afordchess') THEN CREATE ROLE afordchess LOGIN SUPERUSER PASSWORD 'afordchess'; END IF; END \$\$;"
$PSQL -c "ALTER DATABASE afordchess SET timezone TO 'Africa/Lagos';"

echo "==> [6/7] Python driver psycopg2 (fallback chain, then verified)"
python3 -c 'import psycopg2' 2>/dev/null \
 || pip install psycopg2-binary 2>/dev/null \
 || pip install --user psycopg2-binary 2>/dev/null \
 || pip install --break-system-packages psycopg2-binary 2>/dev/null \
 || pip install --user --break-system-packages psycopg2-binary 2>/dev/null \
 || sudo apt-get install -y python3-psycopg2
python3 -c 'import psycopg2; print("    psycopg2", psycopg2.__version__)'

echo "==> [7/7] Final check (any line below that says MISSING means setup failed)"
$PSQL -d afordchess -Atc "SELECT '    PostgreSQL ' || current_setting('server_version') || ', db ' || current_database() || ', tz ' || current_setting('TimeZone')" || echo "    PostgreSQL MISSING"
mongosh --quiet --eval 'print("    MongoDB " + db.version())' || echo "    MongoDB MISSING"
echo "==> Setup complete."
