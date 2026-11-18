#!/usr/bin/env bash
# Minimal self-contained test runner (no external deps).
set -uo pipefail
# These scripts and tests target Linux (they read /proc and use GNU coreutils such as `touch -d`).
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "tests/run-tests.sh requires Linux (found $(uname -s)); run it on Ubuntu or in a Linux container." >&2
  exit 2
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$(mktemp)"; export LOG_FILE
pass=0; failn=0
ok()   { echo "ok   - $1"; pass=$((pass+1)); }
nok()  { echo "FAIL - $1"; failn=$((failn+1)); }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# backup: creates archive + checksum, prunes to KEEP
mkdir -p "$tmp/src" "$tmp/bk"; echo hi > "$tmp/src/a.txt"
for i in 1 2 3 4; do "$ROOT/scripts/backup.sh" "$tmp/src" "$tmp/bk" 2 >/dev/null 2>&1; sleep 1; done
n="$(ls "$tmp"/bk/*.tar.gz | wc -l)"
[[ "$n" -eq 2 ]] && ok "backup keeps newest 2 of 4" || nok "backup retention (got $n)"
( cd "$tmp/bk" && sha256sum -c ./*.sha256 >/dev/null 2>&1 ) && ok "backup checksums verify" || nok "checksums"

# backup: fails on missing source
"$ROOT/scripts/backup.sh" "$tmp/nope" "$tmp/bk" >/dev/null 2>&1 && nok "missing source should fail" || ok "backup rejects missing source"

# cleanup-logs: compress old, delete older, keep fresh
mkdir -p "$tmp/logs"
touch "$tmp/logs/fresh.log"
touch -d '10 days ago' "$tmp/logs/old.log"
echo x | gzip > "$tmp/logs/ancient.log.gz"; touch -d '40 days ago' "$tmp/logs/ancient.log.gz"
"$ROOT/scripts/cleanup-logs.sh" "$tmp/logs" 7 30 >/dev/null 2>&1
[[ -f "$tmp/logs/fresh.log" ]] && ok "fresh log untouched" || nok "fresh log removed"
[[ -f "$tmp/logs/old.log.gz" && ! -f "$tmp/logs/old.log" ]] && ok "old log compressed" || nok "old log not compressed"
[[ ! -f "$tmp/logs/ancient.log.gz" ]] && ok "ancient archive deleted" || nok "ancient archive kept"

# ssh-audit: good vs bad config
cat > "$tmp/good" <<CFG
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
CFG
printf 'PermitRootLogin yes\n#PasswordAuthentication no\n' > "$tmp/bad"
"$ROOT/scripts/ssh-audit.sh" "$tmp/good" >/dev/null && ok "ssh-audit passes hardened config" || nok "ssh-audit good"
"$ROOT/scripts/ssh-audit.sh" "$tmp/bad" >/dev/null && nok "ssh-audit should fail weak config" || ok "ssh-audit flags weak config"

# healthcheck: open port passes, closed port fails
python3 -m http.server 18765 --bind 127.0.0.1 >/dev/null 2>&1 & srv=$!
sleep 1
DISK_WARN_PCT=100 MEM_WARN_PCT=100 "$ROOT/scripts/healthcheck.sh" -p 18765 -u http://127.0.0.1:18765/ >/dev/null 2>&1 \
  && ok "healthcheck passes with live service" || nok "healthcheck live"
kill "$srv" 2>/dev/null; wait "$srv" 2>/dev/null
DISK_WARN_PCT=100 MEM_WARN_PCT=100 "$ROOT/scripts/healthcheck.sh" -p 18765 >/dev/null 2>&1 \
  && nok "healthcheck should fail on closed port" || ok "healthcheck fails on closed port"

echo "passed=$pass failed=$failn"
[[ "$failn" -eq 0 ]]
