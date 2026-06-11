import database
import database_integration_fixtures as fixtures
import db_test_support
import gleam/json
import gleam/option
import gleam/string
import route_test_support

pub fn milestone_routes_lifecycle_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let _ = fixtures.seed_org(db, "acme", "owner")
    let assert Ok(_) =
      database.insert_repo(db, "acme", "demo", option.None, "acme/demo.git")

    let empty =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/milestones",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(empty)
    let assert True =
      route_test_support.contains(empty, "\"milestones\":[]")

    let created =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/milestones",
          token,
          json.object([
            #("title", json.string("v1.0")),
            #("description", json.string("First release milestone")),
            #("due_on", json.string("2026-12-31")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(created)
    let assert True = route_test_support.contains(created, "\"number\":1")
    let assert True = route_test_support.contains(created, "open_issues")
    let milestone_id = extract_string_field(route_test_support.body(created), "id")

    let detail =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/milestones/1",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(detail)
    let assert True = route_test_support.contains(detail, "First release milestone")

    let issue =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/issues",
          token,
          json.object([
            #("title", json.string("Ship feature")),
            #("description", json.null()),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(issue)

    let invalid =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/repos/demo/issues/1",
          token,
          json.object([
            #("milestone_id", json.string("00000000-0000-0000-0000-000000000000")),
          ]),
        ),
        ctx,
      )
    let assert 400 = route_test_support.status(invalid)

    let assigned =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/repos/demo/issues/1",
          token,
          json.object([#("milestone_id", json.string(milestone_id))]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(assigned)
    let assert True = route_test_support.contains(assigned, "\"milestone\"")

    let filtered =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/issues?milestone=1&state=all",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(filtered)
    let assert True = route_test_support.contains(filtered, "Ship feature")

    let cleared =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/repos/demo/issues/1",
          token,
          json.object([#("milestone_id", json.null())]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(cleared)

    let updated =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/repos/demo/milestones/1",
          token,
          json.object([
            #("title", json.string("Version 1.0")),
            #("description", json.string("Updated milestone")),
          ]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(updated)
    let assert True = route_test_support.contains(updated, "Version 1.0")

    let closed =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/milestones/1/close",
          token,
          json.object([]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(closed)
    let assert True = route_test_support.contains(closed, "\"state\":\"closed\"")

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

fn extract_string_field(body: String, field: String) -> String {
  let pattern = "\"" <> field <> "\":\""
  case string.split(body, on: pattern) {
    [_, rest, ..] ->
      case string.split(rest, on: "\"") {
        [value, ..] -> value
        _ -> ""
      }
    _ -> ""
  }
}
