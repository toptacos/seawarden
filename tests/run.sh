#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
pass() { printf 'PASS %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

# syntax
bash -n scripts/seawarden-backup.sh && pass 'bash -n backup' || bad 'bash -n backup'
bash -n scripts/seawarden-restore.sh && pass 'bash -n restore' || bad 'bash -n restore'

# no RaceRaves / internal IP leakage in kit
if rg -n 'RaceRaves|raceraves|167\.71\.111\.203|167\.99\.51\.32' \
  --glob '!tests/**' --glob '!.git/**' . ; then
  bad 'brand/IP scrub'
else
  pass 'brand/IP scrub'
fi

# PHP lint
if command -v php >/dev/null; then
  php -l status-api/backup-status.php >/dev/null && pass 'php -l status' || bad 'php -l status'
  php -l status-api/backup-download.php >/dev/null && pass 'php -l download' || bad 'php -l download'
  php -l wordpress/seawarden-backup-status/seawarden-backup-status.php >/dev/null && pass 'php -l plugin' || bad 'php -l plugin'
  php -l wordpress/seawarden-backup-status/includes/class-backup-status.php >/dev/null && pass 'php -l class' || bad 'php -l class'
else
  pass 'php lint skipped (no php)'
fi

# status API with fixture dir
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/status"
cat > "$TMP/status/production.json" <<'JSON'
{"env":"production","ok":true,"updated_at":"2026-11-24T00:00:00Z","last_backup":"20261124_000000","last_backup_size":100,"files_count":50,"disk_total":1000,"disk_used":100,"total_backups":1,"duration_seconds":10,"snapshot":"wp-content-20261124_000000"}
JSON
if command -v php >/dev/null; then
  out=$(SEAWARDEN_STATUS_DIR="$TMP/status" php -r '
    $_GET["env"]="production";
    include "status-api/backup-status.php";
  ')
  echo "$out" | grep -q '"ok":true' && pass 'status api fixture' || bad 'status api fixture'
  code=$(SEAWARDEN_STATUS_DIR="$TMP/status" php -r '
    $_GET["env"]="nope";
    include "status-api/backup-status.php";
  ' >/dev/null; echo $?)
  # php -r won't capture http code easily; check JSON error instead
  err=$(SEAWARDEN_STATUS_DIR="$TMP/status" php -r '$_GET["env"]="nope"; include "status-api/backup-status.php";' 2>/dev/null || true)
  echo "$err" | grep -q invalid_env && pass 'status api rejects bad env' || bad 'status api rejects bad env'
fi

# restore usage (exits 2)
out=$(scripts/seawarden-restore.sh 2>&1 || true)
grep -qi usage <<<"$out" && pass 'restore usage' || bad 'restore usage'

# benchmarks
python3 benchmarks/verify-fixtures.py && pass 'benchmark fixtures' || bad 'benchmark fixtures'

# required files
for f in README.md config/seawarden.env.example config/rsync-excludes.txt \
  scripts/seawarden-backup.sh wordpress/seawarden-backup-status/seawarden-backup-status.php \
  examples/laravel/README.md examples/symfony/README.md examples/nodejs/README.md; do
  [[ -f "$f" ]] && pass "exists $f" || bad "exists $f"
done

if (( fail )); then
  echo "FAILED"
  exit 1
fi
echo "ALL PASSED"
