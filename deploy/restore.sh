#!/usr/bin/env bash
set -euo pipefail

SUPABASE_DIR="${SUPABASE_DIR:-/opt/my-block-supabase}"
BACKUP_FILE="${1:-}"

if [[ -z "$BACKUP_FILE" || ! -f "$BACKUP_FILE" ]]; then
  echo "Usage: sudo BACKUP_FILE=/path/to/postgres.dump bash deploy/restore.sh"
  echo "       sudo bash deploy/restore.sh /path/to/postgres.dump"
  exit 1
fi

read -r -p "This replaces the current database. Type RESTORE to continue: " CONFIRM
[[ "$CONFIRM" == "RESTORE" ]] || { echo "Restore cancelled."; exit 1; }

docker compose -f "$SUPABASE_DIR/docker-compose.yml" -f "$SUPABASE_DIR/docker-compose.my-block.yml" \
  exec -T db pg_restore -U postgres -d postgres --clean --if-exists --no-owner \
  < "$BACKUP_FILE"
echo "Restore completed from $BACKUP_FILE"
