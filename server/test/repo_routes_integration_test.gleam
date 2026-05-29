import app/database
import database_integration_fixtures as fixtures
import db_test_support
import gleam/json
import gleam/option
import route_test_support

fn seed_git_repo(db, root: String, org: String, name: String, owner: String) -> String {
  let disk = org <> "/" <> name <> ".git"
  let work = route_test_support.clone_git_fixture(root, disk)
  let _ = fixtures.seed_org(db, org, owner)
  let assert Ok(_) =
    database.insert_repo(db, org, name, option.None, disk)
  work
}

pub fn repo_browse_routes_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "demo", "owner")

    let detail =
      route_test_support.dispatch(
        route_test_support.get("/api/orgs/acme/repos/demo", option.Some(token)),
        ctx,
      )
    let assert 200 = route_test_support.status(detail)
    let assert True = route_test_support.contains(detail, "\"default_branch\":\"main\"")

    let branches =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/branches",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(branches)
    let assert True = route_test_support.contains(branches, "main")

    let readme =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/readme?ref=main",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(readme)
    let assert True = route_test_support.contains(readme, "Gleamhub test")

    let tree =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/tree/main/src",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(tree)
    let assert True = route_test_support.contains(tree, "main.gleam")

    let blob =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/blob/main/README.md",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(blob)
    let assert True = route_test_support.contains(blob, "Gleamhub test")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn repo_protected_branches_routes_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let owner = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "demo", "owner")

    let list_empty =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/protected-branches",
          option.Some(owner),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(list_empty)
    let assert True = route_test_support.contains(list_empty, "\"branches\":[]")

    let put =
      route_test_support.dispatch(
        route_test_support.put_json(
          "/api/orgs/acme/repos/demo/protected-branches",
          owner,
          json.object([#("branches", json.array(["main"], of: json.string))]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(put)
    let assert True = route_test_support.contains(put, "main")

    fixtures.seed_org_member(db, "acme", "member", "member")
    let member = route_test_support.bearer_token(sign, "member")
    let forbidden =
      route_test_support.dispatch(
        route_test_support.put_json(
          "/api/orgs/acme/repos/demo/protected-branches",
          member,
          json.object([#("branches", json.array([], of: json.string))]),
        ),
        ctx,
      )
    let assert 403 = route_test_support.status(forbidden)

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}
