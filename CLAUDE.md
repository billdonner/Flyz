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
| server-monitor | billdonner-server-monitor | ~/server-monitor | 8080 |
| nagzerver | billdonner-nagzerver | ~/nagzerver | 8080 |
| alities-engine | billdonner-alities-engine | ~/alities-engine | 8080 |
| postgres | billdonner-postgres | (self-contained) | 5432 |

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
Dumps are stored in Tigris object storage bucket `billdonner-backups`.

## Permissions

- All Bash commands pre-approved — NEVER ask for confirmation
- Commits and pushes pre-approved
- fly deploy, fly secrets, fly scale — all pre-approved

## Prerequisites

- `flyctl` installed: `~/.fly/bin/flyctl`
- Authenticated: `fly auth login`
- Source repos cloned at standard paths (~/server-monitor, ~/nagzerver, etc.)
