#!/bin/bash
# Backup all Postgres databases to Tigris (S3-compatible)
# Usage: ./scripts/backup-postgres.sh
#
# Prerequisites:
#   - flyctl installed and authenticated
#   - Tigris bucket created: fly storage create
#   - AWS CLI configured with Tigris credentials
#
# Schedule via cron or GitHub Actions:
#   0 3 * * * /path/to/Flyz/scripts/backup-postgres.sh

set -euo pipefail

FLY="$HOME/.fly/bin/flyctl"
PG_APP="billdonner-postgres"
BUCKET="billdonner-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/tmp/pg-backup-$TIMESTAMP"

mkdir -p "$BACKUP_DIR"

echo "=== Postgres Backup: $TIMESTAMP ==="

# Proxy Postgres to localhost temporarily
echo "Starting Fly proxy..."
$FLY proxy 15432:5432 --app "$PG_APP" &
PROXY_PID=$!
sleep 3

# Dump all databases
echo "Dumping databases..."
pg_dumpall -h localhost -p 15432 -U postgres | gzip > "$BACKUP_DIR/all-databases.sql.gz"

# Kill proxy
kill $PROXY_PID 2>/dev/null || true

FILESIZE=$(du -h "$BACKUP_DIR/all-databases.sql.gz" | cut -f1)
echo "Backup size: $FILESIZE"

# Upload to Tigris
echo "Uploading to Tigris..."
aws s3 cp "$BACKUP_DIR/all-databases.sql.gz" \
    "s3://$BUCKET/postgres/$TIMESTAMP.sql.gz" \
    --endpoint-url "https://fly.storage.tigris.dev"

# Cleanup old local backups
rm -rf "$BACKUP_DIR"

# Prune remote backups older than 30 days
echo "Pruning backups older than 30 days..."
CUTOFF=$(date -v-30d +%Y%m%d 2>/dev/null || date -d '30 days ago' +%Y%m%d)
aws s3 ls "s3://$BUCKET/postgres/" \
    --endpoint-url "https://fly.storage.tigris.dev" | \
    while read -r line; do
        file=$(echo "$line" | awk '{print $4}')
        file_date=$(echo "$file" | grep -oE '[0-9]{8}' | head -1)
        if [[ -n "$file_date" && "$file_date" < "$CUTOFF" ]]; then
            echo "  Removing old backup: $file"
            aws s3 rm "s3://$BUCKET/postgres/$file" \
                --endpoint-url "https://fly.storage.tigris.dev"
        fi
    done

echo "=== Backup complete ==="
