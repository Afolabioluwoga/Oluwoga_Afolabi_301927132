-- ============================================================================
--  triggers.sql — enforce the two business limitations listed in the P1 README.
--  Run AFTER schema.sql. Idempotent (uses CREATE OR REPLACE / DROP IF EXISTS).
-- ============================================================================

-- 1) Capacity check ----------------------------------------------------------
--   A session's capacity cannot be exceeded: counting the rows already in
--   `attendance` for that session must be strictly less than sessions.capacity
--   before a new attendance row is allowed.
DROP FUNCTION IF EXISTS fn_check_session_capacity() CASCADE;
CREATE OR REPLACE FUNCTION fn_check_session_capacity()
RETURNS TRIGGER AS $$
DECLARE
    current_count INTEGER;
    max_capacity  INTEGER;
BEGIN
    SELECT s.capacity INTO max_capacity
      FROM sessions s
     WHERE s.session_id = NEW.session_id;

    IF max_capacity IS NULL THEN
        RAISE EXCEPTION 'Session % does not exist', NEW.session_id;
    END IF;

    SELECT COUNT(*) INTO current_count
      FROM attendance a
     WHERE a.session_id = NEW.session_id;

    IF current_count >= max_capacity THEN
        RAISE EXCEPTION 'Session % is full (capacity=%, already booked=%). Booking rejected.',
            NEW.session_id, max_capacity, current_count;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_capacity ON attendance;
CREATE TRIGGER trg_check_capacity
    BEFORE INSERT ON attendance
    FOR EACH ROW EXECUTE FUNCTION fn_check_session_capacity();

-- 2) Enrolment check ---------------------------------------------------------
--   A student can only be booked into a session for a course they are
--   enrolled in (an active enrolment in course_enrolments).
DROP FUNCTION IF EXISTS fn_check_enrolment() CASCADE;
CREATE OR REPLACE FUNCTION fn_check_enrolment()
RETURNS TRIGGER AS $$
DECLARE
    course_id_of_session INTEGER;
    is_enrolled          BOOLEAN;
BEGIN
    SELECT s.course_id INTO course_id_of_session
      FROM sessions s
     WHERE s.session_id = NEW.session_id;

    IF course_id_of_session IS NULL THEN
        RAISE EXCEPTION 'Session % does not exist', NEW.session_id;
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM course_enrolments ce
         WHERE ce.student_id = NEW.student_id
           AND ce.course_id  = course_id_of_session
           AND ce.status     = 'active'
    ) INTO is_enrolled;

    IF NOT is_enrolled THEN
        RAISE EXCEPTION
            'Student % is not actively enrolled in course % (session %). Booking rejected.',
            NEW.student_id, course_id_of_session, NEW.session_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_enrolment ON attendance;
CREATE TRIGGER trg_check_enrolment
    BEFORE INSERT ON attendance
    FOR EACH ROW EXECUTE FUNCTION fn_check_enrolment();
