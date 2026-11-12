#!/usr/bin/env bash
# replica_setup.sh - streaming read-replica on port 5433 (Codespaces / Ubuntu). Re-runnable.
# Primary: Unix socket /var/run/postgresql port 5432. Replica: same socket dir, port 5433.
set -euo pipefail
PG_BIN=/usr/lib/postgresql/16/bin
PG_REPLICA_DATA=/var/lib/postgresql/16/replica
PG_CONF=/etc/postgresql/16/main
PG_HBA="$PG_CONF/pg_hba.conf"
REPL_PORT=5433
REPL_USER=afordchess_repl
PSQL_P="sudo runuser -u postgres -- psql -h /var/run/postgresql -p 5432 -d postgres -v ON_ERROR_STOP=1"

echo "==> [1/7] Replication role on the primary"
$PSQL_P -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='$REPL_USER') THEN CREATE ROLE $REPL_USER WITH REPLICATION LOGIN PASSWORD 'afordchess_repl_pass'; END IF; END \$\$;"

echo "==> [2/7] Allow replication connections (lines go at the TOP of pg_hba.conf)"
if ! sudo grep -q '^# afordchess-replication' "$PG_HBA"; then
  sudo cp "$PG_HBA" "$PG_HBA.bak.repl"
  sudo sed -i '1i # afordchess-replication\nlocal   replication     all                                     trust\nhost    replication     all             127.0.0.1/32            trust' "$PG_HBA"
fi
sudo pg_ctlcluster 16 main restart
sleep 2

echo "==> [3/7] Stop any old replica and remove its slot and data"
sudo runuser -u postgres -- "$PG_BIN/pg_ctl" -D "$PG_REPLICA_DATA" -m fast stop 2>/dev/null || true
$PSQL_P -c "SELECT pg_drop_replication_slot('replica_slot') FROM pg_replication_slots WHERE slot_name='replica_slot';" >/dev/null
sudo rm -rf "$PG_REPLICA_DATA"
sudo mkdir -p "$PG_REPLICA_DATA"
sudo chown postgres:postgres "$PG_REPLICA_DATA"
sudo chmod 700 "$PG_REPLICA_DATA"

echo "==> [4/7] pg_basebackup of the primary into the replica directory"
sudo runuser -u postgres -- "$PG_BIN/pg_basebackup" -h /var/run/postgresql -p 5432 \
    -D "$PG_REPLICA_DATA" -U "$REPL_USER" -w -X stream -C -S replica_slot -R

echo "==> [5/7] Config files for the replica (Ubuntu keeps them in /etc, so pg_basebackup copies none)"
sudo tee "$PG_REPLICA_DATA/postgresql.conf" >/dev/null <<CONF
port = $REPL_PORT
listen_addresses = 'localhost'
unix_socket_directories = '/var/run/postgresql'
hot_standby = on
wal_level = replica
max_wal_senders = 10
max_connections = 100
logging_collector = off
hba_file = '$PG_REPLICA_DATA/pg_hba.conf'
ident_file = '$PG_REPLICA_DATA/pg_ident.conf'
data_directory = '$PG_REPLICA_DATA'
CONF
sudo tee "$PG_REPLICA_DATA/pg_hba.conf" >/dev/null <<'HBA'
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
local   replication     all                                     trust
host    replication     all             127.0.0.1/32            trust
HBA
sudo touch "$PG_REPLICA_DATA/pg_ident.conf"
sudo chown -R postgres:postgres "$PG_REPLICA_DATA"
sudo chmod 700 "$PG_REPLICA_DATA"

echo "==> [6/7] Start the replica on port $REPL_PORT"
sudo runuser -u postgres -- "$PG_BIN/pg_ctl" -D "$PG_REPLICA_DATA" -l /tmp/pg-replica.log -w start
sleep 3

echo "==> [7/7] Check: replica is in recovery and the primary sees it streaming"
sudo runuser -u postgres -- psql -h /var/run/postgresql -p $REPL_PORT -d afordchess -Atc "SELECT 'replica pg_is_in_recovery = ' || pg_is_in_recovery()"
sudo runuser -u postgres -- psql -h /var/run/postgresql -p 5432 -d afordchess -c "SELECT application_name, state, sync_state FROM pg_stat_replication"
