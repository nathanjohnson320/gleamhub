import app/database
import database_integration_fixtures as fixtures
import db_test_support
import gleam/json
import gleam/option
import route_test_support

pub fn issue_routes_lifecycle_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let _ = fixtures.seed_org(db, "acme", "owner")
    let assert Ok(_) =
      database.insert_repo(db, "acme", "demo", option.None, "acme/demo.git")

    let create =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/issues",
          token,
          json.object([
            #("title", json.string("Fix login bug")),
            #("description", json.string("Users cannot sign in")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create)
    let assert True = route_test_support.contains(create, "\"number\":1")

    let list =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/issues",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(list)
    let assert True = route_test_support.contains(list, "Fix login bug")

    let detail =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/issues/1",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(detail)
    let assert True = route_test_support.contains(detail, "Fix login bug")

    let comment =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/issues/1/comments",
          token,
          json.object([
            #("body", json.string("I can reproduce this")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(comment)
    let assert True = route_test_support.contains(comment, "I can reproduce this")

    let comments =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/issues/1/comments",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(comments)
    let assert True = route_test_support.contains(comments, "I can reproduce this")

    let close =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/issues/1/close",
          token,
          json.object([]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(close)
    let assert True = route_test_support.contains(close, "\"state\":\"closed\"")

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}
