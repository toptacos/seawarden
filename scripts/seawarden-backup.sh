#!/usr/bin/env bash
# SeaWarden vault backup — pull DB + files from origin over SSH.
# Usage: seawarden-backup <production|staging|development>
set -euo pipefail

ENV_NAME="${1:-}"
case "$ENV_NAME" in
  production|staging|development) ;;
  *)
    echo "usage: $0 <production|staging|development>" >&2
    exit 2
    ;;
esac

ENV_FILE="${SEAWARDEN_ENV_FILE:-/etc/seawarden/seawarden.env}"
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${SEAWARDEN_ROOT:?}" "${SSH_KEY:?}" "${SSH_USER:?}" "${SSH_HOST:?}" "${SITE_PATH:?}"
RETENTION="${RETENTION:-24}"
LOCK_STALE_SECONDS="${LOCK_STALE_SECONDS:-2700}"
RSYNC_BWLIMIT="${RSYNC_BWLIMIT:-50000}"
EXCLUDE_FILE="${EXCLUDE_FILE:-/etc/seawarden/rsync-excludes.txt}"
STATUS_DIR="${STATUS_DIR:-$SEAWARDEN_ROOT/status}"
ORIGIN_STACK="${ORIGIN_STACK:-wordpress}"

BACKUP_ROOT="$SEAWARDEN_ROOT/backups/$ENV_NAME"
LOCK_FILE="$SEAWARDEN_ROOT/locks/${ENV_NAME}.lock"
TIMESTAMP="$(date -u +%Y%m%d_%H%M%S)"
START_EPOCH="$(date +%s)"
mkdir -p "$BACKUP_ROOT" "$STATUS_DIR" "$(dirname "$LOCK_FILE")"

log() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

# Stale lock handling
if [[ -f "$LOCK_FILE" ]]; then
  age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || stat -f %m "$LOCK_FILE") ))
  if (( age > LOCK_STALE_SECONDS )); then
    log "Clearing stale lock (${age}s)"
    rm -f "$LOCK_FILE"
  fi
fi

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "Another backup holds the lock; exiting"
  exit 0
fi

SSH=(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o BatchMode=yes)
RSYNC_SSH="ssh -i $SSH_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o BatchMode=yes"

log "=== Starting backup for environment: $ENV_NAME ==="

# --- connect ---
T0=$(date +%s)
"${SSH[@]}" "$SSH_USER@$SSH_HOST" "test -d '$SITE_PATH'"
log "TIMING connect: $(( $(date +%s) - T0 ))s"

# --- database stream ---
DB_FILE="$BACKUP_ROOT/db_${TIMESTAMP}.sql.gz"
T0=$(date +%s)
case "$ORIGIN_STACK" in
  wordpress)
    DUMP_REMOTE="cd '$SITE_PATH' && wp db export --allow-root --single-transaction --quick --lock-tables=false -"
    ;;
  laravel|symfony)
    DUMP_REMOTE="${DB_DUMP_CMD:?Set DB_DUMP_CMD for $ORIGIN_STACK (see examples/)}"
    ;;
  node)
    DUMP_REMOTE="${DB_DUMP_CMD:?Set DB_DUMP_CMD for node (see examples/nodejs)}"
    ;;
  *)
    log "Unknown ORIGIN_STACK=$ORIGIN_STACK"; exit 1
    ;;
esac

timeout 900 "${SSH[@]}" "$SSH_USER@$SSH_HOST" "$DUMP_REMOTE" | gzip -9 > "$DB_FILE"
log "TIMING db_backup: $(( $(date +%s) - T0 ))s"
DB_SIZE=$(stat -c %s "$DB_FILE" 2>/dev/null || stat -f %z "$DB_FILE")
if (( DB_SIZE < 1024 )); then
  log "ERROR: dump too small ($DB_SIZE bytes)"; exit 1
fi
gzip -t "$DB_FILE"
HEADER=$(gzip -dc "$DB_FILE" | head -c 200 || true)
if ! grep -qiE 'MySQL dump|PostgreSQL|MariaDB|SQLite' <<<"$HEADER"; then
  log "WARN: dump header did not match known SQL signatures"
fi
log "Database backup complete: $DB_FILE ($DB_SIZE bytes)"

# --- files via link-dest ---
PREV=$(ls -1d "$BACKUP_ROOT"/wp-content-* "$BACKUP_ROOT"/files-* 2>/dev/null | sort | tail -1 || true)
SNAP_NAME="wp-content-${TIMESTAMP}"
[[ "$ORIGIN_STACK" != wordpress ]] && SNAP_NAME="files-${TIMESTAMP}"
SNAP_DIR="$BACKUP_ROOT/$SNAP_NAME"
REMOTE_FILES="$SITE_PATH/wp-content/"
[[ "$ORIGIN_STACK" != wordpress ]] && REMOTE_FILES="${REMOTE_FILES_PATH:-$SITE_PATH/}"

LINK_ARGS=()
[[ -n "$PREV" ]] && LINK_ARGS=(--link-dest="$PREV")

T0=$(date +%s)
mkdir -p "$SNAP_DIR"
rsync -a --delete "${LINK_ARGS[@]}" --bwlimit="$RSYNC_BWLIMIT" \
  --exclude-from="$EXCLUDE_FILE" --partial \
  -e "$RSYNC_SSH" \
  "$SSH_USER@$SSH_HOST:$REMOTE_FILES" \
  "$SNAP_DIR/"
log "TIMING files_sync: $(( $(date +%s) - T0 ))s"

# --- verify files ---
FILE_COUNT=$(find "$SNAP_DIR" -type f | wc -l | tr -d ' ')
if (( FILE_COUNT < 10 )); then
  log "ERROR: file count too low ($FILE_COUNT)"; exit 1
fi
SAMPLES=$(find "$SNAP_DIR" -type f | head -3)
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  test -r "$f"
done <<<"$SAMPLES"
log "FS verification passed ($FILE_COUNT files)"

# --- status JSON (jq typed args) ---
DISK_TOTAL=$(df -B1 "$SEAWARDEN_ROOT" | awk 'NR==2{print $2}')
DISK_USED=$(df -B1 "$SEAWARDEN_ROOT" | awk 'NR==2{print $3}')
TOTAL_BACKUPS=$(ls -1 "$BACKUP_ROOT"/db_*.sql.gz 2>/dev/null | wc -l | tr -d ' ')
DURATION=$(( $(date +%s) - START_EPOCH ))
STATUS_FILE="$STATUS_DIR/${ENV_NAME}.json"
jq -n \
  --arg env "$ENV_NAME" \
  --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg last_backup "$TIMESTAMP" \
  --argjson last_backup_size "$DB_SIZE" \
  --argjson files_count "$FILE_COUNT" \
  --argjson disk_total "$DISK_TOTAL" \
  --argjson disk_used "$DISK_USED" \
  --argjson total_backups "$TOTAL_BACKUPS" \
  --argjson duration_seconds "$DURATION" \
  --arg snapshot "$SNAP_NAME" \
  '{
    env: $env,
    updated_at: $updated,
    last_backup: $last_backup,
    last_backup_size: $last_backup_size,
    files_count: $files_count,
    disk_total: $disk_total,
    disk_used: $disk_used,
    total_backups: $total_backups,
    duration_seconds: $duration_seconds,
    snapshot: $snapshot,
    ok: true
  }' > "$STATUS_FILE"
log "Status file updated: $STATUS_FILE"

# --- prune ---
ls -1t "$BACKUP_ROOT"/db_*.sql.gz 2>/dev/null | tail -n +"$((RETENTION + 1))" | while read -r old; do
  rm -f "$old" "${old}.gpg" 2>/dev/null || true
  base=$(basename "$old" .sql.gz)
  ts=${base#db_}
  rm -rf "$BACKUP_ROOT/wp-content-$ts" "$BACKUP_ROOT/files-$ts" 2>/dev/null || true
done

# --- encrypt (best-effort after status) ---
if [[ -n "${GPG_PASSPHRASE_FILE:-}" && -f "${GPG_PASSPHRASE_FILE}" ]]; then
  gpg --batch --yes --symmetric --cipher-algo AES256 \
    --passphrase-file "$GPG_PASSPHRASE_FILE" \
    -o "${DB_FILE}.gpg" "$DB_FILE" \
    && log "Encrypted: ${DB_FILE}.gpg" \
    || log "WARN: GPG encrypt failed"
fi

log "=== snapshot complete in ${DURATION}s ==="
flock -u 9
rm -f "$LOCK_FILE"
