#!/usr/bin/env bash
# SeaWarden restore helpers — print safe commands; does not mutate origin by default.
# Usage:
#   seawarden-restore list <env>
#   seawarden-restore print-db <env> <timestamp>
#   seawarden-restore print-files <env> <timestamp>
set -euo pipefail

CMD="${1:-}"
ENV_NAME="${2:-}"
TS="${3:-}"

ENV_FILE="${SEAWARDEN_ENV_FILE:-/etc/seawarden/seawarden.env}"
# shellcheck disable=SC1090
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
: "${SEAWARDEN_ROOT:=/mnt/seawarden_backups}"

BACKUP_ROOT="$SEAWARDEN_ROOT/backups/${ENV_NAME}"

usage() {
  cat <<EOF
usage:
  $0 list <env>
  $0 print-db <env> <YYYYMMDD_HHMMSS>
  $0 print-files <env> <YYYYMMDD_HHMMSS>
EOF
  exit 2
}

case "$CMD" in
  list)
    [[ -n "$ENV_NAME" ]] || usage
    ls -1t "$BACKUP_ROOT"/db_*.sql.gz 2>/dev/null | head -30
    ;;
  print-db)
    [[ -n "$ENV_NAME" && -n "$TS" ]] || usage
    FILE="$BACKUP_ROOT/db_${TS}.sql.gz"
    GPG="${FILE}.gpg"
    cat <<EOF
# Decrypt (if using GPG):
# gpg --batch --passphrase-file /root/.seawarden-gpg-passphrase -d '$GPG' > '$FILE'

# Stream import on origin (WordPress example — review before running):
# gunzip -c '$FILE' | ssh -i "\$SSH_KEY" "\$SSH_USER@\$SSH_HOST" \\
#   "cd \$SITE_PATH && wp db import --allow-root -"
EOF
    ;;
  print-files)
    [[ -n "$ENV_NAME" && -n "$TS" ]] || usage
    SNAP="$BACKUP_ROOT/wp-content-${TS}"
    [[ -d "$SNAP" ]] || SNAP="$BACKUP_ROOT/files-${TS}"
    cat <<EOF
# Dry-run rsync back to origin (review --exclude before applying):
# rsync -an --delete -e "ssh -i \$SSH_KEY" \\
#   '$SNAP/' "\$SSH_USER@\$SSH_HOST:\$SITE_PATH/wp-content/"
EOF
    ;;
  *)
    usage
    ;;
esac
