-- book_session.sql - booking functions for P3.
-- (A function cannot COMMIT or ROLLBACK in PostgreSQL; the caller owns the transaction.)
\set ON_ERROR_STOP on

-- 1) UNSAFE: check-then-insert with no lock (shows the race) ----------------
DROP FUNCTION IF EXISTS book_session_unsafe(INTEGER, INTEGER) CASCADE;
CREATE FUNCTION book_session_unsafe(p_session_id INTEGER, p_student_id INTEGER)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE v_cap INTEGER; v_cur INTEGER;
BEGIN
    SELECT capacity INTO v_cap FROM sessions WHERE session_id = p_session_id;
    IF v_cap IS NULL THEN RETURN 'ERROR: session not found'; END IF;
    SELECT COUNT(*) INTO v_cur FROM attendance WHERE session_id = p_session_id;
    IF v_cur >= v_cap THEN
        RETURN format('class full (capacity=%s, current=%s)', v_cap, v_cur);
    END IF;
    BEGIN
        INSERT INTO attendance (session_id, student_id) VALUES (p_session_id, p_student_id);
    EXCEPTION WHEN unique_violation THEN
        RETURN 'already booked';
    END;
    RETURN format('booked OK (it was %s/%s before this booking)', v_cur, v_cap);
END $$;

-- 2) SAFE: lock the session row first (SELECT ... FOR UPDATE) ----------------
DROP FUNCTION IF EXISTS book_session_safe(INTEGER, INTEGER) CASCADE;
CREATE FUNCTION book_session_safe(p_session_id INTEGER, p_student_id INTEGER)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE v_cap INTEGER; v_cur INTEGER;
BEGIN
    SELECT capacity INTO v_cap FROM sessions WHERE session_id = p_session_id FOR UPDATE;  -- other callers wait here
    IF v_cap IS NULL THEN RETURN 'ERROR: session not found'; END IF;
    SELECT COUNT(*) INTO v_cur FROM attendance WHERE session_id = p_session_id;           -- fresh count under the lock
    IF v_cur >= v_cap THEN
        RETURN format('class full (capacity=%s, current=%s)', v_cap, v_cur);
    END IF;
    BEGIN
        INSERT INTO attendance (session_id, student_id) VALUES (p_session_id, p_student_id);
    EXCEPTION WHEN unique_violation THEN
        RETURN 'already booked';
    END;
    RETURN format('booked OK (it was %s/%s before this booking)', v_cur, v_cap);
END $$;
\echo '==> book_session_unsafe() and book_session_safe() created'
