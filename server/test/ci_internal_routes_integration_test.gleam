import database
import database_integration_fixtures as fixtures
import db_test_support
import gleam/dynamic/decode
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

pub fn ci_enqueue_and_worker_flow_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "demo", "owner")
    let git_dir = root <> "/acme/demo.git"
    let feature_sha = route_test_support.rev_parse(git_dir, "feature")

    let create =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo/merge-requests",
          token,
          json.object([
            #("title", json.string("CI test")),
            #("description", json.null()),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create)

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
      route_test_support.contains(detail, "\"state\":\"queued\"")
    let assert True =
      route_test_support.contains(detail, "\"module_path\":\"ci\"")

    let next =
      route_test_support.dispatch(
        route_test_support.internal_get("/internal/ci/jobs/next"),
        ctx,
      )
    let assert 200 = route_test_support.status(next)
    let assert True = route_test_support.contains(next, feature_sha)
    let assert Ok(run_id) =
      json.parse(
        route_test_support.body(next),
        decode.at(["id"], decode.string),
      )

    let complete =
      route_test_support.dispatch(
        route_test_support.internal_patch(
          "/internal/ci/jobs/" <> run_id,
          json.object([
            #("state", json.string("success")),
            #("log", json.string("ok\n")),
          ]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(complete)

    let detail_after =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/demo/merge-requests/1",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(detail_after)
    let assert True =
      route_test_support.contains(detail_after, "\"state\":\"success\"")
    let assert True =
      route_test_support.contains(detail_after, "\"mergeable\":true")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn ci_enqueue_post_receive_form_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")
    let work = seed_git_repo(db, root, "acme", "push-ci", "owner")
    let git_dir = root <> "/acme/push-ci.git"
    let main_sha = route_test_support.rev_parse(git_dir, "main")

    let create =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/push-ci/merge-requests",
          token,
          json.object([
            #("title", json.string("Push CI")),
            #("description", json.null()),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create)

    let enqueue =
      route_test_support.dispatch(
        route_test_support.internal_post_form(
          "/internal/ci/enqueue",
          "org=acme&repo=push-ci&branch=feature&commit_sha=" <> main_sha,
        ),
        ctx,
      )
    let assert 204 = route_test_support.status(enqueue)

    let detail =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/repos/push-ci/merge-requests/1",
          option.Some(token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(detail)
    let assert True = route_test_support.contains(detail, main_sha)

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn ci_failure_blocks_merge_test() {
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
            #("title", json.string("Blocked")),
            #("description", json.null()),
            #("source_branch", json.string("feature")),
            #("target_branch", json.string("main")),
          ]),
        ),
        ctx,
      )

    let next =
      route_test_support.dispatch(
        route_test_support.internal_get("/internal/ci/jobs/next"),
        ctx,
      )
    let assert 200 = route_test_support.status(next)
    let assert Ok(run_id) =
      json.parse(
        route_test_support.body(next),
        decode.at(["id"], decode.string),
      )

    let _ =
      route_test_support.dispatch(
        route_test_support.internal_patch(
          "/internal/ci/jobs/" <> run_id,
          json.object([
            #("state", json.string("failure")),
            #("log", json.string("tests failed\n")),
          ]),
        ),
        ctx,
      )

    let merge =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos/demo2/merge-requests/1/merge",
          token,
          json.object([]),
        ),
        ctx,
      )
    let assert 422 = route_test_support.status(merge)
    let assert True = route_test_support.contains(merge, "Checks failed")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn ci_enqueue_default_branch_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, _sign) = route_test_support.authenticated(db, root)
    let work = seed_git_repo(db, root, "acme", "main-ci", "owner")
    let git_dir = root <> "/acme/main-ci.git"
    let main_sha = route_test_support.rev_parse(git_dir, "main")
    let assert Ok(option.Some(repo)) = database.get_repo(db, "acme", "main-ci")

    let enqueue =
      route_test_support.dispatch(
        route_test_support.internal_post_form(
          "/internal/ci/enqueue",
          "org=acme&repo=main-ci&branch=main&commit_sha=" <> main_sha,
        ),
        ctx,
      )
    let assert 204 = route_test_support.status(enqueue)

    let assert Ok(True) =
      database.pipeline_run_exists_for_branch_sha(
        db,
        repo.id,
        "main",
        main_sha,
      )

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn ci_next_job_for_default_branch_run_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, _sign) = route_test_support.authenticated(db, root)
    let work = seed_git_repo(db, root, "acme", "branch-job", "owner")
    let git_dir = root <> "/acme/branch-job.git"
    let main_sha = route_test_support.rev_parse(git_dir, "main")
    let assert Ok(option.Some(repo)) = database.get_repo(db, "acme", "branch-job")

    let assert Ok(_run) =
      database.insert_branch_pipeline_run(
        db,
        repo.id,
        "main",
        main_sha,
        option.Some("ci"),
        "ci",
        "queued",
        "push",
      )

    let next =
      route_test_support.dispatch(
        route_test_support.internal_get("/internal/ci/jobs/next"),
        ctx,
      )
    let assert 200 = route_test_support.status(next)
    let assert True = route_test_support.contains(next, main_sha)
    let assert True = route_test_support.contains(next, "\"merge_request_id\":\"\"")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}
