# Step 0 — Brief Summary of the CA

Student: Afolabi Oluwoga · Matric: 2026/A/MIT/0686 · MIT 8103 Advanced Database Systems · Miva Open University · 2026/2027 First Semester.

## What the CA requires (half-page)

The Continuous Assessment is an **individual practical database portfolio** worth **40 marks**, submitted on the LMS **plus** a private GitHub repository. There is no single compulsory organisation; each student picks one realistic case study and uses it consistently across all five portfolios. The case study chosen here is **Afordchess Academy**, a chess coaching business with online classes and in-person classes in partner schools, students in Nigeria, Canada and the USA, monthly billing in NGN/CAD/USD, and marketing on Instagram, TikTok and YouTube.

The five portfolios and the final documentation carry the marks as follows: P1 Database Design & Modelling (7), P2 Query Processing & Optimisation (7), P3 Transactions & Concurrency (7), P4 NoSQL & Advanced Data Models (7), P5 Distributed & Cloud Database Exercise (6), and Final Documentation (6). Each portfolio folder must contain practical evidence (SQL/JS scripts, ER diagrams, execution plans, screenshots, README files), and the GitHub repository must show **progressive commits** rather than a single end-of-semester upload. The final LMS submission is a **2–3 page documentation** describing all five activities, naming the case study, linking the GitHub repo, and containing an individual technical reflection plus an **AI-use declaration** (tool used, what for, how output was reviewed/tested).

Submission and integrity rules: individual work only; AI tools permitted as learning aids but the student remains responsible for accuracy, originality and explanation; suspicious or copied submissions may trigger a verification viva; the GitHub link must be accessible to the assessor before LMS submission. No real people or records are used in this portfolio — all names, payments and posts are invented.

## Portfolio → Course-note study session mapping

| Portfolio | Title | Primary course-note study session(s) it applies | Why |
|---|---|---|---|
| P1 | Database Design & Modelling | **Study Session 1** — Review of Traditional Relational Databases (DB design stages, components, characteristics of a good DB, normalisation, limitations of traditional DBMS) | P1 is relational schema design, keys, constraints and normalisation — the core of Session 1. |
| P2 | Query Processing & Optimisation | **Study Session 4** — Query Optimisation (intro to queries, query optimisation, execution plans & cost estimation, file organisation) | EXPLAIN ANALYZE, execution plans and indexing map directly to Session 4. |
| P3 | Transactions & Concurrency | **Study Session 1** (DBMS functions — concurrency & recovery; limitations of traditional DBMS) and **Study Session 2** (CAP, BASE vs ACID) | Transactions, isolation levels, locks and race conditions are the concurrency & ACID material from Sessions 1 & 2. |
| P4 | NoSQL & Advanced Data Models | **Study Session 5** — Emerging Trends (DB evolution, graph DBs) and **Study Session 3** — Big Data & Cloud DBs | NoSQL document modelling is the "emerging trends / big data" material; MongoDB metrics suit the big-data use case in Session 3. |
| P5 | Distributed & Cloud Database Exercise | **Study Session 2** — Distributed DB Systems (fragmentation, replication, consistency, CAP, BASE vs ACID) and **Study Session 3** — Big Data & Cloud DBs (cloud DB systems, database security) plus **Study Session 6** — Data Security & Privacy | Partitioning, streaming replication, cloud deployment, NDPA/PIPEDA compliance and CAP trade-offs are exactly Sessions 2, 3 and 6. |

> Note on the baseline schema: the original `schema.sql` and P1 `README.md` were not attached to this delivery run, so the 14-table design in `portfolio-1-database-design/schema.sql` is the **baseline** that all subsequent portfolios extend. Table names, keys and constraints follow standard PostgreSQL conventions and the Afordchess Academy case study (chess courses, students in NG/CA/US, multi-currency billing, social-media marketing). If the student's real P1 schema differs only in cosmetic naming, the rest of the portfolio still runs unchanged after a find/replace.
