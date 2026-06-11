import database
import gleam/dict
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import http/clerk_api
import http/org_access
import http/user_display
import http/web.{type Context}
import json/api as json_api
import notifications/create as notify
import wisp.{type Request, type Response}

fn user_id(ctx: Context) -> String {
  let assert option.Some(id) = ctx.user_id
  id
}

fn ensure_user(ctx: Context) -> Result(Nil, Response) {
  case ctx.user_id {
    option.Some(_) -> Ok(Nil)
    option.None -> Error(wisp.response(401))
  }
}

fn member_error_response(error: database.MemberError) -> Response {
  case error {
    database.AlreadyMember
    | database.AlreadyInvited
    | database.CannotInviteSelf -> wisp.response(409)
    database.LastOwner -> wisp.unprocessable_content()
    database.NotMember
    | database.InvitationNotFound
    | database.NotInvitationTarget -> wisp.not_found()
  }
}

fn query_param(req: Request, key: String) -> option.Option(String) {
  case list.find(wisp.get_query(req), fn(pair) { pair.0 == key }) {
    Ok(#(_, value)) -> option.Some(value)
    Error(_) -> option.None
  }
}

fn clerk_unavailable_response() -> Response {
  json.object([
    #(
      "error",
      json.string(
        "User search requires CLERK_SECRET_KEY to be configured on the server.",
      ),
    ),
  ])
  |> json.to_string
  |> wisp.json_response(503)
}

pub fn search_users(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      case ctx.clerk {
        option.None -> clerk_unavailable_response()
        option.Some(client) -> {
          let query =
            query_param(req, "q")
            |> option.unwrap("")
            |> string.trim
          case string.length(query) < 2 {
            True -> wisp.json_response("[]", 200)
            False -> {
              case clerk_api.search_users(client, query) {
                Ok(users) -> {
                  let org_slug = query_param(req, "org")
                  let excluded = excluded_user_ids(ctx, org_slug)
                  let results =
                    users
                    |> list.filter(fn(user) {
                      !list.contains(excluded, user.id)
                    })
                    |> list.map(fn(user) {
                      #(
                        user.id,
                        clerk_api.username(user),
                        clerk_api.display_name(user),
                      )
                    })
                  json_api.user_search_results_json(results)
                  |> json.to_string
                  |> wisp.json_response(200)
                }
                Error(clerk_api.InvalidResponse) ->
                  json.object([
                    #(
                      "error",
                      json.string(
                        "Could not decode Clerk user search response.",
                      ),
                    ),
                  ])
                  |> json.to_string
                  |> wisp.json_response(502)
                Error(clerk_api.BadStatus(401))
                | Error(clerk_api.BadStatus(403)) ->
                  json.object([
                    #(
                      "error",
                      json.string(
                        "Clerk rejected the server API key - check CLERK_SECRET_KEY.",
                      ),
                    ),
                  ])
                  |> json.to_string
                  |> wisp.json_response(503)
                Error(_) -> wisp.internal_server_error()
              }
            }
          }
        }
      }
    }
  }
}

fn excluded_user_ids(
  ctx: Context,
  org_slug: option.Option(String),
) -> List(String) {
  let current = case ctx.user_id {
    option.Some(id) -> [id]
    option.None -> []
  }
  case org_slug {
    option.None -> current
    option.Some(slug) ->
      case database.list_org_member_ids(ctx.repo(), slug) {
        Ok(ids) -> list.unique(list.append(current, ids))
        Error(_) -> current
      }
  }
}

pub fn list_members(req: Request, ctx: Context, slug: String) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      case org_access.require_member(ctx, user_id(ctx), slug) {
        Error(_) -> wisp.response(403)
        Ok(_) ->
          case database.list_org_members(ctx.repo(), slug) {
            Ok(members) -> {
              let ids = list.map(members, fn(member) { member.user_id })
              let names = user_display.display_names(ctx, ids)
              let usernames = clerk_usernames(ctx, ids)
              json_api.members_json(members, names, usernames)
              |> json.to_string
              |> wisp.json_response(200)
            }
            Error(_) -> wisp.internal_server_error()
          }
      }
    }
  }
}

pub fn update_member_role(
  req: Request,
  ctx: Context,
  slug: String,
  member_id: String,
) -> Response {
  use <- wisp.require_method(req, http.Patch)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      case org_access.require_owner(ctx, user_id(ctx), slug) {
        Error(_) -> wisp.response(403)
        Ok(_) -> {
          let decoder = {
            use role <- decode.field("role", decode.string)
            decode.success(role)
          }
          case decode.run(json_body, decoder) {
            Error(_) -> wisp.bad_request("Invalid JSON")
            Ok(role_str) ->
              case parse_org_role(option.Some(role_str)) {
                Error(r) -> r
                Ok(role) ->
                  case
                    database.update_member_role(
                      ctx.repo(),
                      slug,
                      member_id,
                      role,
                    )
                  {
                    Ok(Nil) ->
                      case database.list_org_members(ctx.repo(), slug) {
                        Ok(members) ->
                          case
                            list.find(members, fn(member) {
                              member.user_id == member_id
                            })
                          {
                            Ok(member) -> member_json_response(ctx, member)
                            Error(_) -> wisp.not_found()
                          }
                        Error(_) -> wisp.internal_server_error()
                      }
                    Error(e) -> member_error_response(e)
                  }
              }
          }
        }
      }
    }
  }
}

pub fn remove_member(
  req: Request,
  ctx: Context,
  slug: String,
  member_id: String,
) -> Response {
  use <- wisp.require_method(req, http.Delete)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      case org_access.require_owner(ctx, user_id(ctx), slug) {
        Error(_) -> wisp.response(403)
        Ok(_) ->
          case database.remove_org_member(ctx.repo(), slug, member_id) {
            Ok(_) -> wisp.no_content()
            Error(e) -> member_error_response(e)
          }
      }
    }
  }
}

pub fn list_org_invitations(
  req: Request,
  ctx: Context,
  slug: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      case org_access.require_owner(ctx, user_id(ctx), slug) {
        Error(_) -> wisp.response(403)
        Ok(_) ->
          invitations_response(
            ctx,
            database.list_org_invitations(ctx.repo(), slug),
          )
      }
    }
  }
}

pub fn create_invitation(req: Request, ctx: Context, slug: String) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      case org_access.require_owner(ctx, user_id(ctx), slug) {
        Error(_) -> wisp.response(403)
        Ok(_) -> {
          let decoder = {
            use invited_user_id <- decode.field("user_id", decode.string)
            use role <- decode.optional_field(
              "role",
              option.None,
              decode.optional(decode.string),
            )
            decode.success(#(invited_user_id, role))
          }
          case decode.run(json, decoder) {
            Error(_) -> wisp.bad_request("Invalid JSON")
            Ok(#(invited_user_id, role_opt)) -> {
              case parse_org_role(role_opt) {
                Error(r) -> r
                Ok(role) -> {
                  let _ = upsert_invited_user(ctx, invited_user_id)
                  case
                    database.create_org_invitation(
                      ctx.repo(),
                      slug,
                      invited_user_id,
                      user_id(ctx),
                      role,
                    )
                  {
                    Ok(invitation) -> {
                      let invitation = case
                        database.get_invitation(ctx.repo(), invitation.id)
                      {
                        Ok(option.Some(full)) -> full
                        _ -> invitation
                      }
                      let ids = [
                        invitation.invited_user_id,
                        invitation.invited_by_user_id,
                      ]
                      let names = user_display.display_names(ctx, ids)
                      let usernames = clerk_usernames(ctx, ids)
                      let invited_name = case
                        dict_get(names, invitation.invited_user_id)
                      {
                        option.Some(name) -> name
                        option.None -> invitation.invited_user_id
                      }
                      let invited_by_name = case
                        dict_get(names, invitation.invited_by_user_id)
                      {
                        option.Some(name) -> name
                        option.None -> invitation.invited_by_user_id
                      }
                      let org_name = invitation.org_name
                        |> option.unwrap("Organization")
                      let org_slug = invitation.org_slug
                        |> option.unwrap("")
                      let _ = notify.org_invitation_received(
                        ctx,
                        user_id(ctx),
                        invitation.invited_user_id,
                        org_slug,
                        org_name,
                        invitation.id,
                        invitation.role,
                      )
                      json_api.invitation_json(
                        invitation,
                        invited_name,
                        dict_get(usernames, invitation.invited_user_id),
                        invited_by_name,
                        dict_get(usernames, invitation.invited_by_user_id),
                      )
                      |> json.to_string
                      |> wisp.json_response(201)
                    }
                    Error(e) -> member_error_response(e)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

pub fn cancel_invitation(
  req: Request,
  ctx: Context,
  slug: String,
  invitation_id: String,
) -> Response {
  use <- wisp.require_method(req, http.Delete)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      case org_access.require_owner(ctx, user_id(ctx), slug) {
        Error(_) -> wisp.response(403)
        Ok(_) ->
          case database.cancel_org_invitation(ctx.repo(), slug, invitation_id) {
            Ok(_) -> wisp.no_content()
            Error(e) -> member_error_response(e)
          }
      }
    }
  }
}

pub fn list_my_invitations(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      invitations_response(
        ctx,
        database.list_invitations_for_user(ctx.repo(), user_id(ctx)),
      )
  }
}

pub fn accept_invitation(
  req: Request,
  ctx: Context,
  invitation_id: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case database.accept_invitation(ctx.repo(), invitation_id, user_id(ctx)) {
        Ok(org_slug) ->
          json.object([#("org_slug", json.string(org_slug))])
          |> json.to_string
          |> wisp.json_response(200)
        Error(e) -> member_error_response(e)
      }
  }
}

pub fn decline_invitation(
  req: Request,
  ctx: Context,
  invitation_id: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case
        database.decline_invitation(ctx.repo(), invitation_id, user_id(ctx))
      {
        Ok(_) -> wisp.no_content()
        Error(e) -> member_error_response(e)
      }
  }
}

fn invitations_response(
  ctx: Context,
  result: Result(List(database.OrgInvitationRow), _),
) -> Response {
  case result {
    Ok(invitations) -> {
      let invited_ids =
        list.map(invitations, fn(invitation) { invitation.invited_user_id })
      let invited_by_ids =
        list.map(invitations, fn(invitation) { invitation.invited_by_user_id })
      let ids = list.unique(list.append(invited_ids, invited_by_ids))
      let names = user_display.display_names(ctx, ids)
      let usernames = clerk_usernames(ctx, ids)
      json_api.invitations_json(invitations, names, usernames)
      |> json.to_string
      |> wisp.json_response(200)
    }
    Error(_) -> wisp.internal_server_error()
  }
}

fn clerk_usernames(
  ctx: Context,
  user_ids: List(String),
) -> dict.Dict(String, String) {
  case ctx.clerk {
    option.Some(client) ->
      clerk_api.lookup_usernames(client, user_ids)
      |> result.unwrap(dict.new())
    option.None -> dict.new()
  }
}

fn upsert_invited_user(ctx: Context, invited_user_id: String) -> Nil {
  let #(display_name, email) = case ctx.clerk {
    option.Some(client) ->
      clerk_api.profile_for_user(client, invited_user_id)
      |> result.unwrap(#(option.None, option.None))
    option.None -> #(option.None, option.None)
  }
  let _ = database.upsert_user(ctx.repo(), invited_user_id, display_name, email)
  Nil
}

fn dict_get(
  dict: dict.Dict(String, String),
  key: String,
) -> option.Option(String) {
  case dict.get(dict, key) {
    Ok(value) -> option.Some(value)
    Error(_) -> option.None
  }
}

fn parse_org_role(role: option.Option(String)) -> Result(String, Response) {
  case role {
    option.None -> Ok("member")
    option.Some("owner") -> Ok("owner")
    option.Some("member") -> Ok("member")
    option.Some(_) -> Error(wisp.bad_request("Invalid role"))
  }
}

fn member_json_response(
  ctx: Context,
  member: database.OrgMemberRow,
) -> Response {
  let names = user_display.display_names(ctx, [member.user_id])
  let usernames = clerk_usernames(ctx, [member.user_id])
  let display_name = case dict_get(names, member.user_id) {
    option.Some(name) -> name
    option.None ->
      member.display_name
      |> option.unwrap(member.user_id)
  }
  json_api.member_json(
    member,
    display_name,
    dict_get(usernames, member.user_id),
  )
  |> json.to_string
  |> wisp.json_response(200)
}
