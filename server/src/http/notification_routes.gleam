import database
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import http/web.{type Context}
import json/api as json_api
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

fn json_ok(body: json.Json, status: Int) -> Response {
  json.to_string(body) |> wisp.json_response(status)
}

pub fn list_notifications(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      let limit = query_int(req, "limit", 50, 1, 100)
      let offset = query_int(req, "offset", 0, 0, 10_000)
      case database.list_notifications(ctx.repo(), user_id(ctx), limit, offset) {
        Ok(notifications) ->
          json_ok(json_api.notifications_json(notifications), 200)
        Error(_) -> wisp.internal_server_error()
      }
    }
  }
}

pub fn mark_read(req: Request, ctx: Context, notification_id: String) -> Response {
  use <- wisp.require_method(req, http.Patch)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case
        database.mark_notification_read(
          ctx.repo(),
          notification_id,
          user_id(ctx),
        )
      {
        Ok(True) -> wisp.response(204)
        Ok(False) -> wisp.not_found()
        Error(_) -> wisp.internal_server_error()
      }
  }
}

pub fn mark_all_read(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Post)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case database.mark_all_notifications_read(ctx.repo(), user_id(ctx)) {
        Ok(Nil) -> wisp.response(204)
        Error(_) -> wisp.internal_server_error()
      }
  }
}

fn query_int(
  req: Request,
  key: String,
  default: Int,
  min: Int,
  max: Int,
) -> Int {
  case list.find(wisp.get_query(req), fn(pair) { pair.0 == key }) {
    Ok(#(_, value)) ->
      case int.parse(value) {
        Ok(n) -> int.clamp(n, min, max)
        Error(_) -> default
      }
    Error(_) -> default
  }
}
