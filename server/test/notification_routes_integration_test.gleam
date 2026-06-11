import database
import database_integration_fixtures as fixtures
import db_test_support
import gleam/json
import gleam/option
import route_test_support

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

pub fn mention_creates_notification_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let owner = route_test_support.bearer_token(sign, "owner")
    let reviewer = route_test_support.bearer_token(sign, "reviewer")
    let _ = seed_git_repo(db, root, "acme", "demo", "owner")
    let _ = fixtures.seed_org_member(db, "acme", "reviewer", "member")

    let create =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/merge-requests",
          owner,
          json.object([
            #("title", json.string("Mention test")),
            #("description", json.string("Details")),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create)

    let comment =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/merge-requests/1/comments",
          owner,
          json.object([
            #("body", json.string("Hey @reviewer please look")),
            #("file_path", json.null()),
            #("line", json.null()),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(comment)

    let notifications =
      route_test_support.dispatch(
        route_test_support.get("/api/notifications", option.Some(reviewer)),
        ctx,
      )
    let assert 200 = route_test_support.status(notifications)
    let assert True =
      route_test_support.contains(notifications, "mention.mr_comment")

    let mark_all =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/notifications/read-all",
          reviewer,
          json.object([]),
        ),
        ctx,
      )
    let assert 204 = route_test_support.status(mark_all)

    let me =
      route_test_support.dispatch(
        route_test_support.get("/api/me", option.Some(reviewer)),
        ctx,
      )
    let assert 200 = route_test_support.status(me)
    let assert True = route_test_support.contains(me, "\"unread_notifications\":0")

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

import gleeunit

pub fn main() {
  gleeunit.main()
}
