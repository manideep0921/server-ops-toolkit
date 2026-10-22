#!/usr/bin/env bash
# Compress logs older than N days and delete compressed logs older than M days.
# Usage: cleanup-logs.sh LOG_DIR [COMPRESS_AFTER_DAYS=7] [DELETE_AFTER_DAYS=30] [--dry-run]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$DIR/common.sh"

LOG_DIR="${1:?usage: cleanup-logs.sh LOG_DIR [COMPRESS_DAYS] [DELETE_DAYS] [--dry-run]}"
COMPRESS_DAYS="${2:-7}"
DELETE_DAYS="${3:-30}"
DRY="${4:-}"

[[ -d "$LOG_DIR" ]] || die "$LOG_DIR is not a directory"

while IFS= read -r -d '' f; do
  if [[ "$DRY" == "--dry-run" ]]; then log INFO "would compress $f"
  else gzip -f -- "$f" && log INFO "compressed $f"; fi
done < <(find "$LOG_DIR" -maxdepth 1 -type f -name '*.log' -mtime +"$COMPRESS_DAYS" -print0)

while IFS= read -r -d '' f; do
  if [[ "$DRY" == "--dry-run" ]]; then log INFO "would delete $f"
  else rm -f -- "$f" && log INFO "deleted $f"; fi
done < <(find "$LOG_DIR" -maxdepth 1 -type f -name '*.gz' -mtime +"$DELETE_DAYS" -print0)
