-- ============================================================================
--  queries.sql - the 7 business queries for Afordchess Academy (P2).
--  run_p2.sh runs these, then wraps each one in EXPLAIN ANALYZE twice:
--  once BEFORE the P2 indexes exist and once AFTER.
--  Q1, Q3, Q4, Q6, Q7 are SELECTIVE (one coach, one currency, a recent window),
--  so indexes should help. Q2 and Q5 are full-history aggregates kept ON PURPOSE
--  to show where indexes do NOT help (the planner must read most of the table).
-- ============================================================================
\pset pager off

\echo '--- Q1: revenue per currency, last 30 days (selective on paid_at)'
SELECT p.currency_code,
       SUM(p.amount)                                  AS total_amount,
       ROUND(SUM(p.amount * c.usd_rate)::numeric, 2)  AS total_usd_equivalent,
       COUNT(*)                                       AS payment_count
  FROM payments p
  JOIN currencies c ON c.currency_code = p.currency_code
 WHERE p.paid_at >= CURRENT_DATE - INTERVAL '30 days'
 GROUP BY p.currency_code
 ORDER BY total_usd_equivalent DESC;

\echo '--- Q2: attendance per course, full history (full aggregate, kept on purpose)'
SELECT co.name AS course_name,
       COUNT(DISTINCT s.session_id) AS sessions_held,
       COUNT(a.attendance_id)       AS attendances_recorded,
       ROUND(100.0 * SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END)
             / NULLIF(COUNT(a.attendance_id), 0), 2) AS pct_present
  FROM courses co
  JOIN sessions s ON s.course_id = co.course_id
  LEFT JOIN attendance a ON a.session_id = s.session_id
 GROUP BY co.course_id, co.name
 ORDER BY pct_present DESC NULLS LAST;

\echo '--- Q3: distinct students taught by coach 3, last 90 days (selective)'
SELECT COUNT(DISTINCT s.session_id)  AS sessions_taught,
       COUNT(DISTINCT a.student_id)  AS distinct_students,
       COUNT(a.attendance_id)        AS total_attendances
  FROM sessions s
  JOIN attendance a ON a.session_id = s.session_id
 WHERE s.coach_id = 3
   AND s.starts_at >= CURRENT_DATE - INTERVAL '90 days'
   AND s.starts_at <  NOW();

\echo '--- Q4: 20 oldest overdue NGN invoices (selective)'
SELECT i.invoice_id, st.first_name || ' ' || st.last_name AS student_name,
       i.billing_month, i.amount_due, i.due_date,
       (CURRENT_DATE - i.due_date) AS days_overdue
  FROM invoices i
  JOIN students st ON st.student_id = i.student_id
 WHERE i.status = 'overdue' AND i.currency_code = 'NGN'
 ORDER BY i.due_date
 LIMIT 20;

\echo '--- Q5: marketing funnel - leads to converted students to payments (full aggregate, small tables)'
SELECT sp.platform,
       COUNT(l.lead_id)                 AS total_leads,
       COUNT(l.converted_student_id)    AS converted_leads,
       ROUND(SUM(p.amount * cur.usd_rate)::numeric, 2) AS revenue_usd_equiv
  FROM leads l
  JOIN social_posts sp ON sp.post_id = l.post_id
  LEFT JOIN invoices   i ON i.student_id = l.converted_student_id
  LEFT JOIN payments   p ON p.invoice_id = i.invoice_id
  LEFT JOIN currencies cur ON cur.currency_code = p.currency_code
 GROUP BY sp.platform
 ORDER BY revenue_usd_equiv DESC NULLS LAST;

\echo '--- Q6: online vs in-person sessions, last 14 days (selective on starts_at)'
SELECT s.mode,
       COUNT(DISTINCT s.session_id) AS sessions_held,
       COUNT(a.attendance_id)       AS total_attendances
  FROM sessions s
  LEFT JOIN attendance a ON a.session_id = s.session_id
 WHERE s.starts_at >= CURRENT_DATE - INTERVAL '14 days'
   AND s.starts_at <  NOW()
 GROUP BY s.mode
 ORDER BY sessions_held DESC;

\echo '--- Q7: top-grossing courses, last 90 days (selective on paid_at)'
SELECT co.name AS course_name,
       COUNT(p.payment_id) AS payments_received,
       ROUND(SUM(p.amount * cur.usd_rate)::numeric, 2) AS gross_usd_equivalent
  FROM payments p
  JOIN invoices   i   ON i.invoice_id = p.invoice_id
  JOIN courses    co  ON co.course_id = i.course_id
  JOIN currencies cur ON cur.currency_code = p.currency_code
 WHERE p.paid_at >= CURRENT_DATE - INTERVAL '90 days'
 GROUP BY co.course_id, co.name
 ORDER BY gross_usd_equivalent DESC
 LIMIT 10;
