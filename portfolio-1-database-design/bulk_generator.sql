-- ============================================================================
--  bulk_generator.sql — generates the large data volumes for P1.
--  Requires: schema.sql + triggers.sql + seed_data.sql already loaded.
--
--  Output volumes:
--    ~1,500 extra students  (Nigerian / Canadian / US names)
--    ~10,000 sessions       (2 years of weekly classes × multiple courses)
--    ~55,000 attendance rows (>= 50k requirement; triggers skipped via direct INSERT)
--    ~32,000 invoices       (enrolments × months × 2 years)
--    ~28,000 payments       (>= 20k requirement, across NGN/CAD/USD)
--    ~6,000  leads
--
--  All dates are relative to CURRENT_DATE so the data never expires.
--  WARNING: this script DISABLES the capacity & enrolment triggers during
--  bulk load and re-enables them afterwards. The triggers are tested
--  separately by constraint_tests.sql.
-- ============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- Pause the two P1 triggers for bulk load (still tested separately) ---------
ALTER TABLE attendance DISABLE TRIGGER trg_check_capacity;
ALTER TABLE attendance DISABLE TRIGGER trg_check_enrolment;

-- ============================================================================
-- 1) 1,500 extra students with realistic Nigerian / Canadian / US names
-- ============================================================================
INSERT INTO students (first_name, last_name, email, country_id, dob, signup_at, guardian_name, guardian_phone)
SELECT
    first_name,
    last_name,
    lower(left(first_name,1)) || '.' || lower(regexp_replace(last_name, '[^A-Za-z]', '', 'g'))
        || n || '@example.com',
    country_id,
    CURRENT_DATE - (8 + floor(random()*8))::int * INTERVAL '1 year',
    NOW() - (random() * INTERVAL '2 years'),
    first_name || ' guardian',
    CASE country_id
        WHEN (SELECT country_id FROM countries WHERE iso_code='NG') THEN '+234803' || lpad((floor(random()*9999999))::text, 7, '0')
        WHEN (SELECT country_id FROM countries WHERE iso_code='CA') THEN '+1416555' || lpad((floor(random()*9999))::text, 4, '0')
        WHEN (SELECT country_id FROM countries WHERE iso_code='US') THEN '+1212555' || lpad((floor(random()*9999))::text, 4, '0')
    END
FROM (
    SELECT
        CASE ng_country
            WHEN 'NG' THEN (ARRAY[
                'Aisha','Chidi','Emeka','Zainab','Tunde','Ngozi','Ibrahim','Chioma','Olu','Adaeze',
                'Bisi','Dotun','Femi','Hauwa','Jide','Kemi','Lola','Mide','Nneka','Obinna',
                'Petra','Seyi','Tosin','Uche','Yetunde','Yakubu','Bola','Chika','Dami','Eze'])[1 + (n % 30)]
            WHEN 'CA' THEN (ARRAY[
                'Liam','Olivia','Noah','Emma','Lucas','Mia','Jack','Sophia','Leo','Charlotte',
                'Benjamin','Amelia','Henry','Ella','Jackson','Ava','Ethan','Mia','Oliver','Aria',
                'Logan','Lily','Caleb','Zoe','Nathan','Stella','Wyatt','Ruby','Hudson','Isla'])[1 + (n % 30)]
            WHEN 'US' THEN (ARRAY[
                'Ethan','Sophia','Mason','Isabella','Logan','Mia','James','Amelia','Aiden','Harper',
                'Jacob','Evelyn','Michael','Abigail','Daniel','Emily','Henry','Ella','Sebastian','Grace',
                'Aria','Chloe','David','Camila','Carter','Penelope','Jayden','Layla','Julian','Riley'])[1 + (n % 30)]
        END AS first_name,
        CASE ng_country
            WHEN 'NG' THEN (ARRAY[
                'Adesanya','Bello','Eze','Mohammed','Okafor','Okoro','Nwosu','Yusuf','Adeyemi','Balogun',
                'Olawale','Sanusi','Oladipo','Jegede','Lawal','Olatunji','Adebowale','Mbadinuju','Eze','Okeke',
                'Anozie','Uche','Oyelowo','Ayodele','Dauda','Olawoyin','Bashir','Idris','Ojo','Nnamdi'])[1 + (n % 30)]
            WHEN 'CA' THEN (ARRAY[
                'Smith','Brown','Wilson','Taylor','Anderson','Martin','Thompson','White','Harris','Clark',
                'Robinson','Lewis','Walker','Young','Hall','Allen','King','Wright','Lopez','Hill',
                'Green','Adams','Baker','Nelson','Carter','Mitchell','Roberts','Turner','Phillips','Parker'])[1 + (n % 30)]
            WHEN 'US' THEN (ARRAY[
                'Johnson','Williams','Jones','Davis','Garcia','Rodriguez','Martinez','Hernandez','Lopez','Gonzalez',
                'Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin','Lee','Perez','Thompson',
                'White','Harris','Sanchez','Clark','Ramirez','Lewis','Robinson','Walker','Young','Allen'])[1 + (n % 30)]
        END AS last_name,
        CASE ng_country
            WHEN 'NG' THEN (SELECT country_id FROM countries WHERE iso_code='NG')
            WHEN 'CA' THEN (SELECT country_id FROM countries WHERE iso_code='CA')
            WHEN 'US' THEN (SELECT country_id FROM countries WHERE iso_code='US')
        END AS country_id,
        n
    FROM generate_series(1, 1500) AS n
    CROSS JOIN LATERAL (
        SELECT CASE
            WHEN n % 100 < 55 THEN 'NG'      -- 55% Nigerian students
            WHEN n % 100 < 80 THEN 'CA'      -- 25% Canadian
            ELSE                  'US'      -- 20% USA
        END AS ng_country
    ) cc
) s
ON CONFLICT (email) DO NOTHING;

-- ============================================================================
-- 2) Enrolments: each new student in 1–3 courses
-- ============================================================================
INSERT INTO course_enrolments (student_id, course_id, enrolled_at, status)
SELECT s.student_id,
       c.course_id,
       NOW() - (random() * INTERVAL '2 years'),
       CASE WHEN random() < 0.85 THEN 'active' ELSE 'completed' END
  FROM students s
  CROSS JOIN LATERAL generate_series(1, 1 + (s.student_id % 3)) AS k      -- 1 to 3 courses per student (depends on the row, so it is not evaluated once)
  CROSS JOIN LATERAL (
    SELECT cc.course_id FROM courses cc ORDER BY md5(s.student_id::text || k::text || cc.course_id::text) LIMIT 1
  ) c
 WHERE s.student_id > 12    -- skip the seed students already enrolled
   AND NOT EXISTS (
       SELECT 1 FROM course_enrolments ce
        WHERE ce.student_id = s.student_id AND ce.course_id = c.course_id
   )
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 3) Sessions: 2 years × weekly per course × 1-2 sessions = ~10,000 sessions
-- ============================================================================
INSERT INTO sessions (course_id, coach_id, school_id, starts_at, duration_minutes, capacity, mode)
SELECT co.course_id,
       -- correlated on course/day/k so each session gets its own coach and school
       (SELECT coach_id FROM coaches ORDER BY md5(co.course_id::text || g.d::text || k::text || coaches.coach_id::text) LIMIT 1),
       CASE WHEN co.mode IN ('in-person','hybrid')
            THEN (SELECT school_id FROM schools ORDER BY md5(g.d::text || co.course_id::text || k::text || schools.school_id::text) LIMIT 1)
            ELSE NULL END,
       g.d + (8 + floor(random()*10))::int * INTERVAL '1 hour',
       60, 8,
       CASE WHEN co.mode = 'hybrid' THEN 'online' ELSE co.mode END
  FROM courses co
  CROSS JOIN LATERAL generate_series(
        CURRENT_DATE - INTERVAL '2 years',
        CURRENT_DATE + INTERVAL '14 days',          -- history plus the next 14 days (open for booking)
        INTERVAL '1 day') AS g(d)
  CROSS JOIN LATERAL generate_series(1, 1 + (extract(doy FROM g.d)::int + co.course_id) % 2) AS k;

-- ============================================================================
-- 4) Attendance: 1–8 enrolled students per session -> ~55k+ rows
--    (triggers disabled above so direct INSERT is fast)
-- ============================================================================
INSERT INTO attendance (session_id, student_id, attended_at, status)
SELECT s.session_id,
       pick.student_id,
       s.starts_at + (floor(random()*5))::int * INTERVAL '1 minute',
       CASE WHEN random() < 0.85 THEN 'present'
            WHEN random() < 0.50 THEN 'late'
            ELSE 'absent' END
  FROM sessions s
  CROSS JOIN LATERAL (
        -- 4 to 8 students per session (never above capacity 8), only students
        -- already enrolled in that course on the session date.
        SELECT ce.student_id
          FROM course_enrolments ce
         WHERE ce.course_id = s.course_id
           AND ce.status IN ('active','completed')
           AND ce.enrolled_at <= s.starts_at
         ORDER BY md5(s.session_id::text || ce.student_id::text)
         LIMIT 4 + (s.session_id % 5)
  ) pick
 WHERE s.starts_at < NOW();                  -- future sessions stay empty (open for booking)

-- ============================================================================
-- 5) Invoices: one per enrolment × month × 2 years -> ~32k invoices
-- ============================================================================
INSERT INTO invoices (student_id, course_id, currency_code, billing_month, amount_due, due_date, status)
SELECT ce.student_id,
       ce.course_id,
       cur.currency_code,
       date_trunc('month', CURRENT_DATE - (m * INTERVAL '1 month'))::date,
       bp.monthly_fee,
       (date_trunc('month', CURRENT_DATE - (m * INTERVAL '1 month')) + INTERVAL '10 days')::date,
       CASE WHEN random() < 0.88 THEN 'paid' ELSE 'unpaid' END
  FROM course_enrolments ce
  JOIN students   st ON st.student_id = ce.student_id
  JOIN countries   co ON co.country_id  = st.country_id
  JOIN currencies   cur ON cur.currency_code = co.default_currency_code
  JOIN billing_plans bp ON bp.course_id = ce.course_id AND bp.currency_code = cur.currency_code
  CROSS JOIN LATERAL generate_series(0, 23) AS m
 WHERE ce.enrolled_at <= CURRENT_DATE - (m * INTERVAL '1 month')
   AND ce.status IN ('active','completed')
ON CONFLICT DO NOTHING;

-- Mark overdue invoices (unpaid and past due_date)
UPDATE invoices SET status = 'overdue'
 WHERE status = 'unpaid' AND due_date < CURRENT_DATE;

-- ============================================================================
-- 6) Payments: ~88% of paid invoices, in the invoice's currency -> ~28k
-- ============================================================================
INSERT INTO payments (invoice_id, student_id, amount, currency_code, paid_at, method)
SELECT i.invoice_id,
       i.student_id,
       i.amount_due + (CASE WHEN random() < 0.05 THEN
            CASE i.currency_code WHEN 'NGN' THEN 1000 WHEN 'CAD' THEN 2 WHEN 'USD' THEN 1 END
            ELSE 0 END),                                -- small over-payments
       i.currency_code,
       i.billing_month + (5 + floor(random()*10))::int * INTERVAL '1 day',
       (ARRAY['bank_transfer','card','mobile_money','paypal'])[1 + floor(random()*4)::int]
  FROM invoices i
 WHERE i.status = 'paid'
   AND random() < 0.92
ON CONFLICT DO NOTHING;

-- Reconcile invoices to 'paid' where a payment now exists
UPDATE invoices i SET status = 'paid'
 WHERE i.status = 'unpaid'
   AND EXISTS (SELECT 1 FROM payments p WHERE p.invoice_id = i.invoice_id);

-- ============================================================================
-- 7) Leads: ~6,000 leads across platforms, ~40% converted
-- ============================================================================
INSERT INTO leads (post_id, platform, contact_at, converted_student_id, status)
SELECT sp.post_id,
       sp.platform,
       sp.posted_at + (random() * INTERVAL '6 hours'),
       CASE WHEN random() < 0.40
            THEN (SELECT st.student_id FROM students st ORDER BY md5(sp.post_id::text || k::text || st.student_id::text) LIMIT 1)
            ELSE NULL END,
       CASE WHEN random() < 0.40 THEN 'converted'
            WHEN random() < 0.70 THEN 'contacted'
            ELSE 'new' END
  FROM social_posts sp
  CROSS JOIN LATERAL generate_series(1, 1 + (sp.post_id % 3)) AS k
 WHERE random() < 0.8
ON CONFLICT DO NOTHING;

-- Re-enable triggers (we want the rules active again for normal use) --------
ALTER TABLE attendance ENABLE TRIGGER trg_check_capacity;
ALTER TABLE attendance ENABLE TRIGGER trg_check_enrolment;

COMMIT;

-- Quick counts (for the README screenshot) ----------------------------------
\echo '==== Bulk data summary ===='
SELECT 'students' AS table_name, COUNT(*)::text FROM students
UNION ALL SELECT 'coaches', COUNT(*)::text FROM coaches
UNION ALL SELECT 'courses', COUNT(*)::text FROM courses
UNION ALL SELECT 'course_enrolments', COUNT(*)::text FROM course_enrolments
UNION ALL SELECT 'sessions', COUNT(*)::text FROM sessions
UNION ALL SELECT 'attendance', COUNT(*)::text FROM attendance
UNION ALL SELECT 'invoices', COUNT(*)::text FROM invoices
UNION ALL SELECT 'payments', COUNT(*)::text FROM payments
UNION ALL SELECT 'social_posts', COUNT(*)::text FROM social_posts
UNION ALL SELECT 'leads', COUNT(*)::text FROM leads
UNION ALL SELECT 'payments by currency',
       (SELECT COUNT(*)::text FROM payments WHERE currency_code='NGN') ||
       ' NGN / ' ||
       (SELECT COUNT(*)::text FROM payments WHERE currency_code='CAD') ||
       ' CAD / ' ||
       (SELECT COUNT(*)::text FROM payments WHERE currency_code='USD') || ' USD'
ORDER BY 1;
