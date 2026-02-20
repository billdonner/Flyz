# Flyz — Fly.io Infrastructure Repo

Central repo for all Fly.io deployment configs, scripts, and ops automation.

## Structure

| Directory | Purpose |
|-----------|---------|
| `apps/` | Per-app fly.toml, Dockerfile, and config |
| `scripts/` | Deploy, backup, restore, status scripts |
| `.claude/commands/` | Claude Code skills (/deploy, /fly-status) |

## Apps

| App | Fly Name | Source Repo | Port |
|-----|----------|-------------|------|
| server-monitor | bd-server-monitor | ~/server-monitor | 8080 |
| nagzerver | bd-nagzerver | ~/nagzerver | 8080 |
| alities-engine | bd-alities-engine | ~/alities-engine | 8080 |
| obo-server | bd-obo-server | ~/obo-server | 8080 |
| postgres | bd-postgres | (self-contained) | 5432 |

## Deploying

```bash
# Deploy a single app
./scripts/deploy.sh server-monitor

# Deploy all apps
./scripts/deploy.sh all

# Check status across all apps
./scripts/status.sh
```

## Backups

Postgres backups run daily via `scripts/backup-postgres.sh`.
Dumps are stored in Tigris object storage bucket `bd-backups`.

## Prerequisites

- `flyctl` installed: `~/.fly/bin/flyctl`
- Authenticated: `fly auth login`
- Source repos cloned at standard paths (~/server-monitor, ~/nagzerver, etc.)
