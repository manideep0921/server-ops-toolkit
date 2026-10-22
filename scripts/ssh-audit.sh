#!/usr/bin/env bash
# Read-only audit of sshd_config against a few common hardening settings.
# Does NOT modify anything. Usage: ssh-audit.sh [/etc/ssh/sshd_config]
set -euo pipefail
CONF="${1:-/etc/ssh/sshd_config}"
[[ -r "$CONF" ]] || { echo "cannot read $CONF" >&2; exit 2; }

fail=0
# setting|expected value
checks=(
  "PermitRootLogin|no"
  "PasswordAuthentication|no"
  "PubkeyAuthentication|yes"
  "PermitEmptyPasswords|no"
  "X11Forwarding|no"
)
for c in "${checks[@]}"; do
  key="${c%%|*}"; want="${c##*|}"
  # first uncommented occurrence wins (sshd behaviour)
  got="$(awk -v k="$key" 'tolower($1)==tolower(k) && $1 !~ /^#/ {print tolower($2); exit}' "$CONF")"
  if [[ "${got:-unset}" == "$want" ]]; then printf 'PASS  %-24s %s\n' "$key" "$got"
  else printf 'FAIL  %-24s got=%s want=%s\n' "$key" "${got:-unset}" "$want"; fail=1; fi
done
exit "$fail"
