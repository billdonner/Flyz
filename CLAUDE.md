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
| alities-engine | bd-alities-engine | ~/alities-engine | 9847 | Swift 6.0 NIO |
| obo-server | bd-obo-server | ~/obo-server | 8080 | Python/FastAPI |
| postgres | bd-postgres | (self-contained) | 5432 | PostgreSQL 16 |

## Public URLs

| App | URL |
|-----|-----|
| server-monitor | https://bd-server-monitor.fly.dev |
| nagzerver | https://bd-nagzerver.fly.dev |
| alities-engine | https://bd-alities-engine.fly.dev |
| obo-server | https://bd-obo-server.fly.dev |

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

### alities-engine special steps

alities-engine has a 3-stage Docker build that bundles the alities-studio React app.
**Do NOT use `deploy.sh`** — deploy from the source repo directly:

```bash
cd ~/alities-engine
cp -r ~/alities-studio studio/
rm -rf studio/.git studio/node_modules
~/.fly/bin/flyctl deploy --yes
```

The `--yes` flag is required for non-interactive deployment.
See `apps/alities-engine/README.md` for full details including DB schema setup.

## PostgreSQL

Shared Postgres instance at `bd-postgres` serves all apps via internal networking.

| Database | User | App |
|----------|------|-----|
| nagz | nagz_user | nagzerver |
| obo | obo_user | obo-server |
| alities | alities_user | alities-engine |

Internal hostname: `bd-postgres.internal:5432`

### Connecting from apps

Apps connect via Fly.io internal DNS. Set these secrets on each app:

```bash
flyctl secrets set -a bd-alities-engine \
  DB_HOST=bd-postgres.internal \
  DB_PORT=5432 \
  DB_USER=alities_user \
  DB_PASSWORD=alities_pass \
  DB_NAME=alities
```

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

See `apps/alities-engine/README.md` "Lessons Learned" section for Swift/Fly.io deployment gotchas.

Common issues:
- **Volume mismatch:** If fly.toml removes `[mounts]` but machine has a volume, destroy the machine first: `flyctl machine destroy <id> --force -a <app>`
- **Lease held:** Wait for the lease to expire (usually 2-5 min) before retrying operations.
- **2 machines created:** `flyctl deploy` creates 2 machines by default for HA. Use `flyctl scale count 1 -a <app>` if you only want 1.
- **Health check failures:** Check `flyctl logs -a <app>` for startup errors. Common: missing DB connection, wrong port.
