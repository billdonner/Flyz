#!/bin/bash
# Tail logs from a Fly.io app
# Usage: ./scripts/logs.sh <app-name>

set -euo pipefail

FLYZ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLY="$HOME/.fly/bin/flyctl"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <app-name>"
    echo ""
    echo "Available apps:"
    for d in "$FLYZ_DIR"/apps/*/; do
        echo "  $(basename "$d")"
    done
    exit 1
fi

app="$1"
fly_toml="$FLYZ_DIR/apps/$app/fly.toml"

if [[ ! -f "$fly_toml" ]]; then
    echo "ERROR: No fly.toml at $fly_toml"
    exit 1
fi

fly_app=$(grep "^app = " "$fly_toml" | sed "s/app = '//;s/'//")
$FLY logs --app "$fly_app"
