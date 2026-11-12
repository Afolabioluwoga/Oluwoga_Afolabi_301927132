# Portfolio 3 - Transactions & Concurrency (Afordchess Academy)

Scenario: the last seat in a capacity-8 class is booked by two students at the same moment.

| File | Purpose |
|---|---|
| `book_session.sql` | `book_session_unsafe()` (check-then-insert, the bug) and `book_session_safe()` (`SELECT ... FOR UPDATE`). |
| `run_race_demos.py` | Runs five parts with two real sessions and prints labelled output: 1 the bug (9/8), 2 FOR UPDATE, 3 SERIALIZABLE with retry (SQLSTATE 40001), 4 READ COMMITTED vs REPEATABLE READ, 5 deadlock and the fixed-lock-order fix. |
| `run_p3.sh` | Loads the functions and runs the demos; output saved to `race_demos_output.log`. |

Run: `bash run_p3.sh`.

Note for the defence: the capacity trigger from P1 does not stop the race under READ COMMITTED, because a session cannot see another session's uncommitted row. The lock (FOR UPDATE) or SERIALIZABLE isolation is what makes the check safe.

Suggested commit: `git add portfolio-3-transactions-concurrency/ && git commit -m "P3: booking race, FOR UPDATE, SERIALIZABLE retry, isolation levels, deadlock"`
