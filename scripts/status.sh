#!/bin/bash
# Show status of all Fly.io apps
# Usage: ./scripts/status.sh

set -euo pipefail

FLYZ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLY="$HOME/.fly/bin/flyctl"

echo "App                          | Status    | Region | Machines"
echo "-----------------------------|-----------|--------|----------"

for d in "$FLYZ_DIR"/apps/*/; do
    app=$(basename "$d")
    fly_toml="$d/fly.toml"

    if [[ ! -f "$fly_toml" ]]; then
        continue
    fi

    # Extract app name from fly.toml
    fly_app=$(grep "^app = " "$fly_toml" | sed "s/app = '//;s/'//")

    # Get status
    status=$($FLY status --app "$fly_app" --json 2>/dev/null) || {
        printf "%-28s | %-9s | %-6s | %s\n" "$app" "not found" "-" "-"
        continue
    }

    app_status=$(echo "$status" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Status','unknown'))" 2>/dev/null || echo "unknown")
    region=$(echo "$status" | python3 -c "import sys,json; d=json.load(sys.stdin); ms=d.get('Machines',[]); print(ms[0]['region'] if ms else '-')" 2>/dev/null || echo "-")
    machines=$(echo "$status" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('Machines',[])))" 2>/dev/null || echo "0")

    printf "%-28s | %-9s | %-6s | %s\n" "$app" "$app_status" "$region" "$machines"
done
