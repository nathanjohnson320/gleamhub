import app/database
import app/json_api
import app/org_access
import app/web.{type Context}
import gleam/http
import gleam/json
import gleam/list
import gleam/option
import wisp.{type Request, type Response}

pub fn authorized_keys(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Get)
  let key_blob = query_param(req, "k")
  case key_blob {
    "" -> plain_text("", 200)
    blob -> {
      case database.authorized_key_line(ctx.repo(), blob) {
        Ok(option.Some(line)) -> plain_text(line <> "\n", 200)
        Ok(option.None) -> plain_text("", 200)
        Error(_) -> wisp.internal_server_error()
      }
    }
  }
}

pub fn access_check(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Get)
  let org = query_param(req, "org")
  let repo = query_param(req, "repo")
  let user_id = query_param(req, "user_id")
  let op = query_param(req, "op")

  let receive_pack = op == "receive-pack"

  let access = org_access.git_access(ctx, user_id, org, repo, receive_pack)

  let allowed = case receive_pack {
    True -> access.write
    False -> access.read
  }

  case allowed {
    True ->
      json_api.access_json(access.read, access.write)
      |> json.to_string
      |> wisp.json_response(200)
    False -> wisp.response(403)
  }
}

fn plain_text(body: String, status: Int) -> Response {
  wisp.response(status)
  |> wisp.set_header("content-type", "text/plain; charset=utf-8")
  |> wisp.string_body(body)
}

fn query_param(req: Request, name: String) -> String {
  case list.find(wisp.get_query(req), fn(pair) {
    let #(key, _) = pair
    key == name
  }) {
    Ok(#(_, value)) -> value
    Error(_) -> ""
  }
}
