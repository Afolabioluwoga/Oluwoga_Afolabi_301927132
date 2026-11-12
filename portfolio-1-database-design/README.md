# Portfolio 1 — Database Design & Modelling (Afordchess Academy)

**Course-note study session:** Session 1 — Review of Traditional Relational Databases (DB design stages, components, normalisation, limitations of traditional DBMS).

## Files in this folder

| File | Purpose |
|---|---|
| `schema.sql` | The 14-table baseline relational schema (countries, currencies, schools, coaches, students, courses, course_enrolments, sessions, attendance, billing_plans, invoices, payments, social_posts, leads). Keys, FKs, CHECK constraints. |
| `er_diagram.md` | ER diagram in Mermaid matching the 14 tables, plus a table of which limitation is enforced where. |
| `triggers.sql` | Two triggers for the P1 README limitations: `trg_check_capacity` (session capacity) and `trg_check_enrolment` (enrolled-student-only booking). |
| `seed_data.sql` | Hand-written reference data: 3 currencies, 3 countries, 4 schools, 6 coaches, 12 students, 10 chess courses, enrolments, sessions, billing plans, invoices, social posts, leads. |
| `bulk_generator.sql` | Generates ~1,500 more students with realistic Nigerian/Canadian/US names, ~10k sessions, ~55k attendance rows, ~32k invoices, ~28k payments across NGN/CAD/USD, ~6k leads. |
| `constraint_tests.sql` | Five tests that MUST FAIL: duplicate email, wrong currency, in-person session without school, capacity exceeded (trigger), not-enrolled (trigger). |

## Commands (run from this folder, after `bash ../setup.sh`)

```bash
# Create schema (drops existing tables first)
sudo runuser -u postgres -- psql -h /var/run/postgresql -d afordchess -f schema.sql

# Add triggers
sudo runuser -u postgres -- psql -h /var/run/postgresql -d afordchess -f triggers.sql

# Seed small reference data
sudo runuser -u postgres -- psql -h /var/run/postgresql -d afordchess -f seed_data.sql

# Generate the bulk data (takes ~1–2 minutes)
sudo runuser -u postgres -- psql -h /var/run/postgresql -d afordchess -f bulk_generator.sql

# Run the constraint tests (5 expected PASS messages)
sudo runuser -u postgres -- psql -h /var/run/postgresql -d afordchess -f constraint_tests.sql
```

Or all in one go:

```bash
bash run_p1.sh
```

## What to screenshot

1. `\dt` of all 14 tables in `psql` (proves they all exist).
2. The final "Bulk data summary" table printed by `bulk_generator.sql` (proves >= 50k attendance + >= 20k payments across the 3 currencies).
3. The five `TEST N PASS: ...` messages from `constraint_tests.sql`.
4. The Mermaid ER diagram rendered in the GitHub web UI (open `er_diagram.md` on GitHub).

## Reflection

The individual reflection and the AI-use declaration are in the submitted documentation (sections 7 and 8).

## AI-use declaration

The individual reflection and the AI-use declaration are in the submitted documentation (sections 7 and 8).
