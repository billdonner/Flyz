# Flyz — Fly.io Infrastructure Repo

Central repo for all Fly.io deployment configs, scripts, and ops automation.

## Structure

| Directory | Purpose |
|-----------|---------|
| `apps/` | Per-app fly.toml, Dockerfile, and config |
| `scripts/` | Deploy, backup, restore, status scripts |
| `.claude/commands/` | Claude Code skills (/deploy, /fly-status) |

## Apps

| App | Fly Name | Source Repo | Port | Runtime |
|-----|----------|-------------|------|---------|
| server-monitor | bd-server-monitor | ~/server-monitor | 8080 | Python/FastAPI |
| nagzerver | bd-nagzerver | ~/nagzerver | 8080 | Python/FastAPI |
| card-engine | bd-card-engine | ~/card-engine | 8080 | Python/FastAPI |
| postgres | bd-postgres | (self-contained) | 5432 | PostgreSQL 16 |

### Retired Apps

| App | Fly Name | Replaced By |
|-----|----------|-------------|
| ~~alities-engine~~ | ~~bd-alities-engine~~ | card-engine |
| ~~obo-server~~ | ~~bd-obo-server~~ | card-engine |

## Public URLs

| App | URL |
|-----|-----|
| server-monitor | https://bd-server-monitor.fly.dev |
| nagzerver | https://bd-nagzerver.fly.dev |
| card-engine | https://bd-card-engine.fly.dev |

## Deploying

```bash
# Deploy a single app
./scripts/deploy.sh server-monitor

# Deploy all apps
./scripts/deploy.sh all

# Check status across all apps
./scripts/status.sh
```

### nagzerver bundling

The nagzerver Dockerfile is a multi-stage build that bundles the nagz-web React app.
`deploy.sh` automatically copies `~/nagz-web` into the build context. The Node stage
builds the React app with `VITE_API_URL=""` (same-origin), and the output is served
at `/` by the FastAPI server.

### card-engine

card-engine has its own `fly.toml` and `Dockerfile` in `~/card-engine/`. Deploy directly:

```bash
cd ~/card-engine && fly deploy
```

## PostgreSQL

Shared Postgres instance at `bd-postgres` serves all apps via internal networking.

| Database | User | App |
|----------|------|-----|
| nagz | nagz_user | nagzerver |
| card_engine | (via CE_DATABASE_URL secret) | card-engine |

Internal hostname: `bd-postgres.internal:5432`

### Direct access via proxy

```bash
~/.fly/bin/flyctl proxy 15432:5432 -a bd-postgres
psql -h localhost -p 15432 -U postgres
```

### SSH into postgres

```bash
~/.fly/bin/flyctl ssh console -a bd-postgres
su - postgres
psql
```

## Backups

Postgres backups run daily via `scripts/backup-postgres.sh`.
Dumps are stored in Tigris object storage bucket `bd-backups`.

## Prerequisites

- `flyctl` installed at `~/.fly/bin/flyctl` (NOT in global PATH)
- Authenticated: `~/.fly/bin/flyctl auth login`
- Source repos cloned at standard paths (~/server-monitor, ~/nagzerver, etc.)

## Troubleshooting

Common issues:
- **Volume mismatch:** If fly.toml removes `[mounts]` but machine has a volume, destroy the machine first: `flyctl machine destroy <id> --force -a <app>`
- **Lease held:** Wait for the lease to expire (usually 2-5 min) before retrying operations.
- **2 machines created:** `flyctl deploy` creates 2 machines by default for HA. Use `flyctl scale count 1 -a <app>` if you only want 1.
- **Health check failures:** Check `flyctl logs -a <app>` for startup errors. Common: missing DB connection, wrong port.
