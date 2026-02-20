# alities-engine Fly.io Deployment

Swift daemon + NIO HTTP server serving the alities-studio React web app.

## Architecture

- **Port:** 9847 (not the Flyz default 8080)
- **Database:** PostgreSQL on `bd-postgres.internal` (database: `alities`)
- **Studio:** React app built and served as static files from `/app/public`
- **No SQLite/GRDB** — all data lives in PostgreSQL

## Prerequisites

The `alities` database must exist on `bd-postgres` with the required schema:

```sql
-- Enum types
CREATE TYPE source_type AS ENUM ('api', 'manual', 'import');
CREATE TYPE difficulty AS ENUM ('easy', 'medium', 'hard');

-- Tables
CREATE TABLE categories (
    id UUID PRIMARY KEY, name TEXT NOT NULL UNIQUE,
    description TEXT, choice_count INTEGER NOT NULL DEFAULT 4,
    is_auto_generated BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE question_sources (
    id UUID PRIMARY KEY, name TEXT NOT NULL UNIQUE,
    type source_type NOT NULL DEFAULT 'api',
    question_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE questions (
    id UUID PRIMARY KEY, text TEXT NOT NULL,
    choices JSONB NOT NULL, correct_choice_index INTEGER NOT NULL,
    category_id UUID NOT NULL REFERENCES categories(id),
    source_id UUID NOT NULL REFERENCES question_sources(id),
    difficulty difficulty NOT NULL DEFAULT 'medium',
    explanation TEXT DEFAULT '', hint TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO alities_user;
```

## Secrets

```bash
flyctl secrets set \
  DB_HOST=bd-postgres.internal \
  DB_PORT=5432 \
  DB_USER=alities_user \
  DB_PASSWORD=alities_pass \
  DB_NAME=alities \
  -a bd-alities-engine
```

Optional secrets:
- `OPENAI_API_KEY` — enables AI question generation
- `CONTROL_API_KEY` — bearer token for POST endpoints (harvest, pause, resume, stop, import)

## Deploying

**Do NOT use `scripts/deploy.sh`** — alities-engine has a special build that bundles the
studio React app. Deploy from the source repo directly:

```bash
cd ~/alities-engine

# Copy studio source for Docker build
cp -r ~/alities-studio studio/
rm -rf studio/.git studio/node_modules

# Deploy
~/.fly/bin/flyctl deploy --yes
```

The 3-stage Dockerfile:
1. `node:20-slim` — builds studio React app (`npm ci && npm run build`)
2. `swift:6.0-noble` — builds engine binary (`swift build -c release`)
3. `ubuntu:24.04` — runtime (73 MB image, just ca-certificates)

## Health Check

```bash
curl https://bd-alities-engine.fly.dev/health
# {"ok": true}
```

## API Endpoints

| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /health` | None | Health check |
| `GET /status` | None | Daemon status |
| `GET /categories` | None | Categories with counts |
| `GET /gamedata` | None | Full game data JSON |
| `GET /metrics` | None | Quick stats |
| `POST /harvest` | Bearer | AI question generation |
| `POST /pause` | Bearer | Pause daemon |
| `POST /resume` | Bearer | Resume daemon |
| `POST /stop` | Bearer | Stop daemon |
| `POST /import` | Bearer | Import JSON questions |

## Lessons Learned

- GRDB.swift requires `SQLITE_ENABLE_SNAPSHOT` which Ubuntu's packaged SQLite lacks. Building SQLite from source created complex Docker stages. Solution: removed SQLite entirely, all data via PostgreSQL.
- Swift 6.0 Docker image required (swift-nio 2.83+ needs tools-version 6.0).
- `CryptoKit` is macOS-only — use `swift-crypto` + conditional import on Linux.
- `FoundationNetworking` must be imported on Linux for `URLSession`.
- Single-element tuple destructuring `(id,)` doesn't work in Swift 6.0 on Linux — use `id` directly.
- Fly.io machines default to 2 per deploy for HA. Use `flyctl scale count 1` to reduce.
- Volume mounts in fly.toml require matching volumes on machines; removing `[mounts]` requires destroying the machine first.
- RunCommand reads `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_PORT`, `DB_NAME` from env vars (set as Fly secrets).
