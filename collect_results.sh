#!/usr/bin/env bash
# collect_results.sh - gathers the REAL output of the five runs into my_results.txt
cd "$(dirname "$0")"
OUT=my_results.txt
sec() { echo; echo "################ $1"; }
{
echo "Afordchess results - collected $(date '+%Y-%m-%d %H:%M %Z')"
echo "Repo: ${GITHUB_REPOSITORY:-unknown}   Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
sec "GIT LOG"; git log --format='%h %ad %s' --date=short 2>/dev/null | head -15

sec "P1 - row counts and constraint tests"
L=portfolio-1-database-design/p1_output.log
if [ -f "$L" ]; then sed -n '/Bulk data summary/,/rows)/p' "$L"; grep -E "TEST [0-9] (PASS|FAIL|control|UNEXPECTED)" "$L" | sed 's/^psql:[^ ]* NOTICE:  //'; else echo "(no p1_output.log)"; fi

sec "P2 - EXPLAIN ANALYZE summary"
if [ -f portfolio-2-query-optimisation/explain_summary.txt ]; then cat portfolio-2-query-optimisation/explain_summary.txt; else echo "(no explain_summary.txt)"; fi

sec "P3 - race, isolation, deadlock demos"
if [ -f portfolio-3-transactions-concurrency/race_demos_output.log ]; then cat portfolio-3-transactions-concurrency/race_demos_output.log; else echo "(no race_demos_output.log)"; fi

sec "P4 - validation, counts, COLLSCAN to IXSCAN"
L=portfolio-4-nosql/p4_output.log
if [ -f "$L" ]; then grep -E "^(PASS|FAIL) - " "$L"; grep -E "^(social_posts|daily_metrics|comments|conversions|TOTAL) *:" "$L"; else echo "(no p4_output.log)"; fi
if [ -f portfolio-4-nosql/index_demo_summary.txt ]; then cat portfolio-4-nosql/index_demo_summary.txt; fi

sec "P5 - partitions and replica"
L=portfolio-5-distributed-cloud/p5_output.log
if [ -f "$L" ]; then
  sed -n '/payments partition tree/,/total in old unpartitioned table/p' "$L" | grep -v '^$'
  grep -E "^===== (One-month|Same query)|Execution Time|on payments_unpartitioned" "$L"
else echo "(no p5_output.log)"; fi
if [ -f portfolio-5-distributed-cloud/replication_output.log ]; then echo; cat portfolio-5-distributed-cloud/replication_output.log; fi
} > "$OUT" 2>&1
echo "==> Wrote $OUT ($(wc -l < "$OUT") lines)"
