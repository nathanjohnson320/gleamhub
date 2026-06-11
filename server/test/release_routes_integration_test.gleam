import database
import database_integration_fixtures as fixtures
import db_test_support
import gleam/json
import gleam/option
import route_test_support

@external(erlang, "git_exec_test_ffi", "create_tag")
fn create_tag(git_dir: String, tag: String, ref: String) -> Nil

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

pub fn tag_and_release_routes_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let _work = seed_git_repo(db, root, "acme", "demo", "owner")
    let bare = root <> "/acme/demo.git"
    create_tag(bare, "v1.0.0", "main")

    let tags =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/tags",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(tags)
    let assert True = route_test_support.contains(tags, "v1.0.0")

    let tag_detail =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/tags/v1.0.0",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(tag_detail)
    let assert True =
      route_test_support.contains(tag_detail, "target_commit_sha")

    let empty_releases =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/releases",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(empty_releases)
    let assert True =
      route_test_support.contains(empty_releases, "\"releases\":[]")

    let created =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/releases",
          token,
          json.object([
            #("tag_name", json.string("v1.0.0")),
            #("title", json.string("Version 1.0.0")),
            #("body", json.string("First release")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(created)
    let assert True =
      route_test_support.contains(created, "Version 1.0.0")

    let release_detail =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/releases/v1.0.0",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(release_detail)
    let assert True =
      route_test_support.contains(release_detail, "First release")

    let updated =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/repos/demo/releases/v1.0.0",
          token,
          json.object([
            #("title", json.string("Version 1.0.0")),
            #("body", json.string("Updated release notes")),
          ]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(updated)
    let assert True =
      route_test_support.contains(updated, "Updated release notes")

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}
