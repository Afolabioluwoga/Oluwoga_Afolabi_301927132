-- ============================================================================
--  seed_data.sql — small, hand-written reference data for Afordchess Academy.
--  Run AFTER schema.sql + triggers.sql.
--  The bulk generator (bulk_generator.sql) adds the large volumes of
--  attendance / payments / leads.
--  All dates are relative to CURRENT_DATE so the seed never expires.
-- ============================================================================

BEGIN;

-- Currencies (rates are example snapshots, not financial advice) -------------
INSERT INTO currencies (currency_code, name, symbol, usd_rate) VALUES
    ('NGN', 'Nigerian Naira',     '₦',   0.000670),
    ('CAD', 'Canadian Dollar',    'C$',  0.730000),
    ('USD', 'US Dollar',          '$',   1.000000)
ON CONFLICT (currency_code) DO NOTHING;

-- Countries ------------------------------------------------------------------
INSERT INTO countries (name, iso_code, default_currency_code, phone_prefix) VALUES
    ('Nigeria', 'NG', 'NGN', '+234'),
    ('Canada',  'CA', 'CAD', '+1'),
    ('United States', 'US', 'USD', '+1')
ON CONFLICT (iso_code) DO NOTHING;

-- Schools (partner schools for in-person classes) ---------------------------
-- 2 in Nigeria, 1 in Canada, 1 in the USA.
INSERT INTO schools (name, country_id, address, contact_email) VALUES
    ('Greensprings School',      (SELECT country_id FROM countries WHERE iso_code='NG'),
     'Lekki Phase 1, Lagos, Nigeria', 'chess@greensprings.edu.ng'),
    ('Day Waterman College',     (SELECT country_id FROM countries WHERE iso_code='NG'),
     'Abeokuta, Ogun State, Nigeria', 'chess@dwc.edu.ng'),
    ('Upper Canada College',     (SELECT country_id FROM countries WHERE iso_code='CA'),
     '200 Lonsdale Rd, Toronto, ON, Canada', 'chess@ucc.on.ca'),
    ('Phillips Exeter Academy',  (SELECT country_id FROM countries WHERE iso_code='US'),
     '20 Main St, Exeter, NH, USA', 'chess@exeter.edu')
ON CONFLICT DO NOTHING;

-- Coaches (invented names, mixed nationalities) -----------------------------
INSERT INTO coaches (first_name, last_name, email, country_id, phone, hired_at, specialty) VALUES
    ('Tunde',   'Adesanya', 'tunde.adesanya@afordchess.example',
        (SELECT country_id FROM countries WHERE iso_code='NG'), '+2348031110001',
        CURRENT_DATE - INTERVAL '3 years', 'tactics'),
    ('Chidi',   'Eze',      'chidi.eze@afordchess.example',
        (SELECT country_id FROM countries WHERE iso_code='NG'), '+2348031110002',
        CURRENT_DATE - INTERVAL '2 years', 'endgames'),
    ('Marie',   'Tremblay', 'marie.tremblay@afordchess.example',
        (SELECT country_id FROM countries WHERE iso_code='CA'), '+14165550011',
        CURRENT_DATE - INTERVAL '18 months', 'openings'),
    ('David',   'Okafor',   'david.okafor@afordchess.example',
        (SELECT country_id FROM countries WHERE iso_code='NG'), '+2348031110003',
        CURRENT_DATE - INTERVAL '1 year', 'positional play'),
    ('Sarah',   'Mitchell', 'sarah.mitchell@afordchess.example',
        (SELECT country_id FROM countries WHERE iso_code='CA'), '+14165550012',
        CURRENT_DATE - INTERVAL '2 years', 'blitz'),
    ('Michael', 'Johnson',  'michael.johnson@afordchess.example',
        (SELECT country_id FROM countries WHERE iso_code='US'), '+12125550021',
        CURRENT_DATE - INTERVAL '14 months', 'tournament prep')
ON CONFLICT (email) DO NOTHING;

-- Students (12 seed students — bulk generator adds more if needed) ---------
INSERT INTO students (first_name, last_name, email, country_id, dob, signup_at, guardian_name, guardian_phone) VALUES
    ('Aisha',   'Bello',     'aisha.bello@example.com',     (SELECT country_id FROM countries WHERE iso_code='NG'), CURRENT_DATE - INTERVAL '11 years',  NOW() - INTERVAL '13 months', 'Fatima Bello',   '+2348032220001'),
    ('Emeka',   'Nwosu',     'emeka.nwosu@example.com',     (SELECT country_id FROM countries WHERE iso_code='NG'), CURRENT_DATE - INTERVAL '10 years',  NOW() - INTERVAL '8 months',  'Grace Nwosu',    '+2348032220002'),
    ('Zainab',  'Mohammed',  'zainab.mohammed@example.com',  (SELECT country_id FROM countries WHERE iso_code='NG'), CURRENT_DATE - INTERVAL '9 years',   NOW() - INTERVAL '6 months',  'Ibrahim Mohammed','+2348032220003'),
    ('Liam',    'Smith',     'liam.smith@example.com',       (SELECT country_id FROM countries WHERE iso_code='CA'), CURRENT_DATE - INTERVAL '12 years',  NOW() - INTERVAL '11 months',  'Jennifer Smith', '+14165550031'),
    ('Olivia',  'Brown',     'olivia.brown@example.com',      (SELECT country_id FROM countries WHERE iso_code='CA'), CURRENT_DATE - INTERVAL '11 years',  NOW() - INTERVAL '4 months',  'Robert Brown',   '+14165550032'),
    ('Noah',    'Wilson',    'noah.wilson@example.com',       (SELECT country_id FROM countries WHERE iso_code='US'), CURRENT_DATE - INTERVAL '13 years',  NOW() - INTERVAL '15 months',  'Karen Wilson',   '+12125550041'),
    ('Emma',    'Davis',     'emma.davis@example.com',        (SELECT country_id FROM countries WHERE iso_code='US'), CURRENT_DATE - INTERVAL '10 years',  NOW() - INTERVAL '7 months',  'James Davis',    '+12125550042'),
    ('Chioma',  'Okoro',     'chioma.okoro@example.com',       (SELECT country_id FROM countries WHERE iso_code='NG'), CURRENT_DATE - INTERVAL '14 years',  NOW() - INTERVAL '20 months',  'Ngozi Okoro',    '+2348032220004'),
    ('Ethan',   'Martinez',  'ethan.martinez@example.com',     (SELECT country_id FROM countries WHERE iso_code='US'), CURRENT_DATE - INTERVAL '9 years',   NOW() - INTERVAL '5 months',  'Sofia Martinez', '+12125550043'),
    ('Sophia',  'Lee',       'sophia.lee@example.com',         (SELECT country_id FROM countries WHERE iso_code='CA'), CURRENT_DATE - INTERVAL '8 years',   NOW() - INTERVAL '3 months',  'Daniel Lee',     '+14165550033'),
    ('Daniel',  'Kim',       'daniel.kim@example.com',         (SELECT country_id FROM countries WHERE iso_code='US'), CURRENT_DATE - INTERVAL '11 years',  NOW() - INTERVAL '9 months',  'Helen Kim',      '+12125550044'),
    ('Fatima',  'Yusuf',     'fatima.yusuf@example.com',        (SELECT country_id FROM countries WHERE iso_code='NG'), CURRENT_DATE - INTERVAL '13 years',  NOW() - INTERVAL '17 months',  'Abdullah Yusuf', '+2348032220005')
ON CONFLICT (email) DO NOTHING;

-- Courses (real-looking chess course names) ---------------------------------
INSERT INTO courses (name, description, level, mode, duration_weeks) VALUES
    ('Chess Basics for Beginners',        'How the pieces move, check and checkmate.', 'beginner',     'online',    8),
    ('Tactics Bootcamp',                  'Pins, forks, skewers and discovered attacks.', 'intermediate', 'online',   10),
    ('Endgame Mastery',                    'King-and-pawn, rook endgames, Lucena and Philidor.', 'advanced', 'online', 12),
    ('Opening Repertoire for White',      'Italian, Ruy Lopez and Queen''s Gambit lines.', 'intermediate', 'hybrid', 10),
    ('Kids Chess Club (U-12)',            'Fun, age-appropriate lessons for under-12s.', 'all-levels',   'in-person', 16),
    ('Blitz & Bullet Speed Training',     '3-minute and 1-minute chess strategy.',     'all-levels',   'online',    6),
    ('Tournament Preparation Camp',       'Game analysis, time management, nerves.',    'advanced',     'in-person', 8),
    ('Positional Play & Strategy',        'Pawn structures, outposts, prophylaxis.',   'advanced',     'online',    12),
    ('Sicilian Defense Deep Dive',        'Najdorf, Dragon and Sveshnikov variations.','intermediate', 'online',    10),
    ('Scholastic Chess (Partner Schools)','Curriculum delivered in partner schools.',  'beginner',     'in-person', 14)
ON CONFLICT DO NOTHING;

-- Enrolments: each seed student in 1–2 courses ------------------------------
INSERT INTO course_enrolments (student_id, course_id, enrolled_at, status)
SELECT s.student_id, c.course_id, NOW() - (random() * INTERVAL '12 months'),
       CASE WHEN random() < 0.85 THEN 'active' ELSE 'completed' END
  FROM students s
  CROSS JOIN LATERAL (
    SELECT course_id FROM courses
     WHERE course_id IN (1, 2, 3, 4, 5)
     ORDER BY random() LIMIT 1 + floor(random()*2)
  ) c
ON CONFLICT DO NOTHING;

-- Sessions (one per course per week for the last 2 months, ~8 per course) ---
-- Capacity 8 students per session (the trigger will reject the 9th).
INSERT INTO sessions (course_id, coach_id, school_id, starts_at, duration_minutes, capacity, mode)
SELECT c.course_id,
       (SELECT coach_id FROM coaches ORDER BY coach_id LIMIT 1 OFFSET floor(random()*6)::int),
       CASE WHEN co.mode IN ('in-person','hybrid')
            THEN (SELECT school_id FROM schools ORDER BY random() LIMIT 1)
            ELSE NULL END,
       date_trunc('week', CURRENT_DATE) - (w * INTERVAL '1 week')
            + (8 + floor(random()*8))::int * INTERVAL '1 hour',
       60, 8,
       CASE WHEN co.mode = 'hybrid' THEN 'online' ELSE co.mode END
  FROM courses co
  CROSS JOIN LATERAL generate_series(0, 7) AS w
  CROSS JOIN LATERAL (SELECT co.course_id AS course_id) c
ON CONFLICT DO NOTHING;

-- Billing plans (one per course per currency) --------------------------------
INSERT INTO billing_plans (course_id, currency_code, monthly_fee, active_from)
SELECT c.course_id, cur.currency_code,
       CASE cur.currency_code
            WHEN 'NGN' THEN 15000 + (c.course_id * 1500)
            WHEN 'CAD' THEN 60    + (c.course_id * 5)
            WHEN 'USD' THEN 45    + (c.course_id * 4)
       END,
       CURRENT_DATE - INTERVAL '2 years'
  FROM courses c
  CROSS JOIN currencies cur
ON CONFLICT DO NOTHING;

-- Invoices: one per enrolled student per month for the last 6 months --------
INSERT INTO invoices (student_id, course_id, currency_code, billing_month, amount_due, due_date, status)
SELECT ce.student_id, ce.course_id,
       cur.currency_code,
       date_trunc('month', CURRENT_DATE - (m * INTERVAL '1 month'))::date,
       bp.monthly_fee,
       (date_trunc('month', CURRENT_DATE - (m * INTERVAL '1 month')) + INTERVAL '10 days')::date,
       CASE WHEN random() < 0.85 THEN 'paid' ELSE 'unpaid' END
  FROM course_enrolments ce
  JOIN countries   co ON co.country_id = (SELECT country_id FROM students s WHERE s.student_id = ce.student_id)
  JOIN currencies   cur ON cur.currency_code = co.default_currency_code
  JOIN billing_plans bp ON bp.course_id = ce.course_id AND bp.currency_code = cur.currency_code
  CROSS JOIN LATERAL generate_series(0, 5) AS m
ON CONFLICT DO NOTHING;

-- Social posts (one per platform per week for the last 12 weeks) -----------
INSERT INTO social_posts (platform, external_id, posted_at, caption, external_url)
SELECT platform,
       platform || '-' || to_char(d, 'YYYYMMDD') || '-' || n,
       d + (n * INTERVAL '2 hours'),
       CASE platform
            WHEN 'instagram' THEN 'Reel: ' || (ARRAY['5-mate puzzle','Blitz game recap','Coach tip'])[1 + (n % 3)]
            WHEN 'tiktok'    THEN 'TikTok: ' || (ARRAY['60s tactic','Duets welcome','Sound on'])[1 + (n % 3)]
            WHEN 'youtube'   THEN 'YouTube: ' || (ARRAY['Endgame lesson','Opening breakdown','Game review'])[1 + (n % 3)]
       END,
       'https://' || platform || '.example/afordchess/' || to_char(d, 'YYYYMMDD') || '/' || n
  FROM (VALUES ('instagram'), ('tiktok'), ('youtube')) AS p(platform)
  CROSS JOIN LATERAL generate_series(CURRENT_DATE - INTERVAL '12 weeks',
                                     CURRENT_DATE, INTERVAL '1 week') AS t(d)
  CROSS JOIN LATERAL generate_series(1, 2) AS n
ON CONFLICT (platform, external_id) DO NOTHING;

-- A few leads (some converted, some new) ------------------------------------
INSERT INTO leads (post_id, platform, contact_at, converted_student_id, status)
SELECT sp.post_id, sp.platform,
       sp.posted_at + INTERVAL '2 hours',
       CASE WHEN random() < 0.4
            THEN (SELECT student_id FROM students ORDER BY random() LIMIT 1)
            ELSE NULL END,
       CASE WHEN random() < 0.4 THEN 'converted' ELSE 'new' END
  FROM social_posts sp
 WHERE sp.posted_at > NOW() - INTERVAL '8 weeks'
 ORDER BY random() LIMIT 12
ON CONFLICT DO NOTHING;

COMMIT;
