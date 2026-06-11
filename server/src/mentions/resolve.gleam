import database
import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string
import http/clerk_api
import http/web.{type Context}
import mentions/parse

pub fn for_org(
  ctx: Context,
  org_slug: String,
  body: String,
) -> List(String) {
  resolve_handles(ctx, org_slug, parse.handles(body))
}

fn resolve_handles(
  ctx: Context,
  org_slug: String,
  handles: List(String),
) -> List(String) {
  case handles {
    [] -> []
    _ ->
      case database.list_org_members(ctx.repo(), org_slug) {
        Error(_) -> []
        Ok(members) -> {
          let aliases = member_aliases(ctx, members)
          handles
          |> list.map(normalize)
          |> list.unique
          |> list.flat_map(fn(handle) {
            case dict.get(aliases, handle) {
              Ok(user_id) -> [user_id]
              Error(_) -> []
            }
          })
          |> list.unique
        }
      }
  }
}

fn normalize(handle: String) -> String {
  string.lowercase(string.trim(handle))
}

fn member_aliases(
  ctx: Context,
  members: List(database.OrgMemberRow),
) -> Dict(String, String) {
  let user_ids = list.map(members, fn(member) { member.user_id })
  let usernames = case ctx.clerk {
    option.Some(client) ->
      case clerk_api.lookup_usernames(client, user_ids) {
        Ok(map) -> map
        Error(_) -> dict.new()
      }
    option.None -> dict.new()
  }

  list.fold(members, dict.new(), fn(aliases, member) {
    let with_id = dict.insert(aliases, normalize(member.user_id), member.user_id)
    case dict.get(usernames, member.user_id) {
      Ok(username) -> dict.insert(with_id, normalize(username), member.user_id)
      Error(_) -> with_id
    }
  })
}
