#!/usr/bin/env python3
"""run_race_demos.py - P3 concurrency demos with TWO real database sessions.
Everything printed here is real output from this run (no pasted or typed results)."""
import sys, threading, time
import psycopg2
from psycopg2 import errors
from psycopg2.extensions import (ISOLATION_LEVEL_READ_COMMITTED as RC,
                                 ISOLATION_LEVEL_REPEATABLE_READ as RR,
                                 ISOLATION_LEVEL_SERIALIZABLE as SER)
DSN = dict(host='/var/run/postgresql', dbname='afordchess', user='afordchess')

def conn(iso=RC):
    c = psycopg2.connect(**DSN); c.set_isolation_level(iso); return c
def one(c, sql, args=None):
    cur = c.cursor(); cur.execute(sql, args); r = cur.fetchone(); cur.close(); return r[0]
admin = psycopg2.connect(**DSN); admin.autocommit = True
made = []

def new_session(booked):
    """Fresh capacity-8 session with `booked` students already in it, plus 2 spare enrolled students."""
    cur = admin.cursor()
    cur.execute("""SELECT course_id FROM course_enrolments WHERE status='active'
                   GROUP BY course_id HAVING COUNT(*) >= 12 ORDER BY course_id LIMIT 1""")
    course = cur.fetchone()[0]
    cur.execute("""INSERT INTO sessions (course_id, coach_id, school_id, starts_at, duration_minutes, capacity, mode)
                   VALUES (%s, 1, NULL, NOW() + INTERVAL '2 days', 60, 8, 'online') RETURNING session_id""", (course,))
    sid = cur.fetchone()[0]; made.append(sid)
    cur.execute("SELECT student_id FROM course_enrolments WHERE course_id=%s AND status='active' ORDER BY student_id LIMIT 12", (course,))
    studs = [r[0] for r in cur.fetchall()]
    for s in studs[:booked]:
        cur.execute("INSERT INTO attendance (session_id, student_id) VALUES (%s,%s)", (sid, s))
    return sid, studs[booked:booked + 2]
def count(sid): return one(admin, "SELECT COUNT(*) FROM attendance WHERE session_id=%s", (sid,))
def head(t): print('\n' + '=' * 70 + '\n' + t + '\n' + '=' * 70)
results = []
def verdict(name, ok, detail): results.append((name, ok, detail)); print(('PASS  ' if ok else 'FAIL  ') + detail)

# ---- Part 1: the bug --------------------------------------------------------
head('PART 1 - THE BUG: check-then-insert with no lock (READ COMMITTED)')
sid, (a, b) = new_session(7)
print(f'Session {sid}: capacity 8, already booked {count(sid)}. Two students try to book the LAST seat.')
c1, c2 = conn(), conn()
print('Session A:', one(c1, 'SELECT book_session_unsafe(%s,%s)', (sid, a)), '(not committed yet)')
print('Session B:', one(c2, 'SELECT book_session_unsafe(%s,%s)', (sid, b)), '(not committed yet)')
c1.commit(); c2.commit(); c1.close(); c2.close()
n = count(sid)
print(f'After both commit: {n}/8 booked. The capacity trigger could not stop it: under READ COMMITTED it cannot see the other session\'s uncommitted row.')
verdict('1 race bug', n == 9, f'overbooked {n}/8 (expected 9/8)')

# ---- Part 2: fix with FOR UPDATE ---------------------------------------------
head('PART 2 - FIX 1: SELECT ... FOR UPDATE on the session row (book_session_safe)')
sid, (a, b) = new_session(7)
print(f'Session {sid}: capacity 8, booked {count(sid)}.')
c1, c2 = conn(), conn(); out = {}
print('Session A:', one(c1, 'SELECT book_session_safe(%s,%s)', (sid, a)), '(holds the row lock, not committed)')
def second():
    out['r'] = one(c2, 'SELECT book_session_safe(%s,%s)', (sid, b)); c2.commit()
t = threading.Thread(target=second); t.start(); time.sleep(1.5)
blocked = t.is_alive()
print('Session B is waiting for the lock:', blocked)
c1.commit(); t.join(15)
print('Session B result after A committed:', out.get('r'))
n = count(sid); c1.close(); c2.close()
verdict('2 FOR UPDATE', blocked and n == 8 and str(out.get('r', '')).startswith('class full'),
        f'B waited, then was refused; final {n}/8')

# ---- Part 3: fix with SERIALIZABLE -------------------------------------------
head('PART 3 - FIX 2: SERIALIZABLE isolation + client retry')
sid, (a, b) = new_session(7)
print(f'Session {sid}: capacity 8, booked {count(sid)}.')
c1, c2 = conn(SER), conn(SER)
print('Session A:', one(c1, 'SELECT book_session_unsafe(%s,%s)', (sid, a)))
failed = None
try:
    print('Session B:', one(c2, 'SELECT book_session_unsafe(%s,%s)', (sid, b)))
    c1.commit(); print('Session A committed.')
    c2.commit()
except errors.SerializationFailure as e:
    failed = e.pgcode; c2.rollback()
    print('Session B FAILED to commit: SQLSTATE', e.pgcode, '- could not serialize access. Retrying B in a new transaction...')
try: c1.commit()
except Exception: pass
c1.close(); c2.close()
c3 = conn(SER)
retry = one(c3, 'SELECT book_session_unsafe(%s,%s)', (sid, b)); c3.commit(); c3.close()
print('Session B retry result:', retry)
n = count(sid)
verdict('3 SERIALIZABLE', failed == '40001' and n == 8 and retry.startswith('class full'),
        f'second writer got 40001, retry refused; final {n}/8')

# ---- Part 4: isolation levels --------------------------------------------------
head('PART 4 - READ COMMITTED vs REPEATABLE READ (what a long transaction sees)')
sid, (a, b) = new_session(3)
rc = conn(RC); first = one(rc, 'SELECT COUNT(*) FROM attendance WHERE session_id=%s', (sid,))
admin.cursor().execute('INSERT INTO attendance (session_id, student_id) VALUES (%s,%s)', (sid, a))
second_ = one(rc, 'SELECT COUNT(*) FROM attendance WHERE session_id=%s', (sid,)); rc.commit(); rc.close()
print(f'READ COMMITTED  : first read {first}, same query after another session committed -> {second_}  (non-repeatable)')
rr = conn(RR); f1 = one(rr, 'SELECT COUNT(*) FROM attendance WHERE session_id=%s', (sid,))
admin.cursor().execute('INSERT INTO attendance (session_id, student_id) VALUES (%s,%s)', (sid, b))
f2 = one(rr, 'SELECT COUNT(*) FROM attendance WHERE session_id=%s', (sid,)); rr.commit()
f3 = one(rr, 'SELECT COUNT(*) FROM attendance WHERE session_id=%s', (sid,)); rr.commit(); rr.close()
print(f'REPEATABLE READ : first read {f1}, same query after another session committed -> {f2}; new transaction sees {f3}')
verdict('4 isolation', second_ == first + 1 and f2 == f1 and f3 == f1 + 1, 'RC sees the change, RR keeps its snapshot')

# ---- Part 5: deadlock ------------------------------------------------------------
head('PART 5 - DEADLOCK: two sessions lock two rows in opposite order')
sA, _ = new_session(0); sB, _ = new_session(0)
c1, c2 = conn(), conn(); err = {}
lock = lambda c, s: one(c, 'SELECT session_id FROM sessions WHERE session_id=%s FOR UPDATE', (s,))
lock(c1, sA); lock(c2, sB)
print(f'Session 1 holds session {sA}; session 2 holds session {sB}. Now each asks for the other one.')
def go(name, c, s):
    try: lock(c, s); err[name] = 'got the second lock'
    except errors.DeadlockDetected as e:
        err[name] = 'DEADLOCK victim, SQLSTATE ' + e.pgcode; c.rollback()
t1 = threading.Thread(target=go, args=('S1', c1, sB)); t2 = threading.Thread(target=go, args=('S2', c2, sA))
t1.start(); time.sleep(0.3); t2.start(); t1.join(20); t2.join(20)
print('Session 1:', err.get('S1')); print('Session 2:', err.get('S2'))
for c in (c1, c2):
    try: c.rollback()
    except Exception: pass
    c.close()
victims = [k for k, v in err.items() if 'DEADLOCK' in v]
verdict('5 deadlock', len(victims) == 1, f'PostgreSQL aborted exactly one session ({victims[0] if victims else "none"}) and let the other finish')
print('\nFIX: always lock rows in the same order (lowest session_id first).')
c1, c2 = conn(), conn(); order = sorted([sA, sB]); done = {}
for s in order: lock(c1, s)
def ordered():
    for s in order: lock(c2, s)
    done['ok'] = True; c2.commit()
t = threading.Thread(target=ordered); t.start(); time.sleep(0.5)
print('Session 2 is waiting (no deadlock):', t.is_alive()); c1.commit(); t.join(15)
c1.close(); c2.close()
verdict('5b ordered locks', done.get('ok') is True, 'with a fixed lock order session 2 simply waited, then finished')

# ---- clean up demo rows and summarise ---------------------------------------------
cur = admin.cursor(); cur.execute('DELETE FROM sessions WHERE session_id = ANY(%s)', (made,))
head('SUMMARY'); [print(('PASS ' if ok else 'FAIL ') + n + ' - ' + d) for n, ok, d in results]
sys.exit(0 if all(ok for _, ok, _ in results) else 1)
