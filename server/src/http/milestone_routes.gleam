import database.{
  type MilestoneError, close_milestone, get_milestone,
  insert_milestone, list_milestones, member_can_write, update_milestone,
}
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option
import gleam/string
import http/org_access
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

pub fn milestone_error_response(error: MilestoneError) -> Response {
  let message = case error {
    database.InvalidMilestoneTitle -> "Invalid milestone title"
    database.MilestoneNotFound -> "Milestone not found"
    database.InvalidMilestone -> "Invalid milestone"
  }
  let status = case error {
    database.MilestoneNotFound -> 404
    _ -> 400
  }
  json.object([#("error", json.string(message))])
  |> json.to_string
  |> wisp.json_response(status)
}

fn with_repo(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  run: fn() -> Response,
) -> Response {
  case org_access.require_member(ctx, user_id(ctx), org_slug) {
    Error(_) -> wisp.response(403)
    Ok(_) ->
      case database.get_repo(ctx.repo(), org_slug, repo_name) {
        Ok(option.None) -> wisp.not_found()
        Ok(option.Some(_)) -> run()
        Error(_) -> wisp.internal_server_error()
      }
  }
}

fn require_write(
  ctx: Context,
  org_slug: String,
  run: fn() -> Response,
) -> Response {
  case member_can_write(ctx.repo(), user_id(ctx), org_slug) {
    True -> run()
    False -> wisp.response(403)
  }
}

fn parse_milestone_number(number_str: String) -> Result(Int, Response) {
  case int.parse(number_str) {
    Ok(number) if number > 0 -> Ok(number)
    _ -> Error(wisp.bad_request("Invalid milestone number"))
  }
}

pub fn list_repo_milestones(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      with_repo(ctx, org_slug, repo_name, fn() {
        case list_milestones(ctx.repo(), org_slug, repo_name) {
          Ok(milestones) -> json_ok(json_api.milestones_json(milestones), 200)
          Error(_) -> wisp.internal_server_error()
        }
      })
  }
}

pub fn get_repo_milestone(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_milestone_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_repo(ctx, org_slug, repo_name, fn() {
            case get_milestone(ctx.repo(), org_slug, repo_name, number) {
              Ok(option.None) -> wisp.not_found()
              Ok(option.Some(milestone)) ->
                json_ok(json_api.milestone_json(milestone), 200)
              Error(_) -> wisp.internal_server_error()
            }
          })
      }
  }
}

pub fn create_repo_milestone(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      require_write(ctx, org_slug, fn() {
        with_repo(ctx, org_slug, repo_name, fn() {
          let decoder = {
            use title <- decode.field("title", decode.string)
            use description <- decode.optional_field(
              "description",
              option.None,
              decode.optional(decode.string),
            )
            use due_on <- decode.optional_field(
              "due_on",
              option.None,
              decode.optional(decode.string),
            )
            decode.success(#(title, description, due_on))
          }
          case decode.run(json_body, decoder) {
            Error(_) -> wisp.bad_request("Invalid JSON body")
            Ok(#(title, description, due_on)) ->
              case
                insert_milestone(
                  ctx.repo(),
                  org_slug,
                  repo_name,
                  title,
                  description,
                  due_on,
                )
              {
                Ok(milestone) ->
                  json_ok(json_api.milestone_json(milestone), 201)
                Error(e) -> milestone_error_response(e)
              }
          }
        })
      })
  }
}

pub fn update_repo_milestone(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Patch)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      require_write(ctx, org_slug, fn() {
        case parse_milestone_number(number_str) {
          Error(r) -> r
          Ok(number) ->
            with_repo(ctx, org_slug, repo_name, fn() {
              case get_milestone(ctx.repo(), org_slug, repo_name, number) {
                Ok(option.None) -> wisp.not_found()
                Ok(option.Some(existing)) -> {
                  let decoder = {
                    use title <- decode.optional_field(
                      "title",
                      option.None,
                      decode.optional(decode.string),
                    )
                    use description <- decode.optional_field(
                      "description",
                      option.None,
                      decode.optional(decode.string),
                    )
                    use due_on <- decode.optional_field(
                      "due_on",
                      option.None,
                      decode.optional(decode.string),
                    )
                    decode.success(#(title, description, due_on))
                  }
                  case decode.run(json_body, decoder) {
                    Error(_) -> wisp.bad_request("Invalid JSON body")
                    Ok(#(title, description, due_on)) -> {
                      let next_title = case title {
                        option.Some(t) -> string.trim(t)
                        option.None -> existing.title
                      }
                      let next_description = case description {
                        option.Some(d) -> option.Some(d)
                        option.None -> existing.description
                      }
                      let next_due_on = case due_on {
                        option.Some(d) -> option.Some(d)
                        option.None -> existing.due_on
                      }
                      case
                        update_milestone(
                          ctx.repo(),
                          org_slug,
                          repo_name,
                          number,
                          next_title,
                          next_description,
                          next_due_on,
                        )
                      {
                        Ok(milestone) ->
                          json_ok(json_api.milestone_json(milestone), 200)
                        Error(e) -> milestone_error_response(e)
                      }
                    }
                  }
                }
                Error(_) -> wisp.internal_server_error()
              }
            })
        }
      })
  }
}

pub fn close_repo_milestone(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      require_write(ctx, org_slug, fn() {
        case parse_milestone_number(number_str) {
          Error(r) -> r
          Ok(number) ->
            with_repo(ctx, org_slug, repo_name, fn() {
              case close_milestone(ctx.repo(), org_slug, repo_name, number) {
                Ok(milestone) ->
                  json_ok(json_api.milestone_json(milestone), 200)
                Error(e) -> milestone_error_response(e)
              }
            })
        }
      })
  }
}

pub fn milestone_by_number(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  case req.method {
    http.Get -> get_repo_milestone(req, ctx, org_slug, repo_name, number_str)
    http.Patch ->
      update_repo_milestone(req, ctx, org_slug, repo_name, number_str)
    _ -> wisp.method_not_allowed([http.Get, http.Patch])
  }
}
