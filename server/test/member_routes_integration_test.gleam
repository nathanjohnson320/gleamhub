import database_integration_fixtures as fixtures
import db_test_support
import gleam/dynamic/decode
import gleam/json
import gleam/option
import route_test_support
import wisp

fn invitation_id_decoder() -> decode.Decoder(String) {
  decode.at(["id"], decode.string)
}

fn first_invitation_id(response: wisp.Response) -> String {
  let assert Ok([id, ..]) =
    json.parse(
      route_test_support.body(response),
      decode.list(invitation_id_decoder()),
    )
  id
}

pub fn member_invite_accept_lifecycle_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let owner_token = route_test_support.bearer_token(sign, "owner")
    let invitee_token = route_test_support.bearer_token(sign, "user_2")
    let _ = fixtures.seed_org(db, "acme", "owner")
    fixtures.seed_user(db, "user_2")

    let invite =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/invitations",
          owner_token,
          json.object([#("user_id", json.string("user_2"))]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(invite)

    let outsider =
      route_test_support.dispatch(
        route_test_support.get("/api/orgs/acme", option.Some(invitee_token)),
        ctx,
      )
    let assert 403 = route_test_support.status(outsider)

    let pending =
      route_test_support.dispatch(
        route_test_support.get("/api/invitations", option.Some(invitee_token)),
        ctx,
      )
    let assert 200 = route_test_support.status(pending)
    let invitation_id = first_invitation_id(pending)

    let accept =
      route_test_support.dispatch(
        route_test_support.post(
          "/api/invitations/" <> invitation_id <> "/accept",
          invitee_token,
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(accept)
    let assert True =
      route_test_support.contains(accept, "\"org_slug\":\"acme\"")

    let member_view =
      route_test_support.dispatch(
        route_test_support.get("/api/orgs/acme", option.Some(invitee_token)),
        ctx,
      )
    let assert 200 = route_test_support.status(member_view)

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn member_invite_permissions_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let owner_token = route_test_support.bearer_token(sign, "owner")
    let member_token = route_test_support.bearer_token(sign, "member")
    let _ = fixtures.seed_org(db, "acme", "owner")
    fixtures.seed_org_member(db, "acme", "member", "member")
    fixtures.seed_user(db, "user_2")

    let member_invite =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/invitations",
          member_token,
          json.object([#("user_id", json.string("user_2"))]),
        ),
        ctx,
      )
    let assert 403 = route_test_support.status(member_invite)

    let owner_invite =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/invitations",
          owner_token,
          json.object([#("user_id", json.string("user_2"))]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(owner_invite)

    let duplicate =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/invitations",
          owner_token,
          json.object([#("user_id", json.string("user_2"))]),
        ),
        ctx,
      )
    let assert 409 = route_test_support.status(duplicate)

    let self_invite =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/invitations",
          owner_token,
          json.object([#("user_id", json.string("owner"))]),
        ),
        ctx,
      )
    let assert 409 = route_test_support.status(self_invite)

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn member_remove_last_owner_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let owner_token = route_test_support.bearer_token(sign, "owner")
    let _ = fixtures.seed_org(db, "solo", "owner")

    let remove =
      route_test_support.dispatch(
        route_test_support.delete("/api/orgs/solo/members/owner", owner_token),
        ctx,
      )
    let assert 422 = route_test_support.status(remove)

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn member_decline_invitation_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let owner_token = route_test_support.bearer_token(sign, "owner")
    let invitee_token = route_test_support.bearer_token(sign, "user_2")
    let _ = fixtures.seed_org(db, "acme", "owner")
    fixtures.seed_user(db, "user_2")

    let _ =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/invitations",
          owner_token,
          json.object([#("user_id", json.string("user_2"))]),
        ),
        ctx,
      )

    let pending =
      route_test_support.dispatch(
        route_test_support.get("/api/invitations", option.Some(invitee_token)),
        ctx,
      )
    let invitation_id = first_invitation_id(pending)

    let decline =
      route_test_support.dispatch(
        route_test_support.post(
          "/api/invitations/" <> invitation_id <> "/decline",
          invitee_token,
        ),
        ctx,
      )
    let assert 204 = route_test_support.status(decline)

    let empty =
      route_test_support.dispatch(
        route_test_support.get("/api/invitations", option.Some(invitee_token)),
        ctx,
      )
    let assert 200 = route_test_support.status(empty)
    let assert Ok([]) =
      json.parse(
        route_test_support.body(empty),
        decode.list(invitation_id_decoder()),
      )

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn member_invite_as_owner_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let owner_token = route_test_support.bearer_token(sign, "owner")
    let invitee_token = route_test_support.bearer_token(sign, "user_2")
    let _ = fixtures.seed_org(db, "acme", "owner")
    fixtures.seed_user(db, "user_2")

    let invite =
      route_test_support.dispatch(
        route_test_support.post_json(
          "/api/orgs/acme/invitations",
          owner_token,
          json.object([
            #("user_id", json.string("user_2")),
            #("role", json.string("owner")),
          ]),
        ),
        ctx,
      )
    let assert 201 = route_test_support.status(invite)
    let assert True = route_test_support.contains(invite, "\"role\":\"owner\"")

    let pending =
      route_test_support.dispatch(
        route_test_support.get("/api/invitations", option.Some(invitee_token)),
        ctx,
      )
    let invitation_id = first_invitation_id(pending)

    let accept =
      route_test_support.dispatch(
        route_test_support.post(
          "/api/invitations/" <> invitation_id <> "/accept",
          invitee_token,
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(accept)

    let members =
      route_test_support.dispatch(
        route_test_support.get(
          "/api/orgs/acme/members",
          option.Some(owner_token),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(members)
    let assert True =
      route_test_support.contains(members, "\"user_id\":\"user_2\"")
    let assert True = route_test_support.contains(members, "\"role\":\"owner\"")

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn member_update_role_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let owner_token = route_test_support.bearer_token(sign, "owner")
    let member_token = route_test_support.bearer_token(sign, "member")
    let _ = fixtures.seed_org(db, "acme", "owner")
    fixtures.seed_org_member(db, "acme", "member", "member")

    let forbidden =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/members/member",
          member_token,
          json.object([#("role", json.string("owner"))]),
        ),
        ctx,
      )
    let assert 403 = route_test_support.status(forbidden)

    let promote =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/acme/members/member",
          owner_token,
          json.object([#("role", json.string("owner"))]),
        ),
        ctx,
      )
    let assert 200 = route_test_support.status(promote)
    let assert True = route_test_support.contains(promote, "\"role\":\"owner\"")

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn member_demote_last_owner_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let owner_token = route_test_support.bearer_token(sign, "owner")
    let _ = fixtures.seed_org(db, "solo", "owner")

    let demote =
      route_test_support.dispatch(
        route_test_support.patch_json(
          "/api/orgs/solo/members/owner",
          owner_token,
          json.object([#("role", json.string("member"))]),
        ),
        ctx,
      )
    let assert 422 = route_test_support.status(demote)

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}

pub fn user_search_requires_clerk_test() {
  db_test_support.with_db(fn(db) {
    let root = route_test_support.repos_root()
    let #(ctx, sign) = route_test_support.authenticated(db, root)
    let token = route_test_support.bearer_token(sign, "owner")

    let res =
      route_test_support.dispatch(
        route_test_support.get("/api/users/search?q=na", option.Some(token)),
        ctx,
      )
    let assert 503 = route_test_support.status(res)

    route_test_support.cleanup_repos_root(root)
    Nil
  })
}
