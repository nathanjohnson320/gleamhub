import app/clerk_api
import app/database as database
import app/json_api
import app/org_access
import app/web.{type Context}
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option
import gleam/string
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

fn hydrate_comments(
  ctx: Context,
  comments: List(database.IssueCommentRow),
) -> List(database.IssueCommentRow) {
  case ctx.clerk {
    option.Some(client) -> clerk_api.hydrate_issue_comments(client, comments)
    option.None -> comments
  }
}

fn hydrate_issues(
  ctx: Context,
  issues: List(database.IssueRow),
) -> List(database.IssueRow) {
  case ctx.clerk {
    option.Some(client) -> clerk_api.hydrate_issues(client, issues)
    option.None -> issues
  }
}

fn hydrate_issue(ctx: Context, issue: database.IssueRow) -> database.IssueRow {
  case ctx.clerk {
    option.Some(client) -> clerk_api.hydrate_issue(client, issue)
    option.None -> issue
  }
}

fn with_repo(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  run: fn(database.RepoRow) -> Response,
) -> Response {
  case org_access.require_member(ctx, user_id(ctx), org_slug) {
    Error(_) -> wisp.response(403)
    Ok(_) ->
      case database.get_repo(ctx.repo(), org_slug, repo_name) {
        Ok(option.None) -> wisp.not_found()
        Ok(option.Some(repo)) -> run(repo)
        Error(_) -> wisp.internal_server_error()
      }
  }
}

fn with_issue(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number: Int,
  run: fn(database.IssueRow) -> Response,
) -> Response {
  with_repo(ctx, org_slug, repo_name, fn(_repo) {
    case database.get_issue(ctx.repo(), org_slug, repo_name, number) {
      Ok(option.None) -> wisp.not_found()
      Ok(option.Some(issue)) -> run(issue)
      Error(_) -> wisp.internal_server_error()
    }
  })
}

fn parse_issue_number(num_str: String) -> Result(Int, Response) {
  case int.parse(num_str) {
    Ok(n) -> Ok(n)
    Error(_) -> Error(wisp.bad_request("Invalid issue number"))
  }
}

fn json_ok(body: json.Json, status: Int) -> Response {
  json.to_string(body) |> wisp.json_response(status)
}

pub fn list_issues(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      with_repo(ctx, org_slug, repo_name, fn(_repo) {
        case database.list_issues(ctx.repo(), org_slug, repo_name) {
          Ok(issues) -> {
            let issues = hydrate_issues(ctx, issues)
            json_ok(json_api.issues_json(issues), 200)
          }
          Error(_) -> wisp.internal_server_error()
        }
      })
  }
}

pub fn create_issue(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) -> {
      let decoder = {
        use title <- decode.field("title", decode.string)
        use description <- decode.field(
          "description",
          decode.optional(decode.string),
        )
        decode.success(#(title, description))
      }
      case decode.run(json_body, decoder) {
        Error(_) -> wisp.bad_request("Invalid JSON body")
        Ok(#(title, description)) ->
          case string.trim(title) {
            "" -> wisp.bad_request("Title is required")
            _ ->
              with_repo(ctx, org_slug, repo_name, fn(_repo) {
                case
                  database.insert_issue(
                    ctx.repo(),
                    org_slug,
                    repo_name,
                    title,
                    description,
                    user_id(ctx),
                  )
                {
                  Ok(issue) -> {
                    let issue = hydrate_issue(ctx, issue)
                    json_ok(json_api.issue_json(issue), 201)
                  }
                  Error(_) -> wisp.internal_server_error()
                }
              })
          }
      }
    }
  }
}

pub fn get_issue_detail(
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
      case parse_issue_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_issue(ctx, org_slug, repo_name, number, fn(issue) {
            let issue = hydrate_issue(ctx, issue)
            json.object([
              #("issue", json_api.issue_json(issue)),
            ])
            |> json_ok(200)
          })
      }
  }
}

pub fn close_issue_route(
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
      case parse_issue_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_issue(ctx, org_slug, repo_name, number, fn(issue) {
            let can_close =
              issue.state == "open"
              && {
                issue.author_user_id == user_id(ctx)
                || database.member_can_write(
                  ctx.repo(),
                  user_id(ctx),
                  org_slug,
                )
              }
            case can_close {
              False -> wisp.response(403)
              True ->
                case database.close_issue(ctx.repo(), org_slug, repo_name, number) {
                  Ok(updated) -> {
                    let updated = hydrate_issue(ctx, updated)
                    json_ok(json_api.issue_json(updated), 200)
                  }
                  Error(_) -> wisp.internal_server_error()
                }
            }
          })
      }
  }
}

pub fn list_comments(
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
      case parse_issue_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_issue(ctx, org_slug, repo_name, number, fn(_issue) {
            case
              database.list_issue_comments(
                ctx.repo(),
                org_slug,
                repo_name,
                number,
              )
            {
              Ok(comments) -> {
                let comments = hydrate_comments(ctx, comments)
                json_ok(json_api.issue_comments_json(comments), 200)
              }
              Error(_) -> wisp.internal_server_error()
            }
          })
      }
  }
}

pub fn create_comment(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_issue_number(number_str) {
        Error(r) -> r
        Ok(number) -> {
          let decoder = {
            use body <- decode.field("body", decode.string)
            decode.success(body)
          }
          case decode.run(json_body, decoder) {
            Error(_) -> wisp.bad_request("Invalid JSON body")
            Ok(body) ->
              case string.trim(body) {
                "" -> wisp.bad_request("Comment body is required")
                _ ->
                  with_issue(ctx, org_slug, repo_name, number, fn(_issue) {
                    case
                      database.insert_issue_comment(
                        ctx.repo(),
                        org_slug,
                        repo_name,
                        number,
                        user_id(ctx),
                        body,
                      )
                    {
                      Ok(comment) -> {
                        let comment = case hydrate_comments(ctx, [comment]) {
                          [hydrated] -> hydrated
                          _ -> comment
                        }
                        json_ok(json_api.issue_comment_json(comment), 201)
                      }
                      Error(_) -> wisp.internal_server_error()
                    }
                  })
              }
          }
        }
      }
  }
}
