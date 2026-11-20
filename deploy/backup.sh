#!/usr/bin/env bash
set -euo pipefail

SUPABASE_DIR="${SUPABASE_DIR:-/opt/my-block-supabase}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/my-block}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
docker compose -f "$SUPABASE_DIR/docker-compose.yml" -f "$SUPABASE_DIR/docker-compose.my-block.yml" \
  exec -T db pg_dump -U postgres -d postgres --format=custom \
  > "$BACKUP_DIR/postgres-$STAMP.dump"

find "$BACKUP_DIR" -type f -name 'postgres-*.dump' -mtime +14 -delete
echo "Created $BACKUP_DIR/postgres-$STAMP.dump"
