# Gleamhub — testing patterns

## Server tests (`cd server && gleam test`)

**Requires Docker.** Test harness:
1. Starts `docker-compose.test.yml` (Postgres :5433, `gleamhub_test`)
2. Runs dbmate migrations
3. Runs gleeunit suite
4. Tears down container

Filter: `gleam test merge_request_routes_integration_test`

### Integration tests (preferred for routes)

Location: `server/test/*_integration_test.gleam`

Pattern:
```gleam
pub fn feature_lifecycle_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "user-id")

    let resp = route_test_support.dispatch(
      route_test_support.post_json("/api/...", token, json.object([...])),
      ctx,
    )
    let assert 201 = route_test_support.status(resp)
  })
}
```

Helpers in `route_test_support.gleam`:
- `authenticated/2` — test JWT sign/verify keys in Context
- `bearer_token/2`, `get/2`, `post_json/3`, `dispatch/2`
- `status/1`, `contains/2`, JSON body helpers

Fixtures:
- `database_integration_fixtures.gleam` — seed orgs/users
- `route_test_support.seed_git_repo` patterns — clone fixture, insert repo row

Git tests use real bare repos under `/tmp/gleamhub_route_*`.

### Unit tests

Pure logic modules: list filters, parsers, policies, URL helpers.

Use `wisp/simulate` for query parsing tests (`list_query_test.gleam`).

### SQL codegen check

CI runs `npm run db:gen:sql:check` — commit regenerated `sql.gleam` when changing SQL files.

## UI tests (`cd ui && gleam test`)

No Docker. Fast unit tests only.

Focus:
- `routes_test.gleam` — URL ↔ Route parsing, path helpers
- Decoder tests for `http/api.gleam` if complex
- Pure helpers: diff, conflict, search query, time format

Do **not** browser-test or hit real API from UI tests.

## common tests

```bash
cd common && gleam test
```

Minimal — expand when shared logic grows.

## ci-worker tests

```bash
cd ci-worker && gleam test
```

Mock HTTP where possible; follow `ci_worker_test.gleam`.

## What to test for a new feature

| Layer | Test type |
|-------|-----------|
| New API route | Integration test: auth, happy path, key error cases |
| New SQL/query | Covered by integration test through database layer |
| New Route parser | UI unit test in `routes_test.gleam` |
| New JSON decoder | UI unit test with sample JSON |
| Pure parser/policy | Direct unit test |

## Test naming

`pub fn thing_scenario_test()` — gleeunit discovers `*_test` modules.

## Anti-patterns

- Skipping integration tests for new `/api/*` routes
- Hitting production Clerk or Postgres in tests
- `gleam test` in server without Docker running
- Tests that depend on execution order across modules
