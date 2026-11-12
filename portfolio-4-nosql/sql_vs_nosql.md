# SQL vs NoSQL — why metrics live in MongoDB while payments stay in PostgreSQL

**Case study:** Afordchess Academy.

## What lives where, and why

| Concern | PostgreSQL (relational) | MongoDB (document) |
|---|---|---|
| Students, coaches, schools, courses, enrolments, sessions, attendance, invoices, **payments** | ✅ Strong consistency, ACID transactions, foreign keys, multi-currency constraints | ❌ |
| Social-media posts (Instagram reels/carousels, TikTok sounds/duets, YouTube chapters) | ❌ Hard to model the platform-specific fields without dozens of nullable columns or many tables | ✅ Polymorphic documents — one collection, platform-specific sub-objects |
| Daily metric snapshots (views, likes, shares, watch-time, FYP impressions) | ❌ Schema changes every time a platform adds a new metric | ✅ Add a new field to the next document; no migration |
| Comments | ✅ Possible, but not joined transactionally to anything financial | ✅ Better fit; rarely read together with payments |
| Marketing funnel (leads → conversions → student) | ✅ The student-side is relational; the post-side is document | ✅ Conversions collection keeps a denormalised `converted_student_id` |

## Suitability analysis (Study Sessions 3 and 5)

1. **Schema flexibility.** Instagram has reels & carousels, TikTok has sounds & duets, YouTube has watch-time & chapters. Each platform adds new metric fields frequently. A document store absorbs these changes without a schema migration; PostgreSQL would need an `ALTER TABLE` per new metric and a growing set of nullable columns.
2. **Read pattern.** Marketing dashboards read "all metrics for a post over the last 30 days" — a single document lookup by `_id` or `{post_id, date}`. MongoDB returns the whole document in one trip; PostgreSQL would need joins across `social_posts`, `daily_metrics`, `comments` and `conversions` tables.
3. **Write pattern.** Metric snapshots are appended once per day per post (high write volume, no updates). MongoDB's WiredTiger storage handles append-only workloads efficiently and shards well (P5 territory: geographic sharding by `country`).
4. **Consistency boundary.** Payments MUST be ACID with the invoice they settle (the composite FK guarantees the currency matches). This is the canonical "money side" of the trade-off, so it stays in PostgreSQL. The marketing side tolerates eventual consistency — a comment showing up two seconds late is fine.
5. **Joins across the boundary.** We do NOT use `postgres_fdw` (forbidden by the Codespaces rules and a bad fit anyway). Instead the conversions collection stores a denormalised `converted_student_id` that references the PostgreSQL `students.student_id`. Joining the two stores for a report is an application-level responsibility (read from Mongo, then `WHERE student_id = ANY(...)` against PostgreSQL).

## CAP / BASE vs ACID mapping (Study Session 2)

- **PostgreSQL payments = ACID.** Partition tolerance is provided by streaming replication (P5); a payment is either committed on the primary or not — no half-states.
- **MongoDB metrics = BASE + tunable consistency.** `writeConcern: "majority"` for important metric uploads (durability across the replica set), `readConcern: "local"` for dashboards (fast, accepts slight staleness).
- This matches the **polyglot persistence** pattern from Study Session 5 (emerging trends): use the right store for each workload instead of forcing one store to do everything.

## What we did NOT move to MongoDB

We deliberately keep the financial core (invoices, payments, billing_plans) in PostgreSQL. Putting money in MongoDB would mean losing the composite-FK currency check and the `trg_check_capacity` / `trg_check_enrolment` triggers — both of which P1 demonstrates as critical business rules. The trade-off is consciously ACID on the money side, BASE on the metrics side.
