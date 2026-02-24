#!/bin/bash
# Deploy one or all apps to Fly.io
# Usage: ./scripts/deploy.sh [app-name|all]

set -euo pipefail

FLYZ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLY="$HOME/.fly/bin/flyctl"

# Map app names to source repos
get_source_repo() {
    case "$1" in
        server-monitor)  echo "$HOME/server-monitor" ;;
        nagzerver)       echo "$HOME/nagzerver" ;;
        alities-engine)  echo "$HOME/alities-engine" ;;
        card-engine)     echo "$HOME/card-engine" ;;
        *)               echo "" ;;
    esac
}

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
    elif [[ -n "$(get_source_repo "$app")" ]]; then
        local src
        src="$(get_source_repo "$app")"
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

        # server-monitor co-hosts the advice app
        if [[ "$app" == "server-monitor" && -d "$HOME/adveyes" ]]; then
            echo "Bundling adveyes for Docker build..."
            mkdir -p "$tmpdir/advice_app"
            rsync -a --exclude='.git' --exclude='.venv' --exclude='__pycache__' \
                  "$HOME/adveyes/" "$tmpdir/advice_app/"
        fi

        # alities-engine needs studio source bundled for the Docker build
        if [[ "$app" == "alities-engine" && -d "$HOME/alities-studio" ]]; then
            echo "Bundling alities-studio for Docker build..."
            rsync -a --exclude='.git' --exclude='node_modules' --exclude='dist' \
                  "$HOME/alities-studio/" "$tmpdir/studio/"
        fi

        # nagzerver needs nagz-web source bundled for the Docker build
        if [[ "$app" == "nagzerver" && -d "$HOME/nagz-web" ]]; then
            echo "Bundling nagz-web for Docker build..."
            rsync -a --exclude='.git' --exclude='node_modules' --exclude='dist' \
                  "$HOME/nagz-web/" "$tmpdir/nagz-web/"
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
