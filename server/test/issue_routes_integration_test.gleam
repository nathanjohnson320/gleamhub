import database
import database_integration_fixtures as fixtures
import db_test_support
import gleam/json
import gleam/option
import gleam/string
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

pub fn issue_template_route_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "demo", "owner")

    let template =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/issues/template?ref=main",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(template)
    let assert True =
      route_test_support.contains(template, "## Steps to reproduce")

    route_test_support.cleanup_repos_root(root)
    route_test_support.cleanup_fixture_repo(work)
    Nil
  })
}

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
    let assert True =
      route_test_support.contains(comment, "I can reproduce this")

    let comments =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/issues/1/comments",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(comments)
    let assert True =
      route_test_support.contains(comments, "I can reproduce this")

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

    let reopen =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/issues/1/reopen",
          token,
          json.object([]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(reopen)
    let assert True = route_test_support.contains(reopen, "\"state\":\"open\"")

    let create_label =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/labels",
          token,
          json.object([
            #("name", json.string("bug")),
            #("color", json.string("#d73a4a")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create_label)

    let patch =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/repos/demo/issues/1",
          token,
          json.object([
            #("title", json.string("Fix login bug (updated)")),
          ]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(patch)
    let assert True =
      route_test_support.contains(patch, "Fix login bug (updated)")

    let assign_owner =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/repos/demo/issues/1",
          token,
          json.object([
            #("assignee_user_ids", json.array(["owner"], of: json.string)),
          ]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(assign_owner)
    let assert True =
      route_test_support.contains(assign_owner, "\"user_id\":\"owner\"")

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn issue_comment_edit_delete_test() {
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
            #("title", json.string("Bug report")),
            #("description", json.string("Something broke")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create)

    let comment =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/issues/1/comments",
          token,
          json.object([#("body", json.string("First comment"))]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(comment)
    let assert True = route_test_support.contains(comment, "\"id\":")
    let assert Ok(comment_id) =
      extract_comment_id(route_test_support.body(comment))

    let updated =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/repos/demo/issues/1/comments/" <> comment_id,
          token,
          json.object([#("body", json.string("Updated comment"))]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(updated)
    let assert True = route_test_support.contains(updated, "Updated comment")

    let deleted =
      route_test_support.dispatch(
        route_test_support.delete(
          "/api/orgs/acme/repos/demo/issues/1/comments/" <> comment_id,
          token,
        ),
        ctx,
      )
    let assert 204 = route_test_support.status(deleted)

    let comments =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/issues/1/comments",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(comments)
    let assert False = route_test_support.contains(comments, "Updated comment")

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn issue_comment_mentions_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let _ = fixtures.seed_org(db, "acme", "owner")
    let _ = fixtures.seed_org_member(db, "acme", "reviewer", "member")
    let assert Ok(_) =
      database.insert_repo(db, "acme", "demo", option.None, "acme/demo.git")

    let create =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/issues",
          token,
          json.object([
            #("title", json.string("Needs review")),
            #("description", json.null()),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create)

    let comment =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/issues/1/comments",
          token,
          json.object([
            #("body", json.string("Hey @reviewer, can you take a look?")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(comment)
    let assert True =
      route_test_support.contains(comment, "\"mentioned_user_ids\":[\"reviewer\"]")
    let assert True =
      route_test_support.contains(comment, "\"mentioned_usernames\":[\"reviewer\"]")

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn label_update_test() {
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
          "/api/orgs/acme/repos/demo/labels",
          token,
          json.object([
            #("name", json.string("bug")),
            #("color", json.string("#d73a4a")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create)
    let assert Ok(label_id) = extract_label_id(route_test_support.body(create))

    let updated =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/repos/demo/labels/" <> label_id,
          token,
          json.object([
            #("name", json.string("defect")),
            #("color", json.string("#0075ca")),
          ]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(updated)
    let assert True =
      route_test_support.contains(updated, "\"name\":\"defect\"")
    let assert True =
      route_test_support.contains(updated, "\"color\":\"#0075ca\"")

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

fn extract_comment_id(body: String) -> Result(String, Nil) {
  case string.split(body, "\"id\":\"") {
    [_, rest, ..] ->
      case string.split(rest, "\"") {
        [id, ..] -> Ok(id)
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

fn extract_label_id(body: String) -> Result(String, Nil) {
  extract_comment_id(body)
}

pub fn issue_list_filter_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let _ = fixtures.seed_org(db, "acme", "owner")
    let _ = fixtures.seed_org_member(db, "acme", "member", "member")
    let assert Ok(_) =
      database.insert_repo(db, "acme", "demo", option.None, "acme/demo.git")

    let create_label =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/labels",
          token,
          json.object([
            #("name", json.string("bug")),
            #("color", json.string("#d73a4a")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create_label)

    let open_issue =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/issues",
          token,
          json.object([
            #("title", json.string("Open login bug")),
            #("description", json.null()),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(open_issue)

    let _ =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/repos/demo/issues/1",
          token,
          json.object([
            #(
              "label_ids",
              case extract_label_id(route_test_support.body(create_label)) {
                Ok(id) -> json.array([id], of: json.string)
                Error(_) -> json.array([], of: json.string)
              },
            ),
            #("assignee_user_ids", json.array(["member"], of: json.string)),
          ]),
        ),
        ctx,
      )

    let closed_issue =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/issues",
          token,
          json.object([
            #("title", json.string("Closed docs task")),
            #("description", json.null()),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(closed_issue)

    let _ =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/issues/2/close",
          token,
          json.object([]),
        ),
        ctx,
      )

    let default_list =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/issues",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(default_list)
    let assert True =
      route_test_support.contains(default_list, "Open login bug")
    let assert False =
      route_test_support.contains(default_list, "Closed docs task")

    let closed_list =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/issues?state=closed",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(closed_list)
    let assert True =
      route_test_support.contains(closed_list, "Closed docs task")
    let assert False =
      route_test_support.contains(closed_list, "Open login bug")

    let label_list =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/issues?label=bug",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(label_list)
    let assert True =
      route_test_support.contains(label_list, "Open login bug")

    let assignee_list =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/issues?assignee=member",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(assignee_list)
    let assert True =
      route_test_support.contains(assignee_list, "Open login bug")

    let search_list =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/issues?state=all&q=docs",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(search_list)
    let assert True =
      route_test_support.contains(search_list, "Closed docs task")
    let assert False =
      route_test_support.contains(search_list, "Open login bug")

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}
