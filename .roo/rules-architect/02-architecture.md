# Gleamhub architecture (for agents)

## Request flow — server

```
mist (TCP) → http/entry.gleam (Wisp connection adapter)
          → router.handle_request (path dispatch)
          → web.middleware (CORS, static, logging, crash rescue)
          → clerk.middleware / internal_auth.with_token
          → *\_routes.gleam handler
          → database.gleam / git/exec.gleam / json/api.gleam
```

**Special case:** MR pipeline SSE (`/api/.../pipeline/stream`) bypasses normal Wisp response path and is handled in `http/entry.gleam` via Mist `server_sent_events`, with auth in `ci/stream_routes.gleam`.

**Boot:** `server/src/server.gleam` — `static_supervisor` (RestForOne) supervises:
1. `pog` connection pool
2. `ci/events` pub/sub actor (SSE fan-out)
3. Mist HTTP listener

## Request flow — UI

```
main.js (Clerk bootstrap) → ui.gleam main()
  → lustre.application(init, update, view)
  → modem.init (URL → Route)
  → pages/* (per-area Model/Msg/update/view)
  → http/lustre_http (Effect-based fetch + JWT)
  → http/api.gleam (decoders + URL builders)
```

App shell (`ui/src/ui.gleam`) owns top-level `Model`, `Msg`, and dispatches to page modules via tagged messages (`OrgsMsg`, `MrDetailMsg`, …).

## Module map — server

| Directory / file | Responsibility |
|------------------|----------------|
| `src/http/router.gleam` | Path segment dispatch; SPA fallback for UI routes |
| `src/http/web.gleam` | `Context`, CORS, middleware stack |
| `src/http/clerk.gleam` | JWT verify, upsert user, attach `user_id` to context |
| `src/http/*_routes.gleam` | Feature handlers (orgs, MRs, issues, labels, …) |
| `src/http/internal_auth.gleam` | Token gate for `/internal/*` |
| `src/git/*` | Git subprocess (`exec`), paths, browse/settings/tag routes, SSH internal |
| `src/ci/*` | Pipeline discovery, enqueue, long-poll API, SSE events |
| `src/database.gleam` | All Postgres access; wraps `sql.*` generated functions |
| `src/sql/*.sql` | Squirrel query source (one file per query) |
| `src/sql.gleam` | **Generated** — do not hand-edit |
| `src/json/api.gleam` | JSON encoders for API responses |
| `db/migrations/` | dbmate SQL migrations |

## Module map — UI

| Path | Responsibility |
|------|----------------|
| `src/routes.gleam` | `Route` ADT, `from_uri`, path helpers |
| `src/ui.gleam` | App shell, route → page dispatch, Clerk session |
| `src/pages/*.gleam` | Feature pages: `Model`, `Msg`, `init`, `on_load`, `update`, `view` |
| `src/http/api.gleam` | API types + `decode.*` decoders |
| `src/http/lustre_http.gleam` | Authenticated GET/POST/PATCH/DELETE as `Effect`s |
| `src/components.gleam` | Shared layout/widgets |
| `src/auth/` | User type, Clerk session effects |
| `src/ci/` | Pipeline status, log rendering, SSE client |
| `src/diff/` | MR diff view, conflict display |
| `src/content/` | Markdown (FFI to `main.js` highlight.js) |

## Data boundaries

| Data | Storage |
|------|---------|
| Orgs, repos, MRs, issues, CI runs, notifications | Postgres |
| Git objects, branches, tags, file contents | Bare repos on disk (`GIT_REPOS_ROOT`) |
| User identity | Clerk (JWT `sub`); display name cached in `users` table |
| Issue/MR templates | Files in git (`.gleamhub/*`) |

## Internal vs public API

- **`/api/*`** — Clerk JWT; used by UI and could be used by CLI
- **`/internal/*`** — shared secret header; git-ssh hooks and ci-worker only
- **`/raw/orgs/...`** — optional query-token auth for raw downloads

## Adding a feature — typical touch points

### New REST resource (server-only)

1. dbmate migration in `server/db/migrations/`
2. Squirrel SQL in `server/src/sql/`
3. `npm run db:up && npm run db:gen:sql`
4. Functions in `database.gleam` (row types + orchestration)
5. Encoders in `json/api.gleam`
6. Handler in `http/*_routes.gleam`
7. Route in `http/router.gleam`
8. Integration test in `server/test/*_integration_test.gleam`

### Same resource + UI

9. Types + decoders in `ui/src/http/api.gleam`
10. `Route` variant + parsing in `ui/src/routes.gleam`
11. Page module in `ui/src/pages/`
12. Wire into `ui/src/ui.gleam` (Model, Msg, dispatch)
13. UI tests in `ui/test/` if parsing/decoding logic added

## CI pipeline (optional subsystem)

1. post-receive hook → `POST /internal/ci/enqueue`
2. ci-worker long-polls `GET /internal/ci/jobs/next`
3. Worker clones repo, runs Dagger module, patches log via `PATCH /internal/ci/jobs/:id`
4. UI subscribes to SSE for live updates; merge gating reads pipeline status from MR detail API

See `docs/ci-platform.md` for the Dagger contract.

## Environment

Copy `.env.example` files. Critical pairs:
- `CLERK_JWKS_URL` (server) ↔ `VITE_CLERK_PUBLISHABLE_KEY` (ui) — same Clerk app
- `INTERNAL_API_TOKEN` — shared by server, git-ssh, ci-worker
