# server-ops-toolkit

Bash scripts for routine Ubuntu/Linux server operations. Each script is
standalone, uses `set -euo pipefail`, logs with timestamps and returns
meaningful exit codes so it can run from cron, systemd timers or CI.

| Script | Purpose |
|---|---|
| `scripts/healthcheck.sh` | Disk, memory, load, TCP ports and HTTP endpoints; exit 1 on any warning |
| `scripts/backup.sh` | Timestamped `tar.gz` + SHA-256 checksum, keeps newest N archives |
| `scripts/cleanup-logs.sh` | Compress logs older than N days, delete archives older than M days (`--dry-run`) |
| `scripts/ssh-audit.sh` | Read-only check of `sshd_config` hardening settings |

## Usage
```bash
./scripts/healthcheck.sh -p 22 -p 80 -u http://127.0.0.1/
./scripts/backup.sh /var/www/app /var/backups 7
./scripts/cleanup-logs.sh /var/log/myapp 7 30 --dry-run
./scripts/ssh-audit.sh /etc/ssh/sshd_config
```

Schedule the health check with the included systemd timer
(`systemd/server-health.{service,timer}`) or cron:
`*/5 * * * * /opt/server-ops-toolkit/scripts/healthcheck.sh -p 80`

## Tests
Linux only (the scripts read `/proc` and the tests use GNU coreutils); on macOS the runner exits with a clear message.
```bash
./tests/run-tests.sh
```
Covers backup retention and checksums, log compression/deletion, SSH audit
pass/fail cases and health check pass/fail against a live and a stopped service.
