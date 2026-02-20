#!/bin/bash
# Restore Postgres from a Tigris backup
# Usage: ./scripts/restore-postgres.sh [backup-filename]
#
# Lists available backups if no filename given.

set -euo pipefail

FLY="$HOME/.fly/bin/flyctl"
PG_APP="billdonner-postgres"
BUCKET="billdonner-backups"

if [[ $# -lt 1 ]]; then
    echo "Available backups:"
    aws s3 ls "s3://$BUCKET/postgres/" \
        --endpoint-url "https://fly.storage.tigris.dev" | \
        awk '{print "  " $4 " (" $3 " bytes, " $1 " " $2 ")"}'
    echo ""
    echo "Usage: $0 <backup-filename>"
    echo "Example: $0 20260219-030000.sql.gz"
    exit 1
fi

BACKUP_FILE="$1"
LOCAL="/tmp/pg-restore-$BACKUP_FILE"

echo "=== Restoring from $BACKUP_FILE ==="

# Download
echo "Downloading from Tigris..."
aws s3 cp "s3://$BUCKET/postgres/$BACKUP_FILE" "$LOCAL" \
    --endpoint-url "https://fly.storage.tigris.dev"

# Proxy
echo "Starting Fly proxy..."
$FLY proxy 15432:5432 --app "$PG_APP" &
PROXY_PID=$!
sleep 3

# Restore
echo "Restoring databases..."
gunzip -c "$LOCAL" | psql -h localhost -p 15432 -U postgres

# Cleanup
kill $PROXY_PID 2>/dev/null || true
rm -f "$LOCAL"

echo "=== Restore complete ==="
