# ER Diagram — Afordchess Academy (14 tables, matches `schema.sql`)

```mermaid
erDiagram
    CURRENCIES ||--o{ COUNTRIES : "default currency of"
    COUNTRIES ||--o{ SCHOOLS   : "located in"
    COUNTRIES ||--o{ COACHES   : "based in"
    COUNTRIES ||--o{ STUDENTS  : "lives in"

    SCHOOLS   ||--o{ SESSIONS  : "host in-person classes"

    COACHES   ||--o{ SESSIONS  : "teaches"

    STUDENTS ||--o{ COURSE_ENROLMENTS : "enrols"
    COURSES  ||--o{ COURSE_ENROLMENTS : "has"

    COURSES  ||--o{ SESSIONS         : "scheduled as"
    COURSES  ||--o{ BILLING_PLANS    : "priced by"
    COURSES  ||--o{ INVOICES         : "billed via"

    SESSIONS ||--o{ ATTENDANCE : "records who came"
    STUDENTS ||--o{ ATTENDANCE : "attended"

    CURRENCIES ||--o{ BILLING_PLANS : "denominated in"
    CURRENCIES ||--o{ INVOICES      : "denominated in"
    CURRENCIES ||--o{ PAYMENTS      : "paid in"

    STUDENTS ||--o{ INVOICES : "owes"
    STUDENTS ||--o{ PAYMENTS : "makes"

    INVOICES ||--o{ PAYMENTS : "settles"
    %% composite FK (invoice_id, currency_code) enforces currency match

    SOCIAL_POSTS ||--o{ LEADS : "generates"
    STUDENTS     ||--o{ LEADS : "converted from"

    CURRENCIES {
        CHAR(3)  currency_code PK
        TEXT     name
        TEXT     symbol
        NUMERIC  usd_rate
    }
    COUNTRIES {
        INTEGER country_id PK
        TEXT    name
        CHAR(2) iso_code UK
        CHAR(3) default_currency_code FK
        TEXT    phone_prefix
    }
    SCHOOLS {
        INTEGER school_id PK
        TEXT    name
        INTEGER country_id FK
        TEXT    address
        TEXT    contact_email
    }
    COACHES {
        INTEGER coach_id PK
        TEXT    first_name
        TEXT    last_name
        TEXT    email UK
        INTEGER country_id FK
        TEXT    phone
        DATE    hired_at
        TEXT    specialty
    }
    STUDENTS {
        INTEGER student_id PK
        TEXT    first_name
        TEXT    last_name
        TEXT    email UK
        INTEGER country_id FK
        DATE    dob
        TIMESTAMPTZ signup_at
        TEXT    guardian_name
        TEXT    guardian_phone
    }
    COURSES {
        INTEGER course_id PK
        TEXT    name
        TEXT    description
        TEXT    level
        TEXT    mode
        INTEGER duration_weeks
    }
    COURSE_ENROLMENTS {
        INTEGER enrolment_id PK
        INTEGER student_id FK
        INTEGER course_id FK
        TIMESTAMPTZ enrolled_at
        TEXT    status
    }
    SESSIONS {
        INTEGER session_id PK
        INTEGER course_id FK
        INTEGER coach_id FK
        INTEGER school_id FK
        TIMESTAMPTZ starts_at
        INTEGER duration_minutes
        INTEGER capacity
        TEXT    mode
    }
    ATTENDANCE {
        INTEGER attendance_id PK
        INTEGER session_id FK
        INTEGER student_id FK
        TIMESTAMPTZ attended_at
        TEXT    status
    }
    BILLING_PLANS {
        INTEGER plan_id PK
        INTEGER course_id FK
        CHAR(3) currency_code FK
        NUMERIC monthly_fee
        DATE    active_from
        DATE    active_to
    }
    INVOICES {
        INTEGER invoice_id PK
        INTEGER student_id FK
        INTEGER course_id FK
        CHAR(3) currency_code FK
        DATE    billing_month
        NUMERIC amount_due
        DATE    due_date
        TEXT    status
    }
    PAYMENTS {
        INTEGER payment_id PK
        INTEGER invoice_id FK
        INTEGER student_id FK
        NUMERIC amount
        CHAR(3) currency_code FK
        TIMESTAMPTZ paid_at
        TEXT    method
    }
    SOCIAL_POSTS {
        INTEGER post_id PK
        TEXT    platform
        TEXT    external_id
        TIMESTAMPTZ posted_at
        TEXT    caption
        TEXT    external_url
    }
    LEADS {
        INTEGER lead_id PK
        INTEGER post_id FK
        TEXT    platform
        TIMESTAMPTZ contact_at
        INTEGER converted_student_id FK
        TEXT    status
    }
```

## Limitations captured by the schema (from P1 README)

| Limitation | Enforced by |
|---|---|
| A student's email is unique | `students.email UNIQUE` (and `coaches.email UNIQUE`) |
| An in-person session must name a partner school | `sessions.chk_inperson_school` CHECK constraint |
| A session's capacity cannot be exceeded | Trigger `trg_check_capacity` (see `triggers.sql`) |
| A student can only be booked into a session for a course they are enrolled in | Trigger `trg_check_enrolment` (see `triggers.sql`) |
| A payment currency must match the invoice currency | Composite FK on `payments(invoice_id, currency_code)` → `invoices(invoice_id, currency_code)` |
