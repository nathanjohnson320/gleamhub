import database
import database_integration_fixtures as fixtures
import db_test_support
import gleam/json
import gleam/option
import gleam/string
import route_test_support

@external(erlang, "git_exec_test_ffi", "create_branch")
fn create_branch(git_dir: String, branch: String, from_branch: String) -> Nil

fn seed_git_repo(
  db,
  root: String,
  org: String,
  name: String,
  owner: String,
) -> String {
  let disk = org <> "/" <> name <> ".git"
  let work = route_test_support.clone_git_fixture(root, disk)
  let _ = fixtures.seed_org(db, org, owner)
  let assert Ok(_) = database.insert_repo(db, org, name, option.None, disk)
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
    let assert True =
      route_test_support.contains(detail, "\"default_branch\":\"main\"")

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

    let bare = root <> "/acme/demo.git"
    create_branch(bare, "test/merge-conflict", "main")
    let slashy_blob =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/blob/README.md?ref=test%2Fmerge-conflict",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(slashy_blob)
    let assert True = route_test_support.contains(slashy_blob, "Gleamhub test")

    let legacy_slashy_blob =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/blob/test/merge-conflict/README.md",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(legacy_slashy_blob)
    let assert True =
      route_test_support.contains(legacy_slashy_blob, "Gleamhub test")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn repo_raw_and_archive_routes_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "demo", "owner")

    let raw =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/raw/main/src/main.gleam",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(raw)
    let body = route_test_support.body(raw)
    let assert True = string.contains(body, "pub fn main()")

    let browser_raw =
      route_test_support.dispatch(
        route_test_support.get(
          "/raw/orgs/acme/repos/demo/main/src/main.gleam?token=" <> token,
          option.None,
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(browser_raw)
    let assert True =
      string.contains(route_test_support.body(browser_raw), "pub fn main()")
    let assert False =
      string.contains(
        route_test_support.response_header(browser_raw, "content-disposition"),
        "filename",
      )

    let download =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/raw/main/README.md?download=1",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(download)
    let assert True =
      string.contains(
        route_test_support.response_header(download, "content-disposition"),
        "attachment",
      )

    let traversal =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/raw/main/../../README.md",
          option.Some(token),
        ),
        ctx,
      )
    let assert 404 = route_test_support.status(traversal)

    let archive =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/archive/main.zip",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(archive)
    let assert "application/zip" =
      route_test_support.response_header(archive, "content-type")
    let assert True =
      string.contains(
        route_test_support.response_header(archive, "content-disposition"),
        "demo-main.zip",
      )

    let archive_tgz =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/archive/main.tar.gz",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(archive_tgz)
    let assert "application/gzip" =
      route_test_support.response_header(archive_tgz, "content-type")
    let assert True =
      string.contains(
        route_test_support.response_header(archive_tgz, "content-disposition"),
        "demo-main.tar.gz",
      )

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

pub fn repo_default_branch_route_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let owner = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "demo", "owner")
    let bare = root <> "/acme/demo.git"
    create_branch(bare, "develop", "main")

    let bad =
      route_test_support.dispatch(
        route_test_support.put_json(
          "/api/orgs/acme/repos/demo/default-branch",
          owner,
          json.object([#("branch", json.string("missing"))]),
        ),
        ctx,
      )
    let assert 400 = route_test_support.status(bad)

    let ok =
      route_test_support.dispatch(
        route_test_support.put_json(
          "/api/orgs/acme/repos/demo/default-branch",
          owner,
          json.object([#("branch", json.string("develop"))]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(ok)
    let assert True =
      route_test_support.contains(ok, "\"default_branch\":\"develop\"")

    let detail =
      route_test_support.dispatch(
        route_test_support.get("/api/orgs/acme/repos/demo", option.Some(owner)),
        ctx,
      )
    let assert 200 = route_test_support.status(detail)
    let assert True =
      route_test_support.contains(detail, "\"default_branch\":\"develop\"")

    fixtures.seed_org_member(db, "acme", "member", "member")
    let member = route_test_support.bearer_token(sign, "member")
    let forbidden =
      route_test_support.dispatch(
        route_test_support.put_json(
          "/api/orgs/acme/repos/demo/default-branch",
          member,
          json.object([#("branch", json.string("main"))]),
        ),
        ctx,
      )
    let assert 403 = route_test_support.status(forbidden)

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}
