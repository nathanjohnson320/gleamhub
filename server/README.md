# server

Gleamhub HTTP API: Wisp + Postgres (pog), Clerk JWT auth, git browse/MR/issue routes, internal SSH and CI endpoints.

## Quick start

From the repo root, follow [README.md](../README.md). For server-only work after Postgres is up:

```bash
cd server
cp .env.example .env   # if needed
npm install
npm run db:up
gleam run
```

Listens on **http://localhost:9999** by default (`PORT` in `.env`).

## Tests

```bash
cd server
npm install    # once - dbmate for migrations
gleam test
```

`gleam test` **requires Docker**. It automatically:

1. Starts Postgres from `../docker-compose.test.yml` on port **5433**
2. Runs `dbmate up` against database `gleamhub_test`
3. Runs the full test suite
4. Stops the container when finished

If Docker is not running, the run fails immediately with an error message.

Filter by module name:

```bash
gleam test merge_request_routes_integration_test
```

## Database workflow

SQL migrations live in `db/migrations/`. After editing squirrel query files in `src/sql/`:

```bash
npm run db:up          # apply migrations (dev DB)
npm run db:gen:sql     # regenerate pog query bindings (squirrel)
npm run db:gen:sql:check   # CI-style check that generated SQL is up to date
```

Dev Postgres is started by `docker compose up postgres` from the repo root (port **5432**).

## Static UI

Production-style bundle: build the UI from `../ui` (`npm run build`), which writes to `priv/static/`. The server serves the SPA for non-API routes.

## Layout

| Path | Role |
|------|------|
| `src/http/` | Router, Wisp entry, middleware, Clerk auth, REST handlers (orgs, repos, MRs, issues) |
| `src/git/` | Git exec/path/URL helpers and browse, settings, SSH internal routes |
| `src/ci/` | Pipeline discovery, enqueue, long-poll, SSE events, internal CI routes |
| `src/json/` | JSON response encoders for API payloads |
| `src/database.gleam` | Postgres access layer |
| `src/sql/` | Squirrel SQL queries (generated `sql.gleam`) |
| `test/` | Unit and integration tests |

See [README.md](../README.md) for the full API list and [docs/ci-platform.md](../docs/ci-platform.md) for CI internals.
