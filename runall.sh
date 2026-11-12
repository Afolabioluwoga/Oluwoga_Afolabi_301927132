#!/usr/bin/env bash
# runall.sh - runs setup (if needed) and all five Afordchess portfolios, commits and pushes each.
# Put this file and the *_FIXED.zip in your repo folder, then:   bash runall.sh
# To resume from a later portfolio:   bash runall.sh 3
set -uo pipefail
START="${1:-1}"
REPO="$(pwd)"
KIT="$HOME/kit"
FOLDERS=(portfolio-1-database-design portfolio-2-query-optimisation portfolio-3-transactions-concurrency portfolio-4-nosql portfolio-5-distributed-cloud)

find_p1() { find "$KIT" -maxdepth 3 -type d -name 'portfolio-1-*' 2>/dev/null | head -1; }
P1="$(find_p1)"
if [ -z "$P1" ]; then
  ZIP="$(ls "$REPO"/*FIXED*.zip 2>/dev/null | head -1)"
  if [ -z "$ZIP" ]; then echo "!!! No *_FIXED.zip in $REPO - drag the zip into this folder first"; exit 1; fi
  echo "==> Unzipping $(basename "$ZIP") to $KIT"
  rm -rf "$KIT"; mkdir -p "$KIT"; unzip -q -o "$ZIP" -d "$KIT"
  P1="$(find_p1)"
fi
KITROOT="$(dirname "$P1")"

# repo-level files
cp "$KITROOT/README.md" "$KITROOT/setup.sh" "$KITROOT/collect_results.sh" "$REPO/"
[ -f "$KITROOT/CHANGES.md" ] && cp "$KITROOT/CHANGES.md" "$REPO/"
mkdir -p "$REPO/docs" && cp -r "$KITROOT/docs/." "$REPO/docs/"

# services (Codespaces stops background programs when it sleeps)
sudo pg_ctlcluster 16 main start 2>/dev/null || true
if ! pgrep -x mongod >/dev/null && command -v mongod >/dev/null; then
  sudo runuser -u mongodb -- "$(command -v mongod)" --dbpath /data/db --logpath /var/log/mongodb/mongod.log --bind_ip 127.0.0.1 --port 27017 --fork >/dev/null 2>&1 || true
  sleep 3
fi

# setup if the database is missing
if ! sudo runuser -u postgres -- psql -h /var/run/postgresql -d afordchess -c 'SELECT 1' >/dev/null 2>&1; then
  echo "==> Database missing - running setup.sh (a few minutes)"
  bash "$REPO/setup.sh" 2>&1 | tee "$REPO/setup_output.log"
  if [ "${PIPESTATUS[0]}" -ne 0 ]; then echo "!!! SETUP FAILED - send Joseph setup_output.log"; exit 1; fi
fi
git add -A >/dev/null 2>&1; git commit -q -m "Setup: kit files, setup script" >/dev/null 2>&1 || true

for N in 1 2 3 4 5; do
  [ "$N" -lt "$START" ] && continue
  D="${FOLDERS[$((N-1))]}"
  echo; echo "################ P$N : $D"
  rm -rf "$REPO/$D"; cp -r "$KITROOT/$D" "$REPO/$D"
  ( cd "$REPO/$D" && bash "run_p$N.sh" 2>&1 | tee "p${N}_output.log"; exit "${PIPESTATUS[0]}" )
  RC=$?
  if [ "$RC" -ne 0 ]; then echo; echo "!!! P$N FAILED - send Joseph $D/p${N}_output.log"; exit 1; fi
  git add -A "$D" >/dev/null 2>&1
  git commit -q -m "P$N: $D - run outputs" >/dev/null 2>&1 || true
  git push -q 2>/dev/null || echo "    (git push did not work - fine, push later)"
done

echo; echo "################ Collecting results"
bash "$REPO/collect_results.sh"
git add -A >/dev/null 2>&1; git commit -q -m "Collected results" >/dev/null 2>&1 || true
git push -q 2>/dev/null || true
echo "==> ALL DONE. Open my_results.txt, press Ctrl+A, Ctrl+C and paste it to Joseph."
code my_results.txt 2>/dev/null || true
