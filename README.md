# Advanced Database Systems Portfolio — Afordchess Academy

**Student:** Afolabi Oluwoga · **Matric:** 2026/A/MIT/0686 · **Programme:** Master of Information Technology, Miva Open University · **Course:** MIT 8103 Advanced Database Systems · **Session:** 2026/2027 First Semester.

**GitHub Repository:** [GitHub link]

## Case study

**Afordchess Academy** — a chess coaching business that delivers online classes and in-person classes in partner schools, with students in Nigeria, Canada and the USA. Students pay monthly in NGN, CAD or USD; marketing runs on Instagram, TikTok and YouTube. All data in this portfolio is **invented**; no real people or records are used.

## What is in this repo

| Folder | Portfolio | Marks | What it demonstrates |
|---|---|---|---|
| `portfolio-1-database-design/` | P1 Database Design & Modelling | 7 | 14-table relational schema, ER diagram, triggers, seed + bulk data, constraint tests. |
| `portfolio-2-query-optimisation/` | P2 Query Processing & Optimisation | 7 | 7 business queries, EXPLAIN ANALYZE before/after indexing. |
| `portfolio-3-transactions-concurrency/` | P3 Transactions & Concurrency | 7 | `book_session()` transaction, two-terminal race-condition demo, isolation levels, deadlock. |
| `portfolio-4-nosql/` | P4 NoSQL & Advanced Data Models | 7 | MongoDB social posts + metrics with schema validation, aggregations, 40k+ docs, COLLSCAN→IXSCAN. |
| `portfolio-5-distributed-cloud/` | P5 Distributed & Cloud Database Exercise | 6 | Payment partitioning, primary + streaming replica, multi-country cloud architecture. |
| `docs/` | Brief summary, AI-use declaration | — | Step 0 summary of the CA. |

## Quick start (GitHub Codespaces)

1. Open this repo in a GitHub Codespace (Ubuntu image).
2. From the repo root, run:
   ```bash
   bash setup.sh
   ```
   This installs PostgreSQL 16 and MongoDB 8, starts both services, and creates the `afordchess` PostgreSQL database and the `afordchess` MongoDB database.
3. Enter any portfolio folder and run its `run_pN.sh` script, e.g.:
   ```bash
   cd portfolio-1-database-design && bash run_p1.sh
   ```
4. Each portfolio `README.md` lists the commands to run, what to screenshot, and the suggested `git commit` message.

## Conventions

- PostgreSQL 16 (relational store for P1, P2, P3, P5) and MongoDB 8 (document store for P4).
- Codespaces sudo rule: the codespace user can `sudo` only as root, so all `postgres` commands use `sudo runuser -u postgres -- …`.
- TCP logins need a password; we connect through the Unix socket at `/var/run/postgresql` (`host=/var/run/postgresql`) instead.
- All dates are **relative to today** (`CURRENT_DATE`, `NOW()`) so the seed data never expires.
- Outputs you must capture yourself (EXPLAIN plans, timings, screenshots) are marked `[paste real output here]` — nothing is simulated.

## Individual work & AI declaration

This is individual work. AI tools were used as a learning aid during drafting and scripting; the student reviewed, corrected and verified every script before committing. A full AI-use declaration is included in the final 2–3 page documentation.

> The 2–3 page documentation PDF (`Oluwoga_Afolabi_2026-A-MIT-0686_Documentation.pdf`) is produced **after** the student has run all five portfolios and captured the real outputs.
