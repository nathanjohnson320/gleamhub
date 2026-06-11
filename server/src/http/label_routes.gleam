import database
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/option
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

pub fn label_error_response(error: database.LabelError) -> Response {
  let message = case error {
    database.InvalidLabelName -> "Invalid label name"
    database.InvalidLabelColor -> "Invalid label color"
    database.DuplicateLabelName -> "A label with that name already exists"
    database.LabelNotFound -> "Label not found"
    database.InvalidLabelIds ->
      "One or more labels are invalid for this repository"
    database.InvalidAssignees ->
      "One or more assignees are not members of this organization"
    database.AuthorCannotReview ->
      "Authors cannot be reviewers on their own merge requests"
  }
  json.object([#("error", json.string(message))])
  |> json.to_string
  |> wisp.json_response(400)
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
  case database.member_can_write(ctx.repo(), user_id(ctx), org_slug) {
    True -> run()
    False -> wisp.response(403)
  }
}

pub fn list_labels(
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
        case database.list_repo_labels(ctx.repo(), org_slug, repo_name) {
          Ok(labels) -> json_ok(json_api.labels_json(labels), 200)
          Error(_) -> wisp.internal_server_error()
        }
      })
  }
}

pub fn create_label(
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
            use name <- decode.field("name", decode.string)
            use color <- decode.field("color", decode.optional(decode.string))
            decode.success(#(name, color))
          }
          case decode.run(json_body, decoder) {
            Error(_) -> wisp.bad_request("Invalid JSON body")
            Ok(#(name, color)) -> {
              let color = case color {
                option.Some(c) -> c
                option.None -> ""
              }
              case
                database.insert_repo_label(
                  ctx.repo(),
                  org_slug,
                  repo_name,
                  name,
                  color,
                )
              {
                Ok(label) -> json_ok(json_api.label_json(label), 201)
                Error(e) -> label_error_response(e)
              }
            }
          }
        })
      })
  }
}

pub fn delete_label(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  label_id: String,
) -> Response {
  use <- wisp.require_method(req, http.Delete)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      require_write(ctx, org_slug, fn() {
        with_repo(ctx, org_slug, repo_name, fn() {
          case
            database.delete_repo_label(
              ctx.repo(),
              org_slug,
              repo_name,
              label_id,
            )
          {
            Ok(True) -> wisp.response(204)
            Ok(False) -> wisp.not_found()
            Error(_) -> wisp.internal_server_error()
          }
        })
      })
  }
}

pub fn update_label(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  label_id: String,
) -> Response {
  use <- wisp.require_method(req, http.Patch)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      require_write(ctx, org_slug, fn() {
        with_repo(ctx, org_slug, repo_name, fn() {
          let decoder = {
            use name <- decode.optional_field(
              "name",
              option.None,
              decode.optional(decode.string),
            )
            use color <- decode.optional_field(
              "color",
              option.None,
              decode.optional(decode.string),
            )
            decode.success(#(name, color))
          }
          case decode.run(json_body, decoder) {
            Error(_) -> wisp.bad_request("Invalid JSON body")
            Ok(#(name, color)) ->
              case name, color {
                option.None, option.None ->
                  wisp.bad_request("At least one of name or color is required")
                _, _ ->
                  case
                    database.update_repo_label(
                      ctx.repo(),
                      org_slug,
                      repo_name,
                      label_id,
                      name,
                      color,
                    )
                  {
                    Ok(label) -> json_ok(json_api.label_json(label), 200)
                    Error(e) -> label_error_response(e)
                  }
              }
          }
        })
      })
  }
}

pub fn label_by_id(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  label_id: String,
) -> Response {
  case req.method {
    http.Patch -> update_label(req, ctx, org_slug, repo_name, label_id)
    http.Delete -> delete_label(req, ctx, org_slug, repo_name, label_id)
    _ -> wisp.method_not_allowed([http.Patch, http.Delete])
  }
}
