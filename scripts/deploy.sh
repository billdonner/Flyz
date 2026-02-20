#!/bin/bash
# Deploy one or all apps to Fly.io
# Usage: ./scripts/deploy.sh [app-name|all]

set -euo pipefail

FLYZ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLY="$HOME/.fly/bin/flyctl"

# Map app names to source repos
declare -A SOURCE_REPOS=(
    [server-monitor]="$HOME/server-monitor"
    [nagzerver]="$HOME/nagzerver"
    [alities-engine]="$HOME/alities-engine"
)

deploy_app() {
    local app="$1"
    local app_dir="$FLYZ_DIR/apps/$app"
    local fly_toml="$app_dir/fly.toml"

    if [[ ! -f "$fly_toml" ]]; then
        echo "ERROR: No fly.toml found at $fly_toml"
        return 1
    fi

    echo "=== Deploying $app ==="

    if [[ "$app" == "postgres" ]]; then
        # Postgres deploys from its own directory
        cd "$app_dir"
        $FLY deploy --config "$fly_toml"
    elif [[ -n "${SOURCE_REPOS[$app]:-}" ]]; then
        local src="${SOURCE_REPOS[$app]}"
        if [[ ! -d "$src" ]]; then
            echo "ERROR: Source repo not found at $src"
            return 1
        fi

        # Create temp build context: source repo + Fly config overlay
        local tmpdir
        tmpdir=$(mktemp -d)
        trap "rm -rf $tmpdir" EXIT

        # Copy source repo
        rsync -a --exclude='.git' --exclude='.venv' --exclude='__pycache__' \
              --exclude='.build' --exclude='DerivedData' \
              "$src/" "$tmpdir/"

        # Overlay Fly-specific files
        cp "$app_dir/Dockerfile" "$tmpdir/Dockerfile"
        if [[ -d "$app_dir/config" ]]; then
            mkdir -p "$tmpdir/fly-config"
            cp "$app_dir/config/"* "$tmpdir/fly-config/"
        fi

        # Deploy from temp context
        cd "$tmpdir"
        $FLY deploy --config "$fly_toml" --remote-only

        rm -rf "$tmpdir"
        trap - EXIT
    else
        echo "ERROR: Unknown app '$app'"
        return 1
    fi

    echo "=== $app deployed ==="
    echo ""
}

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 [app-name|all]"
    echo ""
    echo "Available apps:"
    for d in "$FLYZ_DIR"/apps/*/; do
        echo "  $(basename "$d")"
    done
    exit 1
fi

if [[ "$1" == "all" ]]; then
    for d in "$FLYZ_DIR"/apps/*/; do
        app=$(basename "$d")
        deploy_app "$app" || echo "WARN: $app failed, continuing..."
    done
else
    deploy_app "$1"
fi
