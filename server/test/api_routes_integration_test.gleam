import app/clerk_api.{Client}
import app/database
import database_integration_fixtures as fixtures
import db_test_support
import gleam/dynamic/decode
import gleam/json
import gleam/option
import route_test_support

pub fn api_requires_auth_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, _sign) = route_test_support.authenticated(db, root)
    let res =
      route_test_support.dispatch(route_test_support.get("/api/me", option.None), ctx)
    let assert 401 = route_test_support.status(res)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn api_me_and_org_lifecycle_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "user_1")

    let me =
      route_test_support.dispatch(route_test_support.get("/api/me", option.Some(token)), ctx)
    let assert 200 = route_test_support.status(me)
    let assert True = route_test_support.contains(me, "\"id\":\"user_1\"")

    let create_org =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs",
          token,
          json.object([
            #("slug", json.string("acme")),
            #("name", json.string("Acme Corp")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create_org)
    let assert True = route_test_support.contains(create_org, "\"slug\":\"acme\"")

    let list_orgs =
      route_test_support.dispatch(
        route_test_support.get("/api/orgs", option.Some(token)),
        ctx,
      )
    let assert 200 = route_test_support.status(list_orgs)
    let assert True = route_test_support.contains(list_orgs, "acme")

    let get_org =
      route_test_support.dispatch(
        route_test_support.get("/api/orgs/acme", option.Some(token)),
        ctx,
      )
    let assert 200 = route_test_support.status(get_org)

    let create_repo =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/repos",
          token,
          json.object([
            #("name", json.string("demo")),
            #("description", json.string("Demo repo")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create_repo)
    let assert True = route_test_support.contains(create_repo, "\"name\":\"demo\"")

    let list_repos =
      route_test_support.dispatch(
        route_test_support.get("/api/orgs/acme/repos", option.Some(token)),
        ctx,
      )
    let assert 200 = route_test_support.status(list_repos)
    let assert True = route_test_support.contains(list_repos, "demo")

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn api_create_org_invalid_slug_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "user_1")
    let res =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs",
          token,
          json.object([
            #("slug", json.string("Bad Slug!")),
            #("name", json.string("Nope")),
          ]),
        ),
        ctx,
      )
    let assert 400 = route_test_support.status(res)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn api_org_forbidden_for_non_member_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let owner = route_test_support.bearer_token(sign, "owner")
    let _ =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs",
          owner,
          json.object([
            #("slug", json.string("acme")),
            #("name", json.string("Acme")),
          ]),
        ),
        ctx,
      )
    let outsider = route_test_support.bearer_token(sign, "outsider")
    let res =
      route_test_support.dispatch(
        route_test_support.get("/api/orgs/acme", option.Some(outsider)),
        ctx,
      )
    let assert 403 = route_test_support.status(res)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn api_ssh_keys_lifecycle_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "user_1")
    let #(public_key, _, _) = fixtures.test_ssh_key()

    let create =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/ssh-keys",
          token,
          json.object([
            #("title", json.string("laptop")),
            #("public_key", json.string(public_key)),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create)
    let assert True = route_test_support.contains(create, "laptop")

    let list =
      route_test_support.dispatch(
        route_test_support.get("/api/ssh-keys", option.Some(token)),
        ctx,
      )
    let assert 200 = route_test_support.status(list)
    let assert True = route_test_support.contains(list, "ssh-ed25519")

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn api_delete_ssh_key_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "user_1")
    let #(public_key, _, _) = fixtures.test_ssh_key()

    let create =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/ssh-keys",
          token,
          json.object([
            #("title", json.string("laptop")),
            #("public_key", json.string(public_key)),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(create)
    let assert True = route_test_support.contains(create, "\"id\":")
    let body = route_test_support.body(create)
    let assert Ok(key_id) =
      json.parse(body, decode.at(["id"], decode.string))

    let deleted =
      route_test_support.dispatch(
        route_test_support.delete("/api/ssh-keys/" <> key_id, token),
        ctx,
      )
    let assert 204 = route_test_support.status(deleted)

    let list =
      route_test_support.dispatch(
        route_test_support.get("/api/ssh-keys", option.Some(token)),
        ctx,
      )
    let assert 200 = route_test_support.status(list)
    let assert False = route_test_support.contains(list, "ssh-ed25519")

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn api_create_org_duplicate_slug_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "user_1")
    let body =
      json.object([
        #("slug", json.string("acme")),
        #("name", json.string("Acme Corp")),
      ])

    let first =
      route_test_support.dispatch(
        route_test_support.post_json("/api/orgs", token, body),
        ctx,
      )
    let assert 201 = route_test_support.status(first)

    let dup =
      route_test_support.dispatch(
        route_test_support.post_json("/api/orgs", token, body),
        ctx,
      )
    let assert 409 = route_test_support.status(dup)
    let assert True = route_test_support.contains(dup, "Organization slug already exists")

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn api_me_with_clerk_client_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let clerk = Client(secret_key: "sk_test_invalid")
    let #(ctx, sign) =
      route_test_support.authenticated_with_clerk(db, root, clerk)
    let token = route_test_support.bearer_token(sign, "user_1")

    let me =
      route_test_support.dispatch(
        route_test_support.get("/api/me", option.Some(token)),
        ctx,
      )
    let assert 200 = route_test_support.status(me)
    let assert True = route_test_support.contains(me, "\"id\":\"user_1\"")

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn api_delete_repo_owner_only_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let owner = route_test_support.bearer_token(sign, "owner")
    let disk = "acme/demo.git"
    let work = route_test_support.clone_git_fixture(root, disk)
    let _ = fixtures.seed_org(db, "acme", "owner")
    let assert Ok(_) =
      database.insert_repo(db, "acme", "demo", option.None, disk)
    fixtures.seed_org_member(db, "acme", "member", "member")
    let member = route_test_support.bearer_token(sign, "member")
    let forbidden =
      route_test_support.dispatch(
        route_test_support.delete("/api/orgs/acme/repos/demo", member),
        ctx,
      )
    let assert 403 = route_test_support.status(forbidden)

    let ok =
      route_test_support.dispatch(
        route_test_support.delete("/api/orgs/acme/repos/demo", owner),
        ctx,
      )
    let assert 204 = route_test_support.status(ok)
    route_test_support.cleanup_fixture_repo(work)
    route_test_support.cleanup_repos_root(root)
    Nil
  })
}
