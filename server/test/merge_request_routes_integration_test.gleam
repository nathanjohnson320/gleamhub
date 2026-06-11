import database
import database_integration_fixtures as fixtures
import db_test_support
import gleam/json
import gleam/option
import http/clerk_api.{Client}
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

    let template =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/merge-requests/template?ref=main",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(template)
    let assert True = route_test_support.contains(template, "## Summary")

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

    route_test_support.complete_next_pipeline(ctx)

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

    route_test_support.complete_next_pipeline(ctx)

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
    let assert True =
      route_test_support.contains(detail, "\"state\":\"merged\"")
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

    route_test_support.complete_next_pipeline(ctx)

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

pub fn merge_request_update_branch_route_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "behind", "owner")
    let git_dir = root <> "/acme/behind.git"

    let _ =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/behind/merge-requests",
          token,
          json.object([
            #("title", json.string("Feature")),
            #("description", json.null()),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )

    let detail_before =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/behind/merge-requests/1",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(detail_before)
    let assert True =
      route_test_support.contains(detail_before, "\"behind_target\":false")

    route_test_support.advance_branch(git_dir, "main")

    let detail_stale =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/behind/merge-requests/1",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(detail_stale)
    let assert True =
      route_test_support.contains(detail_stale, "\"behind_target\":true")

    let updated =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/behind/merge-requests/1/update-branch",
          token,
          json.object([]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(updated)
    let assert True =
      route_test_support.contains(updated, "\"behind_target\":false")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn draft_merge_request_test() {
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
            #("title", json.string("Draft work")),
            #("description", json.string("WIP")),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
            #("draft", json.bool(True)),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create)
    let assert True = route_test_support.contains(create, "\"is_draft\":true")

    let detail =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/merge-requests/1",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(detail)
    let assert True =
      route_test_support.contains(detail, "Mark as ready for review first")
    let assert True = route_test_support.contains(detail, "\"mergeable\":false")

    let merge_blocked =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/merge-requests/1/merge",
          token,
          json.object([]),
        ),
        ctx,
      )
    let assert 422 = route_test_support.status(merge_blocked)

    let ready =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/repos/demo/merge-requests/1",
          token,
          json.object([#("draft", json.bool(False))]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(ready)
    let assert True = route_test_support.contains(ready, "\"is_draft\":false")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn merge_request_update_title_test() {
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
            #("title", json.string("Original title")),
            #("description", json.string("Original body")),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )

    let patch =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/repos/demo/merge-requests/1",
          token,
          json.object([
            #("title", json.string("Updated title")),
            #("description", json.string("Updated body")),
          ]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(patch)
    let assert True = route_test_support.contains(patch, "Updated title")
    let assert True = route_test_support.contains(patch, "Updated body")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn merge_request_assignees_test() {
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
            #("title", json.string("Assign me")),
            #("description", json.null()),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )

    let patch =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/repos/demo/merge-requests/1",
          token,
          json.object([
            #("assignee_user_ids", json.array(["owner"], of: json.string)),
          ]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(patch)
    let assert True =
      route_test_support.contains(patch, "\"user_id\":\"owner\"")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn merge_request_merge_rebase_route_test() {
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
            #("title", json.string("Rebase merge")),
            #("description", json.null()),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )

    route_test_support.complete_next_pipeline(ctx)

    let merge =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo2/merge-requests/1/merge",
          token,
          json.object([#("merge_method", json.string("rebase"))]),
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

pub fn merge_request_approval_gate_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "approvals", "owner")

    let assert Ok(1) =
      database.set_required_approvals(db, "acme", "approvals", 1)

    fixtures.seed_org_member(db, "acme", "member", "member")
    let member_token = route_test_support.bearer_token(sign, "member")

    let _ =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/approvals/merge-requests",
          token,
          json.object([
            #("title", json.string("Needs approval")),
            #("description", json.null()),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )

    route_test_support.complete_next_pipeline(ctx)

    let detail =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/approvals/merge-requests/1",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(detail)
    let assert True = route_test_support.contains(detail, "\"mergeable\":false")
    let assert True = route_test_support.contains(detail, "approval")

    let blocked_merge =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/approvals/merge-requests/1/merge",
          token,
          json.object([#("merge_method", json.string("merge"))]),
        ),
        ctx,
      )
    let assert 422 = route_test_support.status(blocked_merge)

    let review =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/approvals/merge-requests/1/reviews",
          member_token,
          json.object([#("state", json.string("approved"))]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(review)

    let merge =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/approvals/merge-requests/1/merge",
          token,
          json.object([#("merge_method", json.string("merge"))]),
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

pub fn merge_request_reviewers_and_changes_requested_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "reviewers", "owner")

    fixtures.seed_org_member(db, "acme", "member", "member")
    let member_token = route_test_support.bearer_token(sign, "member")

    let _ =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/reviewers/merge-requests",
          token,
          json.object([
            #("title", json.string("Review flow")),
            #("description", json.null()),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )

    route_test_support.complete_next_pipeline(ctx)

    let patch_reviewers =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/repos/reviewers/merge-requests/1",
          token,
          json.object([#("reviewer_user_ids", json.array(["member"], json.string))]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(patch_reviewers)
    let assert True = route_test_support.contains(patch_reviewers, "\"reviewers\"")

    let invalid_reviewer =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/repos/reviewers/merge-requests/1",
          token,
          json.object([
            #("reviewer_user_ids", json.array(["not-a-member"], json.string)),
          ]),
        ),
        ctx,
      )
    let assert 400 = route_test_support.status(invalid_reviewer)

    let author_as_reviewer =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/repos/reviewers/merge-requests/1",
          token,
          json.object([
            #("reviewer_user_ids", json.array(["owner"], json.string)),
          ]),
        ),
        ctx,
      )
    let assert 400 = route_test_support.status(author_as_reviewer)
    let assert True =
      route_test_support.contains(author_as_reviewer, "Authors cannot be reviewers")

    let review =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/reviewers/merge-requests/1/reviews",
          member_token,
          json.object([
            #("state", json.string("changes_requested")),
            #("body", json.null()),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(review)

    let detail =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/reviewers/merge-requests/1",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(detail)
    let assert True = route_test_support.contains(detail, "\"mergeable\":false")
    let assert True =
      route_test_support.contains(detail, "Changes requested by a reviewer")

    let blocked_merge =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/reviewers/merge-requests/1/merge",
          token,
          json.object([#("merge_method", json.string("merge"))]),
        ),
        ctx,
      )
    let assert 422 = route_test_support.status(blocked_merge)

    let approve =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/reviewers/merge-requests/1/reviews",
          member_token,
          json.object([#("state", json.string("approved"))]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(approve)

    let merge =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/reviewers/merge-requests/1/merge",
          token,
          json.object([#("merge_method", json.string("merge"))]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(merge)
    let assert True = route_test_support.contains(merge, "\"state\":\"merged\"")

    let list_reviews =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/reviewers/merge-requests/1/reviews",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(list_reviews)
    let assert True = route_test_support.contains(list_reviews, "\"reviewers\"")
    let assert True = route_test_support.contains(list_reviews, "\"reviews\"")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn issue_mr_link_merge_closes_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "linkdemo", "owner")

    let create_issue =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/linkdemo/issues",
          token,
          json.object([
            #("title", json.string("First bug")),
            #("description", json.null()),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create_issue)

    let create_mr =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/linkdemo/merge-requests",
          token,
          json.object([
            #("title", json.string("Fix first bug")),
            #("description", json.string("Fixes #1")),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create_mr)

    let issue_detail =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/linkdemo/issues/1",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(issue_detail)
    let assert True =
      route_test_support.contains(issue_detail, "linked_merge_requests")
    let assert True =
      route_test_support.contains(issue_detail, "Fix first bug")

    let mr_detail =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/linkdemo/merge-requests/1",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(mr_detail)
    let assert True = route_test_support.contains(mr_detail, "linked_issues")
    let assert True =
      route_test_support.contains(mr_detail, "\"link_type\":\"closes\"")

    route_test_support.complete_next_pipeline(ctx)

    let merge =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/linkdemo/merge-requests/1/merge",
          token,
          json.object([#("merge_method", json.string("merge"))]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(merge)

    let closed_issue =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/linkdemo/issues/1",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(closed_issue)
    let assert True =
      route_test_support.contains(closed_issue, "\"state\":\"closed\"")

    let create_issue2 =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/linkdemo/issues",
          token,
          json.object([
            #("title", json.string("Second bug")),
            #("description", json.null()),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create_issue2)

    let create_mr2 =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/linkdemo/merge-requests",
          token,
          json.object([
            #("title", json.string("Related work")),
            #("description", json.string("Related #2")),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create_mr2)

    route_test_support.complete_next_pipeline(ctx)

    let merge2 =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/linkdemo/merge-requests/2/merge",
          token,
          json.object([#("merge_method", json.string("merge"))]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(merge2)

    let open_issue2 =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/linkdemo/issues/2",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(open_issue2)
    let assert True =
      route_test_support.contains(open_issue2, "\"state\":\"open\"")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}
