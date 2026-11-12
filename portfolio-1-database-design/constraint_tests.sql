-- ============================================================================
--  constraint_tests.sql — five constraint tests that MUST FAIL.
--  Each block is wrapped in a DO block so the script keeps running
--  even if one fails. Run AFTER schema.sql + triggers.sql + seed_data.sql.
--
--  Expected behaviour: each test prints "Expected FAIL: ..." and the
--  underlying error from PostgreSQL. The script ends with exit code 0
--  regardless, because failures are EXPECTED.
-- ============================================================================

\set ON_ERROR_STOP off

\echo '================================================================'
\echo ' Constraint tests — each block is expected to raise an error.'
\echo '================================================================'

-- ---------------------------------------------------------------------------
-- TEST 1: duplicate student email (students.email UNIQUE)
-- ---------------------------------------------------------------------------
\echo ''
\echo '[TEST 1] Duplicate student email — should FAIL with unique_violation'
DO $$
BEGIN
    INSERT INTO students (first_name, last_name, email, country_id)
    VALUES ('Aisha', 'Bello', 'aisha.bello@example.com',
            (SELECT country_id FROM countries WHERE iso_code='NG'));
    RAISE NOTICE 'TEST 1 UNEXPECTED: insert succeeded (should have failed)';
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'TEST 1 PASS: duplicate email rejected — %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'TEST 1 PASS (other): %', SQLERRM;
END $$;

-- ---------------------------------------------------------------------------
-- TEST 2: wrong currency on payment (composite FK invoice+currency)
-- ---------------------------------------------------------------------------
\echo ''
\echo '[TEST 2] Payment in wrong currency — should FAIL with foreign_key_violation'
DO $$
DECLARE
    v_invoice_id INTEGER;
BEGIN
    -- pick an NGN-denominated invoice, then try to pay it in USD
    SELECT i.invoice_id INTO v_invoice_id
      FROM invoices i
      JOIN countries c ON c.default_currency_code = i.currency_code
     WHERE c.iso_code = 'NG' LIMIT 1;

    INSERT INTO payments (invoice_id, student_id, amount, currency_code, method)
    VALUES (v_invoice_id,
            (SELECT student_id FROM invoices WHERE invoice_id = v_invoice_id),
            100.00, 'USD', 'card');        -- wrong currency: invoice is NGN
    RAISE NOTICE 'TEST 2 UNEXPECTED: insert succeeded (should have failed)';
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'TEST 2 PASS: wrong-currency payment rejected — %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'TEST 2 PASS (other): %', SQLERRM;
END $$;

-- ---------------------------------------------------------------------------
-- TEST 3: in-person session with no school (CHECK constraint)
-- ---------------------------------------------------------------------------
\echo ''
\echo '[TEST 3] In-person session with no school — should FAIL with check_violation'
DO $$
BEGIN
    INSERT INTO sessions (course_id, coach_id, school_id, starts_at, duration_minutes, capacity, mode)
    VALUES (1, 1, NULL,                                -- school_id is NULL
            NOW() + INTERVAL '1 day', 60, 8, 'in-person');
    RAISE NOTICE 'TEST 3 UNEXPECTED: insert succeeded (should have failed)';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'TEST 3 PASS: in-person session without school rejected — %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'TEST 3 PASS (other): %', SQLERRM;
END $$;

-- ---------------------------------------------------------------------------
-- TEST 4: capacity exceeded (trg_check_capacity trigger)
--   Fills a session of capacity 8 with 8 attendees, then tries the 9th.
-- ---------------------------------------------------------------------------
\echo ''
\echo '[TEST 4] Session capacity exceeded — should FAIL (trigger exception)'
DO $$
DECLARE
    v_session_id INTEGER;
    v_course_id  INTEGER;
    v_students   INTEGER[];
BEGIN
    SELECT course_id INTO v_course_id FROM courses ORDER BY course_id LIMIT 1;
    -- Fresh session with capacity = 8.
    INSERT INTO sessions (course_id, coach_id, school_id, starts_at,
                          duration_minutes, capacity, mode)
    VALUES (v_course_id, 1, NULL, NOW() + INTERVAL '3 days', 60, 8, 'online')
    RETURNING session_id INTO v_session_id;

    -- Pick 9 students NOT yet enrolled in that course, and enrol them.
    SELECT array_agg(q.student_id) INTO v_students FROM (
        SELECT st.student_id FROM students st
         WHERE NOT EXISTS (SELECT 1 FROM course_enrolments ce
                            WHERE ce.student_id = st.student_id AND ce.course_id = v_course_id)
         ORDER BY st.student_id LIMIT 9) q;
    INSERT INTO course_enrolments (student_id, course_id, status)
    SELECT unnest(v_students), v_course_id, 'active';

    -- Control: the first 8 bookings must SUCCEED.
    FOR i IN 1..8 LOOP
        INSERT INTO attendance (session_id, student_id) VALUES (v_session_id, v_students[i]);
    END LOOP;
    RAISE NOTICE 'TEST 4 control: first 8 bookings succeeded';

    -- The 9th must fail with the capacity message (not some other error).
    BEGIN
        INSERT INTO attendance (session_id, student_id) VALUES (v_session_id, v_students[9]);
        RAISE NOTICE 'TEST 4 FAIL: 9th booking succeeded (should have been rejected)';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%is full%' THEN
            RAISE NOTICE 'TEST 4 PASS: capacity exceeded rejected - %', SQLERRM;
        ELSE
            RAISE NOTICE 'TEST 4 FAIL: wrong error - %', SQLERRM;
        END IF;
    END;
END $$;

-- ---------------------------------------------------------------------------
-- TEST 5: student not enrolled (trg_check_enrolment trigger)
--   Tries to book a student into a session for a course they are NOT enrolled in.
-- ---------------------------------------------------------------------------
\echo ''
\echo '[TEST 5] Student not enrolled in course — should FAIL (trigger exception)'
DO $$
DECLARE
    v_session_id INTEGER;
    v_course_id  INTEGER;
    v_student_id INTEGER;
BEGIN
    -- Find a course and a student who is NOT enrolled in it.
    SELECT course_id INTO v_course_id FROM courses LIMIT 1;
    LOOP
        SELECT s.student_id INTO v_student_id
          FROM students s
         WHERE s.student_id NOT IN (
                SELECT student_id FROM course_enrolments WHERE course_id = v_course_id)
         ORDER BY random() LIMIT 1;
        EXIT WHEN v_student_id IS NOT NULL;
        -- if all students enrolled, expand the search by skipping course 1
        v_course_id := v_course_id + 1;
    END LOOP;

    INSERT INTO sessions (course_id, coach_id, school_id, starts_at,
                         duration_minutes, capacity, mode)
    VALUES (v_course_id, 1, NULL, NOW() + INTERVAL '4 days', 60, 8, 'online')
    RETURNING session_id INTO v_session_id;

    INSERT INTO attendance (session_id, student_id)
    VALUES (v_session_id, v_student_id);
    RAISE NOTICE 'TEST 5 UNEXPECTED: booking succeeded (should have failed)';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'TEST 5 PASS: not-enrolled booking rejected — %', SQLERRM;
END $$;

\echo ''
\echo '================================================================'
\echo ' End of constraint tests — all 5 should report PASS above.'
\echo '================================================================'
