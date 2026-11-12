# Portfolio 4 — NoSQL & Advanced Data Models (Afordchess Academy)

**Course-note study session:** Session 5 — Emerging Trends (DB evolution, graph DBs) and Session 3 — Big Data & Cloud DBs.

## Files in this folder

| File | Purpose |
|---|---|
| `schema_validation.js` | Creates four collections (`social_posts`, `daily_metrics`, `comments`, `conversions`) with strict `$jsonSchema` validators. Platform-specific fields are nested under `instagram` / `tiktok` / `youtube` sub-objects. |
| `seed_posts.js` | Generates ~42,000 documents: 3,000 posts (1k per platform), 30,000 daily metric snapshots, ~6,000 comments, 3,000 conversions. |
| `aggregations.js` | Four pipelines: engagement per platform, best post types per platform, posts linked to conversions (top revenue), top TikTok sounds by duets. |
| `index_demo.js` | Shows `COLLSCAN` → `IXSCAN` by creating `{ post_id: 1, date: 1 }` on `daily_metrics`. |
| `sql_vs_nosql.md` | Why metrics suit MongoDB while payments stay in PostgreSQL. |

## Platform-specific fields

| Platform | Sub-object fields |
|---|---|
| Instagram | `post_type` (reel/carousel/story), `duration_seconds`, `slides_count`, `filter_used` |
| TikTok | `post_type` (video/duet/stitch), `sound_id`, `sound_title`, `duet_with`, `stitch_with`, `duration_seconds` |
| YouTube | `video_id`, `duration_seconds`, `chapters[]`, `watch_time_seconds_avg` |

## Commands

```bash
MONGOSH="mongosh --quiet afordchess"

# 1) Create the collections with schema validation
$MONGOSH --file schema_validation.js

# 2) Generate ~42k documents (takes ~30s)
$MONGOSH --file seed_posts.js

# 3) Run the four aggregation pipelines
$MONGOSH --file aggregations.js

# 4) Show COLLSCAN -> IXSCAN
$MONGOSH --file index_demo.js
```

Or all in one go:

```bash
bash run_p4.sh
```

## What to screenshot

1. The "Inserted ... documents" lines from `seed_posts.js` and the final `TOTAL` count (>= 40,000).
2. The four aggregation outputs from `aggregations.js` (engagement per platform; best post types per platform; top-10 posts by converted revenue; top TikTok sounds by duets).
3. The `index_demo.js` output showing `totalDocsExamined` going from the full collection size (COLLSCAN) down to the matching documents only (IXSCAN).
4. The `getIndexes()` output at the end of `index_demo.js`.

## What it demonstrates

Polymorphic document modelling, JSON-schema validation, large-volume bulk insert, aggregation pipelines with `$lookup` and `$group`, and index selection — all aligned with the NoSQL / big-data material from course Sessions 3 and 5.

## Reflection

The individual reflection and the AI-use declaration are in the submitted documentation (sections 7 and 8).
