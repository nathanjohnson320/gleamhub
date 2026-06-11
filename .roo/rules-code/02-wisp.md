# Gleamhub — Wisp / Mist server patterns

You are implementing HTTP API code in the Gleamhub `server/` crate.

## Stack

- **Wisp** — request/response abstraction, middleware, JSON helpers
- **Mist** — actual HTTP server (Wisp runs on Mist via `http/entry.gleam`)
- **pog** — Postgres connection pool (supervised child)
- **Clerk JWT** — `ywt` decode against JWKS keys in `Context`

This is **not** Phoenix. There are no controllers, plugs, or contexts — use route modules + `database.gleam`.

## Layering (strict)

```
router.gleam          → dispatch only
*_routes.gleam        → HTTP concerns: method, auth, parse body/query, status codes
database.gleam        → Postgres: row types, multi-query orchestration
sql/*.sql + sql.gleam → raw queries (generated)
git/exec.gleam        → git subprocess IO
json/api.gleam        → response JSON encoders
```

**Never** put SQL strings or business rules directly in route handlers beyond request parsing and calling `database.*`.

## Context and auth

`http/web.Context` carries:
- `repo: fn() -> pog.Connection` — always call `ctx.repo()` per request
- `user_id: Option(String)` — set by Clerk middleware when authenticated
- `clerk_keys`, `clerk`, `internal_api_token`, git paths, pipeline event name

**Authenticated routes:**
```gleam
use req <- clerk.middleware(req, ctx, fn(ctx) {
  // ctx.user_id is Some(...)
  my_handler(req, ctx)
})
```

**Internal routes** (git-ssh, ci-worker):
```gleam
internal_auth.with_token(req, ctx, fn() {
  ssh_internal_routes.authorized_keys(req, ctx)
})
```

**Optional query-token auth** (raw downloads): `clerk.middleware_allow_query`

## Route handler pattern

Follow existing `*_routes.gleam` files:

```gleam
pub fn create_thing(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json_body <- wisp.require_json(req)
  use ctx <- clerk.middleware(req, ctx, fn(ctx) { Ok(ctx) }) // or ensure_user helper

  // decode body with gleam/json or gleam/dynamic/decode
  // call database.* 
  // return wisp.json_response(json.to_string(...), 201)
}
```

Common helpers in route files:
- `ensure_user(ctx) -> Result(Nil, Response)` — 401 if no user
- `org_access.*` — membership / write checks → 403
- `wisp.not_found()`, `wisp.bad_request(...)`, `wisp.internal_server_error()`

## Router

`http/router.gleam` matches `wisp.path_segments(req)`:
- `["api", "orgs", org, ...]` → feature routes
- `["internal", ...]` → internal auth wrapper
- UI paths → `serve_spa` (static `index.html`)

Add new routes here; keep handlers in dedicated modules.

## Middleware stack

Applied in `web.middleware/3`:
1. `wisp.method_override`
2. CORS (`cors_builder`)
3. `wisp.serve_static` under `/static`
4. `wisp.log_request`
5. `wisp.rescue_crashes`
6. `wisp.handle_head`
7. `default_responses` — HTML fallbacks for empty 4xx bodies

## JSON responses

- **Encode:** `json/api.gleam` functions → `json.to_string` → `wisp.json_response(status)`
- **Decode request:** `wisp.require_json` or manual decode; return `wisp.bad_request` on failure
- Keep API shape stable — UI decoders in `ui/src/http/api.gleam` must match

## Git operations

Use `git/exec.gleam` and `git/path.gleam` — never shell out from route handlers directly.

Browse/settings routes live under `src/git/`. Protected branch checks use `git/ref_update_policy.gleam` via SSH internal routes.

## SSE (pipeline stream)

Do not add new SSE routes through normal Wisp response path. Follow `ci/stream_routes.gleam`:
- Registered in `http/entry.gleam` before generic handler
- Uses Mist `server_sent_events` + `ci/events` pub/sub actor

## Error handling

- Handlers return `wisp.Response` directly for HTTP errors
- Database/git calls return `Result` — map to 4xx/5xx in handler
- Use `let assert` only when failure is truly impossible or should crash in dev

## Env and boot

- Config via `envie` in `server.gleam`; `envie.load_override()` prefers `server/.env`
- Do not read env vars scattered in handlers — extend `Context` if new config is needed

## Checklist for new API endpoint

- [ ] Route in `router.gleam`
- [ ] Handler module with method + auth guards
- [ ] `database.gleam` function(s)
- [ ] SQL in `src/sql/` if new queries needed (+ regenerate)
- [ ] Encoder in `json/api.gleam`
- [ ] Integration test using `route_test_support`
- [ ] Document in root README API table if user-facing
