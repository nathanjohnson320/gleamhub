import db_test_support
import gleam/json
import gleam/option
import route_test_support

pub fn router_serves_spa_for_ui_routes_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, _sign) = route_test_support.authenticated(db, root)
    let res =
      route_test_support.dispatch(
        route_test_support.get("/orgs/acme/repos/demo", option.None),
        ctx,
      )
    let assert 200 = route_test_support.status(res)
    let assert True = route_test_support.contains(res, "<html")
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn router_api_not_found_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "user_1")
    let res =
      route_test_support.dispatch(
        route_test_support.get("/api/does-not-exist", option.Some(token)),
        ctx,
      )
    let assert 404 = route_test_support.status(res)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn router_method_not_allowed_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "user_1")
    let res =
      route_test_support.dispatch(
        route_test_support.post_json("/api/me", token, json.object([])),
        ctx,
      )
    let assert 405 = route_test_support.status(res)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn router_cors_preflight_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, _sign) = route_test_support.authenticated(db, root)
    let res =
      route_test_support.dispatch(
        route_test_support.options("/api/me", "http://localhost:5173"),
        ctx,
      )
    let assert 204 = route_test_support.status(res)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn router_wisp_debug_routes_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "user_1")

    let err =
      route_test_support.dispatch(
        route_test_support.get("/internal-server-error", option.Some(token)),
        ctx,
      )
    let assert 500 = route_test_support.status(err)

    let bad =
      route_test_support.dispatch(
        route_test_support.get("/bad-request", option.Some(token)),
        ctx,
      )
    let assert 400 = route_test_support.status(bad)

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn router_merge_requests_new_is_not_found_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "user_1")
    let res =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/merge-requests/new",
          option.Some(token),
        ),
        ctx,
      )
    let assert 404 = route_test_support.status(res)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}
