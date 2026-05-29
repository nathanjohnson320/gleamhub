import app/clerk_api.{Client}
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

pub fn merge_request_routes_lifecycle_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "demo", "owner")

    let create =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/merge-requests",
          token,
          json.object([
            #("title", json.string("Add feature")),
            #("description", json.string("Details")),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create)
    let assert True = route_test_support.contains(create, "\"number\":1")

    let list =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/merge-requests",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(list)
    let assert True = route_test_support.contains(list, "Add feature")

    let detail =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/merge-requests/1",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(detail)
    let assert True = route_test_support.contains(detail, "merge_check")

    let commits =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/merge-requests/1/commits",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(commits)
    let assert True = route_test_support.contains(commits, "commits")

    let diff =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/merge-requests/1/diff",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(diff)
    let assert True = route_test_support.contains(diff, "files")

    let comment =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/merge-requests/1/comments",
          token,
          json.object([
            #("body", json.string("Looks good")),
            #("file_path", json.string("feature.txt")),
            #("line", json.int(1)),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(comment)
    let assert True = route_test_support.contains(comment, "Looks good")

    let comments =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/merge-requests/1/comments",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(comments)
    let assert True = route_test_support.contains(comments, "Looks good")

    let close =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/merge-requests/1/close",
          token,
          json.object([]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(close)
    let assert True = route_test_support.contains(close, "\"state\":\"closed\"")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn merge_request_merge_route_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "demo", "owner")

    let create =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/merge-requests",
          token,
          json.object([
            #("title", json.string("Merge via HTTP")),
            #("description", json.null()),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create)

    let merge =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/merge-requests/1/merge",
          token,
          json.object([#("merge_method", json.string("merge"))]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(merge)
    let assert True = route_test_support.contains(merge, "\"state\":\"merged\"")
    let assert True = route_test_support.contains(merge, "merge_commit_sha")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn merge_request_merge_delete_source_branch_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "demo3", "owner")

    let _ =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo3/merge-requests",
          token,
          json.object([
            #("title", json.string("Merge and delete")),
            #("description", json.null()),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )

    let merge =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo3/merge-requests/1/merge",
          token,
          json.object([
            #("merge_method", json.string("merge")),
            #("delete_source_branch", json.bool(True)),
          ]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(merge)
    let assert True = route_test_support.contains(merge, "\"state\":\"merged\"")

    let branches =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo3/branches",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(branches)
    let assert True = route_test_support.contains(branches, "main")
    let assert False = route_test_support.contains(branches, "feature")

    let detail =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo3/merge-requests/1",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(detail)
    let assert True = route_test_support.contains(detail, "\"state\":\"merged\"")
    let assert True = route_test_support.contains(detail, "Already merged")

    let commits =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo3/merge-requests/1/commits",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(commits)
    let assert True = route_test_support.contains(commits, "commits")

    let diff =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo3/merge-requests/1/diff",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(diff)
    let assert True = route_test_support.contains(diff, "files")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn merge_request_merge_squash_route_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "demo2", "owner")

    let _ =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo2/merge-requests",
          token,
          json.object([
            #("title", json.string("Squash merge")),
            #("description", json.null()),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )

    let merge =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo2/merge-requests/1/merge",
          token,
          json.object([#("merge_method", json.string("squash"))]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(merge)
    let assert True = route_test_support.contains(merge, "\"state\":\"merged\"")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn merge_request_merge_closed_is_unprocessable_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "demo", "owner")

    let _ =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/merge-requests",
          token,
          json.object([
            #("title", json.string("Close then merge")),
            #("description", json.null()),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )

    let _ =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/merge-requests/1/close",
          token,
          json.object([]),
        ),
        ctx,
      )

    let merge =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/merge-requests/1/merge",
          token,
          json.object([]),
        ),
        ctx,
      )
    let assert 422 = route_test_support.status(merge)

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn merge_request_comments_with_clerk_client_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let clerk = Client(secret_key: "sk_test_invalid")
    let #(ctx, sign) =
      route_test_support.authenticated_with_clerk(db, root, clerk)
    let token = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "demo", "owner")

    let _ =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/merge-requests",
          token,
          json.object([
            #("title", json.string("Comment hydration")),
            #("description", json.null()),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )

    let comment =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/merge-requests/1/comments",
          token,
          json.object([
            #("body", json.string("Needs review")),
            #("file_path", json.null()),
            #("line", json.null()),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(comment)

    let comments =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/merge-requests/1/comments",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(comments)
    let assert True = route_test_support.contains(comments, "Needs review")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn merge_request_duplicate_open_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "demo", "owner")
    let body =
      json.object([
        #("title", json.string("First")),
        #("description", json.null()),
        #("source_branch", json.string("feature")),
        #("target_branch", json.string("main")),
      ])
    let first =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/merge-requests",
          token,
          body,
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(first)
    let dup =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/merge-requests",
          token,
          body,
        ),
        ctx,
      )
    let assert 409 = route_test_support.status(dup)
    let assert True = route_test_support.contains(dup, "existing_number")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}
