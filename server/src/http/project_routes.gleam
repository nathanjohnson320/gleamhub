import database.{
  type ProjectError, delete_project_column, delete_project_item, get_project,
  get_project_board, insert_project, insert_project_column, insert_project_item,
  list_projects, member_can_write, move_project_item, update_project,
  update_project_column,
}
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
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

pub fn project_error_response(error: ProjectError) -> Response {
  let message = case error {
    database.InvalidProjectTitle -> "Invalid project title"
    database.ProjectNotFound -> "Project not found"
    database.InvalidProjectColumn -> "Invalid project column"
    database.InvalidProjectItem -> "Invalid project item"
    database.InvalidItemType -> "Invalid item type"
  }
  let status = case error {
    database.ProjectNotFound -> 404
    _ -> 400
  }
  json.object([#("error", json.string(message))])
  |> json.to_string
  |> wisp.json_response(status)
}

fn with_org(
  ctx: Context,
  org_slug: String,
  run: fn() -> Response,
) -> Response {
  case org_access.require_member(ctx, user_id(ctx), org_slug) {
    Error(_) -> wisp.response(403)
    Ok(_) -> run()
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

fn parse_project_number(number_str: String) -> Result(Int, Response) {
  case int.parse(number_str) {
    Ok(number) if number > 0 -> Ok(number)
    _ -> Error(wisp.bad_request("Invalid project number"))
  }
}

pub fn list_org_projects(
  req: Request,
  ctx: Context,
  org_slug: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      with_org(ctx, org_slug, fn() {
        case list_projects(ctx.repo(), org_slug) {
          Ok(projects) -> json_ok(json_api.projects_json(projects), 200)
          Error(_) -> wisp.internal_server_error()
        }
      })
  }
}

pub fn create_org_project(
  req: Request,
  ctx: Context,
  org_slug: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      require_write(ctx, org_slug, fn() {
        with_org(ctx, org_slug, fn() {
          let decoder = {
            use title <- decode.field("title", decode.string)
            use description <- decode.optional_field(
              "description",
              option.None,
              decode.optional(decode.string),
            )
            decode.success(#(title, description))
          }
          case decode.run(json_body, decoder) {
            Error(_) -> wisp.bad_request("Invalid JSON body")
            Ok(#(title, description)) ->
              case
                insert_project(
                  ctx.repo(),
                  org_slug,
                  title,
                  description,
                  user_id(ctx),
                )
              {
                Ok(project) -> json_ok(json_api.project_json(project), 201)
                Error(e) -> project_error_response(e)
              }
          }
        })
      })
  }
}

pub fn get_org_project(
  req: Request,
  ctx: Context,
  org_slug: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_project_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_org(ctx, org_slug, fn() {
            case get_project(ctx.repo(), org_slug, number) {
              Ok(option.None) -> wisp.not_found()
              Ok(option.Some(project)) ->
                json_ok(json_api.project_json(project), 200)
              Error(_) -> wisp.internal_server_error()
            }
          })
      }
  }
}

pub fn update_org_project(
  req: Request,
  ctx: Context,
  org_slug: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Patch)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      require_write(ctx, org_slug, fn() {
        case parse_project_number(number_str) {
          Error(r) -> r
          Ok(number) ->
            with_org(ctx, org_slug, fn() {
              case get_project(ctx.repo(), org_slug, number) {
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
                    use state <- decode.optional_field(
                      "state",
                      option.None,
                      decode.optional(decode.string),
                    )
                    decode.success(#(title, description, state))
                  }
                  case decode.run(json_body, decoder) {
                    Error(_) -> wisp.bad_request("Invalid JSON body")
                    Ok(#(title, description, state)) -> {
                      let next_title = case title {
                        option.Some(t) -> string.trim(t)
                        option.None -> existing.title
                      }
                      let next_description = case description {
                        option.Some(d) -> option.Some(d)
                        option.None -> existing.description
                      }
                      let next_state = case state {
                        option.Some(s) -> s
                        option.None -> existing.state
                      }
                      case
                        update_project(
                          ctx.repo(),
                          org_slug,
                          number,
                          next_title,
                          next_description,
                          next_state,
                        )
                      {
                        Ok(project) ->
                          json_ok(json_api.project_json(project), 200)
                        Error(e) -> project_error_response(e)
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

pub fn get_org_project_board(
  req: Request,
  ctx: Context,
  org_slug: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_project_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_org(ctx, org_slug, fn() {
            case get_project_board(ctx.repo(), org_slug, number) {
              Ok(option.None) -> wisp.not_found()
              Ok(option.Some(board)) ->
                json_ok(json_api.project_board_json(board), 200)
              Error(_) -> wisp.internal_server_error()
            }
          })
      }
  }
}

pub fn create_org_project_item(
  req: Request,
  ctx: Context,
  org_slug: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      require_write(ctx, org_slug, fn() {
        case parse_project_number(number_str) {
          Error(r) -> r
          Ok(number) ->
            with_org(ctx, org_slug, fn() {
              let decoder = {
                use item_type <- decode.field("item_type", decode.string)
                use repo_name <- decode.field("repo_name", decode.string)
                use item_number <- decode.field("number", decode.int)
                decode.success(#(item_type, repo_name, item_number))
              }
              case decode.run(json_body, decoder) {
                Error(_) -> wisp.bad_request("Invalid JSON body")
                Ok(#(item_type, repo_name, item_number)) ->
                  case
                    insert_project_item(
                      ctx.repo(),
                      org_slug,
                      number,
                      repo_name,
                      item_type,
                      item_number,
                    )
                  {
                    Ok(item) -> json_ok(json_api.project_item_json(item), 201)
                    Error(e) -> project_error_response(e)
                  }
              }
            })
        }
      })
  }
}

pub fn update_org_project_item(
  req: Request,
  ctx: Context,
  org_slug: String,
  number_str: String,
  item_id: String,
) -> Response {
  use <- wisp.require_method(req, http.Patch)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      require_write(ctx, org_slug, fn() {
        case parse_project_number(number_str) {
          Error(r) -> r
          Ok(number) ->
            with_org(ctx, org_slug, fn() {
              let decoder = {
                use column_id <- decode.field("column_id", decode.string)
                use position <- decode.field("position", decode.int)
                decode.success(#(column_id, position))
              }
              case decode.run(json_body, decoder) {
                Error(_) -> wisp.bad_request("Invalid JSON body")
                Ok(#(column_id, position)) ->
                  case
                    move_project_item(
                      ctx.repo(),
                      org_slug,
                      number,
                      item_id,
                      column_id,
                      position,
                    )
                  {
                    Ok(item) -> json_ok(json_api.project_item_json(item), 200)
                    Error(e) -> project_error_response(e)
                  }
              }
            })
        }
      })
  }
}

pub fn delete_org_project_item(
  req: Request,
  ctx: Context,
  org_slug: String,
  number_str: String,
  item_id: String,
) -> Response {
  use <- wisp.require_method(req, http.Delete)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      require_write(ctx, org_slug, fn() {
        case parse_project_number(number_str) {
          Error(r) -> r
          Ok(number) ->
            with_org(ctx, org_slug, fn() {
              case delete_project_item(ctx.repo(), org_slug, number, item_id) {
                Ok(Nil) -> wisp.response(204)
                Error(e) -> project_error_response(e)
              }
            })
        }
      })
  }
}

pub fn create_org_project_column(
  req: Request,
  ctx: Context,
  org_slug: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      require_write(ctx, org_slug, fn() {
        case parse_project_number(number_str) {
          Error(r) -> r
          Ok(number) ->
            with_org(ctx, org_slug, fn() {
              let decoder = {
                use name <- decode.field("name", decode.string)
                use position <- decode.field("position", decode.int)
                decode.success(#(name, position))
              }
              case decode.run(json_body, decoder) {
                Error(_) -> wisp.bad_request("Invalid JSON body")
                Ok(#(name, position)) ->
                  case
                    insert_project_column(
                      ctx.repo(),
                      org_slug,
                      number,
                      name,
                      position,
                    )
                  {
                    Ok(column) ->
                      json_ok(json_api.project_column_json(column), 201)
                    Error(e) -> project_error_response(e)
                  }
              }
            })
        }
      })
  }
}

pub fn update_org_project_column(
  req: Request,
  ctx: Context,
  org_slug: String,
  number_str: String,
  column_id: String,
) -> Response {
  use <- wisp.require_method(req, http.Patch)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      require_write(ctx, org_slug, fn() {
        case parse_project_number(number_str) {
          Error(r) -> r
          Ok(number) ->
            with_org(ctx, org_slug, fn() {
              case get_project_board(ctx.repo(), org_slug, number) {
                Ok(option.None) -> wisp.not_found()
                Ok(option.Some(board)) -> {
                  let existing_column =
                    list.find(board.columns, fn(column) {
                      column.id == column_id
                    })
                  case existing_column {
                    Error(_) -> wisp.not_found()
                    Ok(existing) -> {
                      let decoder = {
                        use name <- decode.optional_field(
                          "name",
                          option.None,
                          decode.optional(decode.string),
                        )
                        use position <- decode.optional_field(
                          "position",
                          option.None,
                          decode.optional(decode.int),
                        )
                        decode.success(#(name, position))
                      }
                      case decode.run(json_body, decoder) {
                        Error(_) -> wisp.bad_request("Invalid JSON body")
                        Ok(#(name, position)) -> {
                          let next_name = case name {
                            option.Some(n) -> string.trim(n)
                            option.None -> existing.name
                          }
                          let next_position = case position {
                            option.Some(p) -> p
                            option.None -> existing.position
                          }
                          case
                            update_project_column(
                              ctx.repo(),
                              org_slug,
                              number,
                              column_id,
                              next_name,
                              next_position,
                            )
                          {
                            Ok(column) ->
                              json_ok(json_api.project_column_json(column), 200)
                            Error(e) -> project_error_response(e)
                          }
                        }
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

pub fn delete_org_project_column(
  req: Request,
  ctx: Context,
  org_slug: String,
  number_str: String,
  column_id: String,
) -> Response {
  use <- wisp.require_method(req, http.Delete)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      require_write(ctx, org_slug, fn() {
        case parse_project_number(number_str) {
          Error(r) -> r
          Ok(number) ->
            with_org(ctx, org_slug, fn() {
              case delete_project_column(ctx.repo(), org_slug, number, column_id) {
                Ok(Nil) -> wisp.response(204)
                Error(e) -> project_error_response(e)
              }
            })
        }
      })
  }
}

pub fn project_by_number(
  req: Request,
  ctx: Context,
  org_slug: String,
  number_str: String,
) -> Response {
  case req.method {
    http.Get -> get_org_project(req, ctx, org_slug, number_str)
    http.Patch -> update_org_project(req, ctx, org_slug, number_str)
    _ -> wisp.method_not_allowed([http.Get, http.Patch])
  }
}

pub fn project_item_by_id(
  req: Request,
  ctx: Context,
  org_slug: String,
  number_str: String,
  item_id: String,
) -> Response {
  case req.method {
    http.Patch ->
      update_org_project_item(req, ctx, org_slug, number_str, item_id)
    http.Delete ->
      delete_org_project_item(req, ctx, org_slug, number_str, item_id)
    _ -> wisp.method_not_allowed([http.Patch, http.Delete])
  }
}

pub fn project_column_by_id(
  req: Request,
  ctx: Context,
  org_slug: String,
  number_str: String,
  column_id: String,
) -> Response {
  case req.method {
    http.Patch ->
      update_org_project_column(req, ctx, org_slug, number_str, column_id)
    http.Delete ->
      delete_org_project_column(req, ctx, org_slug, number_str, column_id)
    _ -> wisp.method_not_allowed([http.Patch, http.Delete])
  }
}
