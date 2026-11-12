-- ============================================================================
--  Afordchess Academy — Relational Schema (P1 baseline, 14 tables)
--  Student: Afolabi Oluwoga · 2026/A/MIT/0686 · MIT 8103
--
--  Case study: Afordchess Academy — chess coaching business with online
--  classes and in-person classes in partner schools, students in Nigeria,
--  Canada and the USA, monthly billing in NGN / CAD / USD, and marketing
--  on Instagram, TikTok and YouTube. All data is invented.
--
--  This file is the BASELINE design that P2–P5 extend. Do not redesign it.
--  Subsequent portfolios only ADD: triggers, indexes, partitions, replicas, etc.
-- ============================================================================

-- Drop in dependency order (children first) so the script is idempotent. -----
DROP TABLE IF EXISTS payments_unpartitioned CASCADE;   -- left behind by P5 on a re-run
DROP TABLE IF EXISTS leads              CASCADE;
DROP TABLE IF EXISTS social_posts       CASCADE;
DROP TABLE IF EXISTS payments           CASCADE;
DROP TABLE IF EXISTS invoices           CASCADE;
DROP TABLE IF EXISTS billing_plans      CASCADE;
DROP TABLE IF EXISTS attendance          CASCADE;
DROP TABLE IF EXISTS sessions           CASCADE;
DROP TABLE IF EXISTS course_enrolments  CASCADE;
DROP TABLE IF EXISTS courses            CASCADE;
DROP TABLE IF EXISTS students           CASCADE;
DROP TABLE IF EXISTS coaches            CASCADE;
DROP TABLE IF EXISTS schools            CASCADE;
DROP TABLE IF EXISTS currencies         CASCADE;
DROP TABLE IF EXISTS countries          CASCADE;

-- 1. countries ---------------------------------------------------------------
CREATE TABLE countries (
    country_id     SERIAL PRIMARY KEY,
    name           TEXT        NOT NULL,
    iso_code       CHAR(2)     NOT NULL UNIQUE,            -- NG, CA, US
    default_currency_code CHAR(3) NOT NULL,                -- resolved by FK below
    phone_prefix   TEXT        NOT NULL                     -- +234, +1, ...
);

-- 2. currencies --------------------------------------------------------------
CREATE TABLE currencies (
    currency_code  CHAR(3) PRIMARY KEY,                    -- NGN, CAD, USD
    name           TEXT        NOT NULL,
    symbol         TEXT        NOT NULL,
    usd_rate       NUMERIC(12,6) NOT NULL DEFAULT 1.0        -- 1 unit = usd_rate USD
);

ALTER TABLE countries
    ADD CONSTRAINT fk_countries_currency
    FOREIGN KEY (default_currency_code) REFERENCES currencies(currency_code);

-- 3. schools (partner schools for in-person classes) -------------------------
CREATE TABLE schools (
    school_id       SERIAL PRIMARY KEY,
    name            TEXT        NOT NULL,
    country_id      INTEGER     NOT NULL,
    address         TEXT        NOT NULL,
    contact_email   TEXT        NOT NULL,
    CONSTRAINT fk_schools_country FOREIGN KEY (country_id) REFERENCES countries(country_id)
);

-- 4. coaches -----------------------------------------------------------------
CREATE TABLE coaches (
    coach_id        SERIAL PRIMARY KEY,
    first_name      TEXT        NOT NULL,
    last_name       TEXT        NOT NULL,
    email           TEXT        NOT NULL UNIQUE,             -- LIMITATION: unique email
    country_id      INTEGER     NOT NULL,
    phone           TEXT,
    hired_at        DATE        NOT NULL DEFAULT CURRENT_DATE,
    specialty       TEXT,                                   -- 'tactics', 'endgames', ...
    CONSTRAINT fk_coaches_country FOREIGN KEY (country_id) REFERENCES countries(country_id)
);

-- 5. students ----------------------------------------------------------------
CREATE TABLE students (
    student_id      SERIAL PRIMARY KEY,
    first_name      TEXT        NOT NULL,
    last_name       TEXT        NOT NULL,
    email           TEXT        NOT NULL UNIQUE,             -- LIMITATION: unique email
    country_id      INTEGER     NOT NULL,
    dob             DATE,
    signup_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    guardian_name   TEXT,                                   -- many students are minors
    guardian_phone  TEXT,
    CONSTRAINT fk_students_country FOREIGN KEY (country_id) REFERENCES countries(country_id)
);

-- 6. courses -----------------------------------------------------------------
CREATE TABLE courses (
    course_id       SERIAL PRIMARY KEY,
    name            TEXT        NOT NULL,
    description     TEXT,
    level           TEXT        NOT NULL CHECK (level IN ('beginner','intermediate','advanced','all-levels')),
    mode            TEXT        NOT NULL CHECK (mode  IN ('online','in-person','hybrid')),
    duration_weeks  INTEGER     NOT NULL CHECK (duration_weeks > 0)
);

-- 7. course_enrolments (a student can only be in a course once) -------------
CREATE TABLE course_enrolments (
    enrolment_id    SERIAL PRIMARY KEY,
    student_id      INTEGER     NOT NULL,
    course_id       INTEGER     NOT NULL,
    enrolled_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status          TEXT        NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','completed','dropped')),
    CONSTRAINT uk_enrolment_student_course UNIQUE (student_id, course_id),
    CONSTRAINT fk_enr_student FOREIGN KEY (student_id) REFERENCES students(student_id)   ON DELETE CASCADE,
    CONSTRAINT fk_enr_course  FOREIGN KEY (course_id)  REFERENCES courses(course_id)    ON DELETE CASCADE
);

-- 8. sessions (a scheduled class meeting) -----------------------------------
-- LIMITATION enforced here by CHECK:
--   an in-person session MUST name a partner school.
CREATE TABLE sessions (
    session_id       SERIAL PRIMARY KEY,
    course_id        INTEGER     NOT NULL,
    coach_id         INTEGER     NOT NULL,
    school_id        INTEGER,                                -- NULL for online sessions
    starts_at        TIMESTAMPTZ NOT NULL,
    duration_minutes INTEGER     NOT NULL CHECK (duration_minutes > 0),
    capacity         INTEGER     NOT NULL CHECK (capacity > 0),   -- LIMITATION: max students
    mode             TEXT        NOT NULL CHECK (mode IN ('online','in-person')),
    CONSTRAINT chk_inperson_school CHECK (mode = 'online' OR school_id IS NOT NULL),
    CONSTRAINT fk_sessions_course FOREIGN KEY (course_id) REFERENCES courses(course_id),
    CONSTRAINT fk_sessions_coach   FOREIGN KEY (coach_id)  REFERENCES coaches(coach_id),
    CONSTRAINT fk_sessions_school FOREIGN KEY (school_id) REFERENCES schools(school_id)
);

-- 9. attendance -------------------------------------------------------------
-- LIMITATION (enforced by trigger, see triggers.sql):
--   (a) a session's capacity cannot be exceeded;
--   (b) a student can only be booked into a session for a course they are
--       enrolled in.
CREATE TABLE attendance (
    attendance_id   SERIAL PRIMARY KEY,
    session_id      INTEGER     NOT NULL,
    student_id      INTEGER     NOT NULL,
    attended_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status          TEXT        NOT NULL DEFAULT 'present'
                    CHECK (status IN ('present','absent','late')),
    CONSTRAINT uk_attendance_session_student UNIQUE (session_id, student_id),
    CONSTRAINT fk_att_session FOREIGN KEY (session_id) REFERENCES sessions(session_id) ON DELETE CASCADE,
    CONSTRAINT fk_att_student FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
);

-- 10. billing_plans (one fee per course per currency) ----------------------
CREATE TABLE billing_plans (
    plan_id          SERIAL PRIMARY KEY,
    course_id        INTEGER     NOT NULL,
    currency_code    CHAR(3)     NOT NULL,
    monthly_fee      NUMERIC(12,2) NOT NULL CHECK (monthly_fee >= 0),
    active_from      DATE        NOT NULL DEFAULT CURRENT_DATE,
    active_to        DATE,                                  -- NULL = still active
    CONSTRAINT uk_plan_course_currency UNIQUE (course_id, currency_code, active_from),
    CONSTRAINT fk_plan_course   FOREIGN KEY (course_id)     REFERENCES courses(course_id),
    CONSTRAINT fk_plan_currency FOREIGN KEY (currency_code) REFERENCES currencies(currency_code)
);

-- 11. invoices (monthly bill per student per course) -----------------------
CREATE TABLE invoices (
    invoice_id       SERIAL PRIMARY KEY,
    student_id       INTEGER     NOT NULL,
    course_id        INTEGER     NOT NULL,
    currency_code    CHAR(3)     NOT NULL,                  -- denormalised from billing plan
    billing_month    DATE        NOT NULL,                  -- first day of the month
    amount_due       NUMERIC(12,2) NOT NULL CHECK (amount_due >= 0),
    due_date         DATE        NOT NULL,
    status           TEXT        NOT NULL DEFAULT 'unpaid'
                     CHECK (status IN ('unpaid','paid','overdue','cancelled')),
    CONSTRAINT uk_invoice UNIQUE (student_id, course_id, billing_month),
    CONSTRAINT uk_invoice_currency UNIQUE (invoice_id, currency_code),   -- target of payments' composite FK
    CONSTRAINT fk_inv_student FOREIGN KEY (student_id)     REFERENCES students(student_id),
    CONSTRAINT fk_inv_course  FOREIGN KEY (course_id)      REFERENCES courses(course_id),
    CONSTRAINT fk_inv_currency FOREIGN KEY (currency_code) REFERENCES currencies(currency_code)
);

-- 12. payments --------------------------------------------------------------
-- LIMITATION enforced by composite FK:
--   the payment currency MUST match the invoice currency.
CREATE TABLE payments (
    payment_id       SERIAL PRIMARY KEY,
    invoice_id       INTEGER     NOT NULL,
    student_id       INTEGER     NOT NULL,
    amount           NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    currency_code    CHAR(3)     NOT NULL,                  -- must equal invoice currency
    paid_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    method           TEXT        NOT NULL CHECK (method IN ('bank_transfer','card','mobile_money','paypal')),
    -- composite FK guarantees currency matches the invoice.
    CONSTRAINT fk_pay_invoice_currency
        FOREIGN KEY (invoice_id, currency_code)
        REFERENCES invoices(invoice_id, currency_code),
    CONSTRAINT fk_pay_student FOREIGN KEY (student_id) REFERENCES students(student_id)
);

-- 13. social_posts (lightweight reference; full metrics live in MongoDB P4) -
CREATE TABLE social_posts (
    post_id          SERIAL PRIMARY KEY,
    platform         TEXT        NOT NULL CHECK (platform IN ('instagram','tiktok','youtube')),
    external_id      TEXT,                                  -- id from the platform
    posted_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    caption          TEXT,
    external_url     TEXT,
    CONSTRAINT uk_post_platform_external UNIQUE (platform, external_id)
);

-- 14. leads (marketing funnel: lead → converted student) -------------------
CREATE TABLE leads (
    lead_id           SERIAL PRIMARY KEY,
    post_id           INTEGER,                               -- nullable: walked-in / referral
    platform          TEXT        NOT NULL
                       CHECK (platform IN ('instagram','tiktok','youtube','referral','walk-in','website')),
    contact_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    converted_student_id INTEGER,                            -- NULL until converted
    status            TEXT        NOT NULL DEFAULT 'new'
                       CHECK (status IN ('new','contacted','converted','lost')),
    CONSTRAINT fk_leads_post    FOREIGN KEY (post_id)             REFERENCES social_posts(post_id),
    CONSTRAINT fk_leads_student FOREIGN KEY (converted_student_id) REFERENCES students(student_id)
);

-- Helpful indexes for queries that P2 will need later -----------------------
CREATE INDEX idx_attendance_session   ON attendance(session_id);
CREATE INDEX idx_attendance_student   ON attendance(student_id);
CREATE INDEX idx_sessions_course      ON sessions(course_id);
CREATE INDEX idx_sessions_startsat    ON sessions(starts_at);
CREATE INDEX idx_payments_paidat      ON payments(paid_at);
CREATE INDEX idx_payments_currency    ON payments(currency_code);
CREATE INDEX idx_invoices_status      ON invoices(status);
CREATE INDEX idx_invoices_billing     ON invoices(billing_month);
CREATE INDEX idx_enrolments_student   ON course_enrolments(student_id);
CREATE INDEX idx_enrolments_course   ON course_enrolments(course_id);
CREATE INDEX idx_leads_status         ON leads(status);

-- ============================================================================
--  End of baseline schema — 14 tables.
--  (countries, currencies, schools, coaches, students, courses,
--   course_enrolments, sessions, attendance, billing_plans, invoices,
--   payments, social_posts, leads)
-- ============================================================================
