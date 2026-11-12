# Portfolio 5 — Distributed & Cloud Database Exercise (Afordchess Academy)

**Course-note study session:** Session 2 (distributed DB, fragmentation, replication, consistency, CAP, BASE vs ACID), Session 3 (cloud DB systems, database security), Session 6 (data security & privacy).

## Files in this folder

| File | Purpose |
|---|---|
| `partition_payments.sql` | Converts `payments` from a flat table to a RANGE-partitioned table by `paid_at` (monthly), with 27 monthly partitions + a DEFAULT partition. Includes EXPLAIN showing partition pruning. |
| `replica_setup.sh` | Sets up a streaming read-replica on port 5433: creates the replication role, configures the primary, runs `pg_basebackup`, writes a dedicated `postgresql.conf` for the replica, and starts it. |
| `replica_demo.sql` | Three demos: (a) replica rejects writes, (b) new rows on the primary appear on the replica, (c) `pg_stat_replication` shows lag. |
| `cloud_architecture.md` | Multi-region architecture for students in NG / CA / US: data residency under NDPA 2023 and PIPEDA, CAP trade-offs, sync vs async replication, time-zone-aware class scheduling, sharding vs partitioning vs replication. |

## Commands

```bash
PSQL_PRIMARY="sudo runuser -u postgres -- psql -h /var/run/postgresql -d afordchess -v ON_ERROR_STOP=1"
PSQL_REPLICA="sudo runuser -u postgres -- psql -h /var/run/postgresql -p 5433 -d afordchess -v ON_ERROR_STOP=1"

# 1) Partition the payments table by paid_at month
$PSQL_PRIMARY -f partition_payments.sql

# 2) Set up the streaming read-replica on port 5433 (takes ~30s)
bash replica_setup.sh

# 3) Run the replica demo
$PSQL_PRIMARY -f replica_demo.sql
```

Or all in one go:

```bash
bash run_p5.sh
```

## What to screenshot

1. The `pg_partition_tree('payments')` output showing 27 monthly partitions + DEFAULT.
2. The `EXPLAIN` output showing partition pruning (only the relevant monthly partitions are scanned).
3. `pg_stat_replication` row showing `sent_lsn == replay_lsn` and the replica is `streaming`.
4. The `cannot execute INSERT in a read-only transaction` error from the replica.
5. The new row inserted on the primary appearing on the replica.

## What it demonstrates

- **Partitioning** (Study Session 2 — data fragmentation): monthly RANGE partitioning of payments, with EXPLAIN proving partition pruning.
- **Replication** (Study Session 2 — replication and consistency models): a streaming read-replica for reporting dashboards, with the replica rejecting writes.
- **Cloud architecture & data residency** (Study Sessions 3 & 6): a 3-region deployment that respects NDPA 2023 (Nigeria) and PIPEDA (Canada), with CAP trade-offs spelled out per workload.
- **Time zones**: `TIMESTAMPTZ` storage + local rendering for online classes across WAT / ET.

## Reflection

The individual reflection and the AI-use declaration are in the submitted documentation (sections 7 and 8).
