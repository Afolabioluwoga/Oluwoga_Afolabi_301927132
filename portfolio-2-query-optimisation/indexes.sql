-- indexes.sql - the P2 index set (run AFTER the BEFORE plans were captured).
-- It re-creates the baseline helper indexes from schema.sql and adds new
-- composite ones aimed at the selective queries Q1, Q3, Q4, Q6, Q7.
\echo '==> Creating P2 indexes'
CREATE INDEX IF NOT EXISTS idx_attendance_session  ON attendance (session_id);
CREATE INDEX IF NOT EXISTS idx_attendance_student  ON attendance (student_id);
CREATE INDEX IF NOT EXISTS idx_sessions_course     ON sessions (course_id);
CREATE INDEX IF NOT EXISTS idx_sessions_startsat   ON sessions (starts_at);
CREATE INDEX IF NOT EXISTS idx_payments_paidat     ON payments (paid_at);
CREATE INDEX IF NOT EXISTS idx_payments_currency   ON payments (currency_code);
CREATE INDEX IF NOT EXISTS idx_invoices_status     ON invoices (status);
CREATE INDEX IF NOT EXISTS idx_invoices_billing    ON invoices (billing_month);
CREATE INDEX IF NOT EXISTS idx_enrolments_student  ON course_enrolments (student_id);
CREATE INDEX IF NOT EXISTS idx_enrolments_course   ON course_enrolments (course_id);
CREATE INDEX IF NOT EXISTS idx_leads_status        ON leads (status);
-- new, P2-specific
CREATE INDEX IF NOT EXISTS idx_sessions_coach_startsat ON sessions (coach_id, starts_at);   -- Q3
CREATE INDEX IF NOT EXISTS idx_invoices_status_cur_due ON invoices (status, currency_code, due_date); -- Q4
CREATE INDEX IF NOT EXISTS idx_payments_invoice        ON payments (invoice_id);            -- Q7 join (FK side)
CREATE INDEX IF NOT EXISTS idx_leads_converted_student ON leads (converted_student_id);     -- Q5
ANALYZE;
