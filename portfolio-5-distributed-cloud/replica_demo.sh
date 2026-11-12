#!/usr/bin/env bash
# replica_demo.sh - ONE script that talks to the primary (5432) and the replica (5433) in turn.
set -euo pipefail
P="sudo runuser -u postgres -- psql -h /var/run/postgresql -d afordchess -p 5432 -X"
R="sudo runuser -u postgres -- psql -h /var/run/postgresql -d afordchess -p 5433 -X"
echo "================ Replica demo: primary (5432) + streaming replica (5433) ================"
echo; echo "### 1. Who is who"
$P -Atc "SELECT 'PRIMARY port ' || current_setting('port') || '  in_recovery=' || pg_is_in_recovery()"
$R -Atc "SELECT 'REPLICA port ' || current_setting('port') || '  in_recovery=' || pg_is_in_recovery()"
echo; echo "### 2. Write on the REPLICA must be rejected"
if $R -c "INSERT INTO students(first_name,last_name,email,country_id) VALUES ('Should','Fail','should.fail@example.com',1)" 2>&1; then
  echo "UNEXPECTED: write was accepted on the replica"; exit 1
else echo "-> rejected as expected (replica is read-only)"; fi
echo; echo "### 3. Insert on the PRIMARY"
$P -c "DELETE FROM students WHERE email='demo.replica@example.com'" >/dev/null
$P -c "INSERT INTO students(first_name,last_name,email,country_id) VALUES ('DemoReplica','Streaming','demo.replica@example.com',(SELECT country_id FROM countries WHERE iso_code='NG')) RETURNING student_id, email"
sleep 2
echo; echo "### 4. Read the same row on the REPLICA"
$R -c "SELECT student_id, first_name, last_name, email FROM students WHERE email='demo.replica@example.com'"
echo; echo "### 5. Replication state, seen from the PRIMARY"
$P -c "SELECT application_name, state, sync_state, sent_lsn, replay_lsn, sent_lsn - replay_lsn AS lag_bytes FROM pg_stat_replication"
echo; echo "### 6. Replay position, seen from the REPLICA"
$R -c "SELECT pg_last_wal_replay_lsn() AS replayed_up_to, pg_is_in_recovery() AS in_recovery"
echo; echo "================ End of replica demo ================"
