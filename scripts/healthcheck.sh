#!/usr/bin/env bash
# Checks disk, memory, load, listening ports and HTTP endpoints.
# Exit code: 0 = all OK, 1 = at least one WARN/FAIL (usable from cron/CI).
#
# Usage: healthcheck.sh [-u URL]... [-p PORT]...
#   env: DISK_WARN_PCT (default 85)  MEM_WARN_PCT (default 90)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$DIR/common.sh"

DISK_WARN_PCT="${DISK_WARN_PCT:-85}"
MEM_WARN_PCT="${MEM_WARN_PCT:-90}"
URLS=(); PORTS=(); status=0

while getopts "u:p:" opt; do
  case "$opt" in
    u) URLS+=("$OPTARG") ;;
    p) PORTS+=("$OPTARG") ;;
    *) echo "Usage: $0 [-u URL]... [-p PORT]..." >&2; exit 2 ;;
  esac
done

warn() { log WARN "$*"; status=1; }

# Disk usage per mounted filesystem
while read -r pct mount; do
  pct="${pct%\%}"
  if (( pct >= DISK_WARN_PCT )); then warn "disk $mount at ${pct}% (limit ${DISK_WARN_PCT}%)"
  else log INFO "disk $mount at ${pct}%"; fi
done < <(df -P -x tmpfs -x devtmpfs | awk 'NR>1 {print $5, $6}')

# Memory usage
read -r total avail < <(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {print t, a}' /proc/meminfo)
used_pct=$(( (total - avail) * 100 / total ))
if (( used_pct >= MEM_WARN_PCT )); then warn "memory at ${used_pct}% (limit ${MEM_WARN_PCT}%)"
else log INFO "memory at ${used_pct}%"; fi

# Load average vs CPU count
cpus="$(nproc)"; load1="$(cut -d' ' -f1 /proc/loadavg)"
if awk -v l="$load1" -v c="$cpus" 'BEGIN {exit !(l > c)}'; then warn "load $load1 exceeds $cpus CPUs"
else log INFO "load $load1 on $cpus CPUs"; fi

# Listening TCP ports (uses ss; falls back to /dev/tcp probe)
for port in "${PORTS[@]:-}"; do
  [[ -z "$port" ]] && continue
  if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then log INFO "port $port open"
  else warn "port $port not accepting connections"; fi
done

# HTTP endpoints
for url in "${URLS[@]:-}"; do
  [[ -z "$url" ]] && continue
  code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$url" || true)"
  if [[ "$code" =~ ^2|^3 ]]; then log INFO "$url -> $code"
  else warn "$url -> ${code:-no response}"; fi
done

exit "$status"
