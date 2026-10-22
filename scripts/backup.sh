#!/usr/bin/env bash
# Timestamped tar.gz backup of a directory with retention and checksum.
# Usage: backup.sh SOURCE_DIR BACKUP_DIR [KEEP_COUNT]   (KEEP_COUNT default 7)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$DIR/common.sh"

SRC="${1:?usage: backup.sh SOURCE_DIR BACKUP_DIR [KEEP_COUNT]}"
DEST="${2:?usage: backup.sh SOURCE_DIR BACKUP_DIR [KEEP_COUNT]}"
KEEP="${3:-7}"

[[ -d "$SRC" ]] || die "source $SRC is not a directory"
mkdir -p "$DEST"

name="$(basename "$SRC")-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
tar -czf "$DEST/$name" -C "$(dirname "$SRC")" "$(basename "$SRC")"
( cd "$DEST" && sha256sum "$name" > "$name.sha256" && sha256sum -c "$name.sha256" >/dev/null )
log INFO "created $DEST/$name ($(du -h "$DEST/$name" | cut -f1))"

# Retention: keep newest KEEP archives for this source, delete older ones
prefix="$(basename "$SRC")-"
mapfile -t old < <(ls -1t "$DEST"/"$prefix"*.tar.gz 2>/dev/null | tail -n +"$((KEEP + 1))")
for f in "${old[@]:-}"; do
  [[ -z "$f" ]] && continue
  rm -f -- "$f" "$f.sha256"
  log INFO "pruned $f"
done
