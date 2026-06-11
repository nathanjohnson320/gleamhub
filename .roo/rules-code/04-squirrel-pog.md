# Gleamhub — Squirrel + pog database patterns

You are working with Postgres in the Gleamhub `server/` crate.

## Stack

- **dbmate** — SQL migrations in `server/db/migrations/`
- **Squirrel** — codegen from `server/src/sql/*.sql` → `server/src/sql.gleam`
- **pog** — runtime query execution against `pog.Connection`
- **database.gleam** — application data layer (row types, orchestration, domain errors)

## Workflow (always in this order)

1. **Schema change:** new migration
   ```bash
   cd server && npm run db:new add_feature_table
   # edit db/migrations/YYYYMMDDHHMMSS_add_feature_table.sql
   npm run db:up
   ```

2. **Query:** add/edit `src/sql/feature_list.sql` (one query per file, snake_case name = function name)

3. **Regenerate bindings:**
   ```bash
   npm run db:gen:sql
   # CI check: npm run db:gen:sql:check
   ```

4. **Wrap in database.gleam** — map rows to `*Row` types, combine queries, return domain errors

5. **Never hand-edit `src/sql.gleam`** — it is generated and will be overwritten

## Squirrel SQL files

Example `src/sql/orgs_insert.sql`:
```sql
INSERT INTO organizations (slug, name)
VALUES ($1, $2)
RETURNING id::text, slug, name;
```

Conventions:
- `$1`, `$2`, … positional parameters → function args in generated Gleam
- Use `RETURNING` when you need inserted/updated rows
- Cast UUIDs to text in RETURNING for simpler decoding: `id::text`
- File name = generated function name (`orgs_insert` → `sql.orgs_insert/3`)

Squirrel runs via dev-dep: `gleam run -m squirrel` (see `server/package.json`).

## Generated code usage

Generated functions return `Result(pog.Returned(T), pog.QueryError)`.

```gleam
case sql.orgs_insert(db, slug, name) {
  Ok(returned) ->
    case returned.rows {
      [row] -> Ok(row)
      _ -> Error(...)
    }
  Error(e) -> Error(e)
}
```

Access rows via generated record fields matching SQL column aliases.

## database.gleam responsibilities

This is the **only** module route handlers should call for Postgres.

Pattern:
1. Define `pub type FooRow { ... }` matching query columns
2. Define `pub type FooError { ... }` for domain failures
3. Public functions take `pog.Connection` (+ args)
4. Call `sql.*` functions internally
5. Map `pog.QueryError` / empty rows to `Result(FooRow, FooError)` or similar
6. Multi-step operations (insert org + insert owner member) happen here

Example orchestration (orgs):
```gleam
case sql.orgs_insert(db, slug, name) {
  Ok(returned) ->
    case returned.rows {
      [row] -> {
        let assert Ok(org_uuid) = uuid.from_string(row.id)
        case sql.org_members_insert(db, org_uuid, owner_id, "owner") {
          Ok(_) -> Ok(OrgRow(...))
          Error(e) -> Error(e)
        }
      }
      _ -> ...
    }
  ...
}
```

## Migrations

- Timestamped files in `db/migrations/`
- Dev DB: docker compose postgres :5432
- Test DB: `docker-compose.test.yml` :5433, database `gleamhub_test`
- `gleam test` runs migrations automatically via test harness

## Connection access

- Pool started in `server.gleam` with named connection
- Handlers get `ctx.repo()` — one connection per request operation
- Pass `db` explicitly in tests and `database.gleam` functions

## List/filter queries

Shared list filtering: `database/list_filter.gleam`, `http/list_query.gleam` — follow for paginated/sorted API lists.

## UUIDs

- DB uses UUID columns; often exposed as strings in API
- `youid/uuid` for parsing/generation in Gleam

## Testing database code

- Integration tests use real Postgres (`db_test_support.with_db`)
- Fixtures: `database_integration_fixtures.gleam`
- Seed data via `database.*` functions, not raw SQL in tests

## Checklist for new persisted feature

- [ ] dbmate migration
- [ ] Squirrel SQL file(s)
- [ ] `npm run db:up && npm run db:gen:sql`
- [ ] Row types + functions in `database.gleam`
- [ ] Encoders in `json/api.gleam`
- [ ] Integration test with `db_test_support`

## Anti-patterns

- SQL strings in route handlers or `database.gleam` outside `sql.*` calls
- Editing generated `sql.gleam`
- Skipping migration for schema changes
- Using Ecto/Phoenix terminology or patterns
