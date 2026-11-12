# Cloud Architecture — Afordchess Academy (multi-country deployment)

**Case study:** Students in Nigeria (NG), Canada (CA) and the USA (US), paying monthly in NGN, CAD or USD, attending online and in-person classes.

**Course-note mapping:** Session 2 (distributed DB, fragmentation, replication, consistency, CAP, BASE vs ACID), Session 3 (cloud DB systems, database security), Session 6 (data security & privacy).

---

## 1. Logical topology

```
                 ┌────────────────────────────────────────────────────────────┐
                 │                  Afordchess Academy — 3 regions           │
                 └────────────────────────────────────────────────────────────┘

   NG region (Lagos)             CA region (Toronto)            US region (Virginia)
   ┌────────────────────┐         ┌────────────────────┐         ┌────────────────────┐
   │ PG-primary (NGN)   │◀──async─│ PG-replica (CAD)   │◀──async─│ PG-replica (USD)   │
   │ MongoDB shard NG   │         │ MongoDB shard CA   │         │ MongoDB shard US   │
   │ Online classes TZ:│         │ Online classes TZ: │         │ Online classes TZ: │
   │   WAT (UTC+1)      │         │   ET  (UTC-5/-4)   │         │   ET  (UTC-5/-4)   │
   └────────────────────┘         └────────────────────┘         └────────────────────┘
            │                              │                              │
            └────── global analytics dashboard (reads from the CA replica) ─┘
```

- Each region runs its own PostgreSQL instance and its own MongoDB shard.
- The NG region hosts the **write-primary** for the financial core (students, enrolments, invoices, payments). CA and US run **streaming read-replicas** of the NG primary so dashboards stay local and fast.
- The replica set up in `replica_setup.sh` is a single-node proof of this topology: primary on the default port, replica on port 5433.
- Marketing metrics (MongoDB) are **sharded by country** so each region's social posts stay close to the users who view them.

## 2. Data residency & privacy law

### 2.1 NDPA 2023 (Nigeria Data Protection Act, 2023)

- **What is in scope:** personal data of Nigerian students (name, dob, guardian name, guardian phone, email) and their payment records.
- **Where the data lives:** the NG-region PostgreSQL primary and the NG-region MongoDB shard, both physically hosted in a Lagos data centre (e.g. an AWS `af-west-1`-equivalent or a Tier-III Lagos colo).
- **Cross-border transfer:** NDPA 2023 requires that personal data transferred outside Nigeria either (a) goes to a country on the NDPC's adequacy list, (b) is covered by an approved safeguard (standard contractual clauses / binding corporate rules), or (c) has the data subject's explicit consent. Canada and the USA are NOT automatically "adequate" — so Nigerian student PII does NOT replicate to the CA or US region. Only **aggregated, anonymised** statistics (e.g. monthly revenue totals) cross the border.
- **MongoDB metrics:** metric snapshots do not contain personal data (no student_id), so they CAN be replicated globally for the marketing dashboard.

### 2.2 PIPEDA (Canada — Personal Information Protection and Electronic Documents Act)

- **What is in scope:** personal information of Canadian students.
- **Where the data lives:** the CA-region PostgreSQL replica (which only stores the student rows whose `country_id` = Canada) and the CA-region MongoDB shard.
- **PIPEDA principles applied:** (4) limiting collection — we collect only what's needed for billing and class attendance; (5) limiting use, disclosure and retention — Canadian PII stays in Canada; (7) safeguards — TLS in transit, AES-256 at rest, role-based access; (8) openness — the privacy notice is in the student signup form.
- **US students** have no single federal privacy law; we apply **CCPA/CPRA-grade controls** (opt-out of sale, right to deletion) by default, hosted in the US region.

### 2.3 Cross-region data flow summary

| Data class | Stored in NG | Stored in CA | Stored in US | Cross-border? |
|---|---|---|---|---|
| Nigerian student PII | ✅ primary | ❌ | ❌ | Only anonymised aggregates leave NG |
| Canadian student PII | ❌ | ✅ | ❌ | Stays in CA |
| US student PII | ❌ | ❌ | ✅ | Stays in US |
| Payments (NGN/CAD/USD) | ✅ NGN primary | ✅ CAD replica | ✅ USD replica | Replicated only as anonymised daily totals for dashboards |
| Social-media metrics | ✅ | ✅ | ✅ | Yes (no PII) — global marketing dashboard |
| Comments (may contain author handles) | ✅ NG posts | ✅ CA posts | ✅ US posts | Author handle treated as PII under its region's law |

## 3. CAP theorem trade-offs

| Workload | Pick 2 of {C, A, P} | Justification |
|---|---|---|
| Payment insert (NGN) | **C + P** (sacrifice A) | Money must never be double-charged or lost. If the NG primary cannot reach a quorum, the transaction fails fast (reject) rather than accepting a write that could later be rolled back. |
| Marketing dashboard read | **A + P** (sacrifice C) | A dashboard being 5 minutes stale is acceptable. Use `readConcern: "local"` on the MongoDB replica — fast and eventually consistent. |
| Online class booking (the P3 race condition) | **C + P** | `SELECT ... FOR UPDATE` on the session row in the NG primary. The booking API never accepts a write against a replica. |
| Replica for reporting | **A + P** | Streaming replication is asynchronous — the reporting replica keeps serving reads even if the primary is briefly unreachable. The cost: eventual consistency on the reports. |

### Sync vs async replication

- **Synchronous** (e.g. PostgreSQL `synchronous_commit = on` with `synchronous_standby_names`) — used for cross-data-centre copies of payment data only when the second region's replica is the same AZ; otherwise the write-latency cost is too high.
- **Asynchronous streaming** (the default) — used for the cross-region replicas in this architecture. Acceptable because:
  - The marketing dashboard tolerates ~5s of staleness.
  - A regional outage does not block writes on the NG primary.

## 4. Serving online classes across time zones

| City | Time zone | Offset from UTC (Standard / DST) |
|---|---|---|
| Lagos, NG | WAT | UTC+1 (no DST) |
| Toronto, CA | ET | UTC−5 (EST) / UTC−4 (EDT, mid-Mar to early-Nov) |
| Virginia, US | ET | UTC−5 / UTC−4 (same DST rules as Canada ET) |

- All `starts_at` values in the `sessions` table are stored as `TIMESTAMPTZ` (UTC internally). The application converts to the student's local TZ when rendering a calendar.
- Online classes that cross regions are scheduled in a TZ-aware way: a 17:00 WAT class in Lagos is rendered as 12:00 EST in Toronto — that is acceptable for weekend classes, not for weekday mornings.
- For in-person classes, the school's local TZ is used and the `sessions.starts_at` is the local time of that school's country.

## 5. Sharding vs partitioning vs replication — what we used where

| Technique | Where | Why |
|---|---|---|
| **RANGE partitioning** (by `paid_at` month) | `payments` table | P5 partition_payments.sql — fast pruning of monthly revenue queries, easy month-by-month archival. |
| **Streaming replication** (primary + 1 replica) | PostgreSQL | P5 replica_setup.sh — read-scale-out for reporting dashboards, regional proximity. |
| **Sharding** (by country) | MongoDB metrics | Geo-distributed shards so each region's social metrics are queried locally. |
| **Async replication** | Cross-region | Avoids write-latency penalty across the Atlantic. |
| **NOT used: `postgres_fdw`** | — | Forbidden by the Codespaces rules and unnecessary; cross-region joins are done at the application layer. |

## 6. Disaster recovery

- **RPO** (recovery point objective): ≤ 5 minutes (async streaming lag).
- **RTO** (recovery time objective): ≤ 15 minutes — promote the regional replica with `pg_ctl promote` and re-point the application connection string.
- **MongoDB:** 3-node replica set per shard; automatic failover to the next healthy node.

## 7. What this demonstrates

The student can articulate CAP trade-offs per workload, design a multi-region deployment that respects Nigerian (NDPA 2023) and Canadian (PIPEDA) data-residency law, choose sync vs async replication per workload, and serve students across three time zones from a single logical schema.
