import app/database
import app/org_access
import app/pipeline_events
import app/web
import gleam/erlang/process
import database_integration_fixtures as fixtures
import db_test_support
import gleam/option
import pog
import ywt
import ywt/algorithm
import ywt/verify_key

fn test_context(repo: fn() -> pog.Connection) -> web.Context {
  let sign = ywt.generate_key(algorithm.rs256)
  let clerk_keys = [verify_key.derived(sign)]
  let pipeline_events_name = process.new_name("gleamhub.test.pipeline_events")
  let assert Ok(_) = pipeline_events.start(pipeline_events_name)
  web.Context(
    clerk_keys:,
    static_directory: "",
    repo:,
    git_repos_root: "/tmp/gleamhub-repos",
    git_host: "git.example.com",
    user_id: option.None,
    clerk: option.None,
    internal_api_token: "test-internal-token",
    clerk_issuer: option.None,
    pipeline_events_name:,
  )
}

pub fn git_access_owner_read_write_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_repo(db, "acme", "demo", "owner")
    let ctx = test_context(fn() { db })
    let access = org_access.git_access(ctx, "owner", "acme", "demo", True)
    let assert org_access.Access(read: True, write: True) = access
    let assert "git.example.com" = org_access.git_host(ctx)
    let assert "/tmp/gleamhub-repos" = org_access.git_repos_root(ctx)
    Nil
  })
}

pub fn git_access_member_read_only_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_org(db, "acme", "owner")
    fixtures.seed_org_member(db, "acme", "member", "member")
    let assert Ok(_) =
      database.insert_repo(db, "acme", "demo", option.None, "acme/demo.git")
    let ctx = test_context(fn() { db })
    let access = org_access.git_access(ctx, "member", "acme", "demo", True)
    let assert org_access.Access(read: True, write: True) = access
    Nil
  })
}

pub fn git_access_member_no_receive_pack_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_repo(db, "acme", "demo", "owner")
    fixtures.seed_org_member(db, "acme", "member", "member")
    let ctx = test_context(fn() { db })
    let access = org_access.git_access(ctx, "member", "acme", "demo", False)
    let assert org_access.Access(read: True, write: False) = access
    Nil
  })
}

pub fn git_access_non_member_denied_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_repo(db, "acme", "demo", "owner")
    fixtures.seed_user(db, "outsider")
    let ctx = test_context(fn() { db })
    let access = org_access.git_access(ctx, "outsider", "acme", "demo", True)
    let assert org_access.Access(read: False, write: False) = access
    Nil
  })
}

pub fn git_access_unknown_repo_denied_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_org(db, "acme", "owner")
    let ctx = test_context(fn() { db })
    let access = org_access.git_access(ctx, "owner", "acme", "missing", True)
    let assert org_access.Access(read: False, write: False) = access
    Nil
  })
}

pub fn require_member_and_owner_test() {
  db_test_support.with_db(fn(db) {
    let _ = fixtures.seed_org(db, "acme", "owner")
    fixtures.seed_org_member(db, "acme", "member", "member")
    let ctx = test_context(fn() { db })
    let assert Ok(Nil) = org_access.require_member(ctx, "owner", "acme")
    let assert Ok(Nil) = org_access.require_member(ctx, "member", "acme")
    let assert Error(Nil) = org_access.require_member(ctx, "outsider", "acme")
    let assert Ok(Nil) = org_access.require_owner(ctx, "owner", "acme")
    let assert Error(Nil) = org_access.require_owner(ctx, "member", "acme")
    Nil
  })
}
