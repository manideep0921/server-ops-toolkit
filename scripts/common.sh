#!/usr/bin/env bash
# Shared helpers: logging and config loading.
set -euo pipefail

LOG_FILE="${LOG_FILE:-/tmp/server-ops.log}"

log() {
  local level="$1"; shift
  printf '%s [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$*" | tee -a "$LOG_FILE" >&2
}
die() { log ERROR "$*"; exit 1; }
