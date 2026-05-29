import app/database
import database_integration_fixtures as fixtures
import db_test_support
import gleam/option
import route_test_support

pub fn ssh_authorized_keys_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, _sign) = route_test_support.authenticated(db, root)
    fixtures.seed_user(db, "user_1")
    let #(public_key, blob, fp) = fixtures.test_ssh_key()
    let assert Ok(_) =
      database.insert_key(db, "user_1", "laptop", public_key, blob, fp)

    let hit =
      route_test_support.dispatch(
        route_test_support.internal_get(
          "/internal/ssh/authorized_keys?k=" <> blob,
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(hit)
    let assert True = route_test_support.contains(hit, "GLEAMHUB_USER_ID=user_1")

    let miss =
      route_test_support.dispatch(
        route_test_support.internal_get(
          "/internal/ssh/authorized_keys?k=missing",
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(miss)
    let assert "" = route_test_support.body(miss)

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn ssh_internal_auth_rejects_missing_token_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, _sign) = route_test_support.authenticated(db, root)

    let res =
      route_test_support.dispatch(
        route_test_support.get("/internal/ssh/access?org=acme&repo=demo", option.None),
        ctx,
      )
    let assert 401 = route_test_support.status(res)

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn ssh_access_check_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, _sign) = route_test_support.authenticated(db, root)
    let disk = "acme/demo.git"
    let work = route_test_support.clone_git_fixture(root, disk)
    let _ = fixtures.seed_org(db, "acme", "owner")
    let assert Ok(_) =
      database.insert_repo(db, "acme", "demo", option.None, disk)

    let allowed =
      route_test_support.dispatch(
        route_test_support.internal_get(
          "/internal/ssh/access?org=acme&repo=demo&user_id=owner&op=git-upload-pack",
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(allowed)
    let assert True = route_test_support.contains(allowed, "\"read\":true")

    let denied =
      route_test_support.dispatch(
        route_test_support.internal_get(
          "/internal/ssh/access?org=acme&repo=demo&user_id=outsider&op=git-upload-pack",
        ),
        ctx,
      )
    let assert 403 = route_test_support.status(denied)

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn ssh_ref_update_unprotected_allows_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, _sign) = route_test_support.authenticated(db, root)
    let disk = "acme/demo.git"
    let work = route_test_support.clone_git_fixture(root, disk)
    let _ = fixtures.seed_org(db, "acme", "owner")
    let assert Ok(_) =
      database.insert_repo(db, "acme", "demo", option.None, disk)

    let res =
      route_test_support.dispatch(
        route_test_support.internal_get(
          "/internal/ssh/ref-update?org=acme&repo=demo&user_id=owner&oldrev=0000000000000000000000000000000000000000&newrev=abc123def4567890123456789012345678901234&ref=refs/heads/feature",
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(res)
    let assert True = route_test_support.contains(res, "\"allowed\":true")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn ssh_ref_update_protected_denies_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, _sign) = route_test_support.authenticated(db, root)
    let disk = "acme/demo.git"
    let work = route_test_support.clone_git_fixture(root, disk)
    let _ = fixtures.seed_repo(db, "acme", "demo", "owner")
    let assert Ok(_) =
      database.replace_protected_branches(db, "acme", "demo", ["main"])
    let git_dir = root <> "/" <> disk
    let main_sha = route_test_support.rev_parse(git_dir, "main")
    let feature_sha = route_test_support.rev_parse(git_dir, "feature")

    let res =
      route_test_support.dispatch(
        route_test_support.internal_get(
          "/internal/ssh/ref-update?org=acme&repo=demo&user_id=owner&oldrev="
          <> main_sha
          <> "&newrev="
          <> feature_sha
          <> "&ref=refs/heads/main",
        ),
        ctx,
      )
    let assert 403 = route_test_support.status(res)
    let assert True = route_test_support.contains(res, "\"allowed\":false")

    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}
