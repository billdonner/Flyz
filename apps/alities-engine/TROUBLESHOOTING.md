# Alities Engine — Fly.io Deployment Troubleshooting

Lessons learned from deploying the Swift NIO daemon to Fly.io (2026-02-20).

## Architecture

- **3-stage Docker build**: `node:20-slim` (studio) → `swift:6.0-noble` (engine) → `ubuntu:24.04` (runtime)
- **Final image size**: ~75 MB
- **Port**: 9847 (not the default 8080 used by Python apps)
- **Health check**: `GET /health` → `{"ok": true}`
- **Static files**: alities-studio React app served from `/app/public` via `--static-dir`

## Issue: `flyctl` not in PATH

`flyctl` installs to `~/.fly/bin/flyctl`, not a global location.

**Fix**: Always use full path `~/.fly/bin/flyctl` or add `~/.fly/bin` to PATH.

## Issue: `libcurl.so.4` missing at runtime

`--static-swift-stdlib` statically links the Swift standard library, but Foundation on Linux still dynamically links libcurl for HTTP/TLS.

**Fix**: Include `libcurl4` in the runtime stage:
```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libcurl4 \
    && rm -rf /var/lib/apt/lists/*
```

Also need `ca-certificates` for HTTPS connections.

## Issue: Volume mismatch blocking deploy

If fly.toml previously had `[mounts]` but no longer does, Fly.io refuses to deploy to machines that still have volumes attached.

**Fix**:
```bash
# List machines
flyctl machines list -a bd-alities-engine

# Destroy the machine with the stale volume
flyctl machines destroy <machine-id> --force -a bd-alities-engine

# Destroy the orphaned volume
flyctl volumes list -a bd-alities-engine
flyctl volumes destroy <vol-id> -a bd-alities-engine

# Redeploy — creates fresh machine without volume
flyctl deploy --remote-only
```

## Issue: Stale machine leases blocking operations

Failed deploys can leave active leases on machines, preventing destroy/update.

**Fix**:
```bash
flyctl machines leases clear <machine-id> -a bd-alities-engine
```

## Issue: Too many machines created

Fly.io may create 2+ machines per deploy (redundancy). Daemon apps only need 1.

**Fix**:
```bash
flyctl scale count 1 --yes -a bd-alities-engine
```

To check current state:
```bash
flyctl machines list -a bd-alities-engine
```

## Issue: PostgreSQL connection crash on startup

Without a database, the engine would crash. Now it degrades gracefully — health check and static file serving still work.

**Fix (already applied)**: RunCommand.swift catches PostgreSQL connection errors and logs a warning instead of throwing.

## Issue: DB connecting to localhost instead of Fly internal

Environment variables weren't being read for DB config.

**Fix**: RunCommand.swift reads from env vars with fallback defaults:
- `DB_HOST` → defaults to `localhost`
- `DB_PORT` → defaults to `5432`
- `DB_USER` → defaults to `trivia`
- `DB_PASSWORD` → defaults to `trivia`
- `DB_NAME` → defaults to `trivia_db`

Set via Fly secrets:
```bash
flyctl secrets set -a bd-alities-engine \
  DB_HOST=bd-postgres.internal \
  DB_PORT=5432 \
  DB_USER=alities_user \
  DB_PASSWORD=alities_pass \
  DB_NAME=alities
```

## Issue: DNS not resolving immediately

After first deploy, `bd-alities-engine.fly.dev` may not resolve via local DNS right away.

**Fix**: Wait a few minutes, or test with:
```bash
curl --resolve bd-alities-engine.fly.dev:443:66.241.125.146 \
  https://bd-alities-engine.fly.dev/health
```

## Issue: Secrets "Staged" but not "Deployed"

`flyctl secrets set` stages secrets but can't deploy if no machines exist yet.

**Fix**: Deploy first (creates machines), then secrets take effect. Or set secrets before the first deploy — they'll be picked up when machines are created.

## Dockerfile Caching Tip

Separate `swift package resolve` from source copy for better Docker layer caching:
```dockerfile
COPY Package.swift Package.resolved ./
RUN swift package resolve        # cached unless dependencies change
COPY Sources/ Sources/
COPY Tests/ Tests/
RUN swift build -c release --static-swift-stdlib
```

## alities-engine vs Python apps

| Aspect | alities-engine | Python apps |
|--------|---------------|-------------|
| Port | 9847 | 8080 |
| auto_stop_machines | false (daemon) | stop (on-demand) |
| min_machines_running | 1 | 0 |
| Health check | /health (custom) | Default TCP |
| DB connection | postgres-nio (Swift) | psycopg2/asyncpg |
| Static files | Bundled in image | Separate or none |

## Useful Commands

```bash
# Deploy
~/.fly/bin/flyctl deploy --remote-only -a bd-alities-engine

# Logs
~/.fly/bin/flyctl logs -a bd-alities-engine

# SSH into running machine
~/.fly/bin/flyctl ssh console -a bd-alities-engine

# Check secrets
~/.fly/bin/flyctl secrets list -a bd-alities-engine

# Restart machines
~/.fly/bin/flyctl machines restart <machine-id> -a bd-alities-engine

# Scale
~/.fly/bin/flyctl scale count 1 --yes -a bd-alities-engine
```
