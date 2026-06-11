import database
import git/browse_routes as repo_browse_routes
import git/exec as git_exec
import git/path as git_path
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import http/label_routes
import http/list_query
import http/milestone_routes
import http/org_access
import http/user_display
import http/web.{type Context}
import json/api as json_api
import mentions/notify as mention_notify
import mentions/resolve as mention_resolve
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
  user_display.hydrate_issue_comments(ctx, comments)
}

fn mention_usernames(
  ctx: Context,
  comment: database.IssueCommentRow,
) -> List(String) {
  user_display.mention_handles(ctx, comment.mentioned_user_ids)
}

fn comment_json(
  ctx: Context,
  comment: database.IssueCommentRow,
) -> json.Json {
  json_api.issue_comment_json(comment, mention_usernames(ctx, comment))
}

fn insert_issue_comment_with_mentions(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number: Int,
  body: String,
) -> Result(database.IssueCommentRow, Response) {
  let mentioned_user_ids = mention_resolve.for_org(ctx, org_slug, body)
  case
    database.insert_issue_comment(
      ctx.repo(),
      org_slug,
      repo_name,
      number,
      user_id(ctx),
      body,
      mentioned_user_ids,
    )
  {
    Error(_) -> Error(wisp.internal_server_error())
    Ok(comment) -> {
      let _ =
        mention_notify.comment_mentioned(
        ctx,
        user_id(ctx),
        mentioned_user_ids,
        [],
        mention_notify.IssueComment(
          org_slug:,
          repo_name:,
          issue_number: number,
          comment_id: comment.id,
        ),
      )
      Ok(comment)
    }
  }
}

fn update_issue_comment_with_mentions(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number: Int,
  comment_id: String,
  body: String,
) -> Result(database.IssueCommentRow, Response) {
  let previous_mentioned = case
    database.get_issue_comment(
      ctx.repo(),
      org_slug,
      repo_name,
      number,
      comment_id,
    )
  {
    Ok(option.Some(comment)) -> comment.mentioned_user_ids
    _ -> []
  }
  let mentioned_user_ids = mention_resolve.for_org(ctx, org_slug, body)
  case
    database.update_issue_comment(
      ctx.repo(),
      org_slug,
      repo_name,
      number,
      comment_id,
      body,
      mentioned_user_ids,
    )
  {
    Error(_) -> Error(wisp.internal_server_error())
    Ok(option.None) -> Error(wisp.not_found())
    Ok(option.Some(comment)) -> {
      let _ =
        mention_notify.comment_mentioned(
        ctx,
        user_id(ctx),
        mentioned_user_ids,
        previous_mentioned,
        mention_notify.IssueComment(
          org_slug:,
          repo_name:,
          issue_number: number,
          comment_id: comment.id,
        ),
      )
      Ok(comment)
    }
  }
}

fn hydrate_issues(
  ctx: Context,
  issues: List(database.IssueRow),
) -> List(database.IssueRow) {
  list.map(user_display.hydrate_issues(ctx, issues), fn(issue) {
    user_display.hydrate_issue_assignees(ctx, issue)
  })
}

fn hydrate_issue(ctx: Context, issue: database.IssueRow) -> database.IssueRow {
  user_display.hydrate_issue(ctx, issue)
}

fn git_dir(
  ctx: Context,
  repo: database.RepoRow,
) -> Result(String, git_exec.GitError) {
  git_exec.repo_path(org_access.git_repos_root(ctx), repo.disk_path)
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

fn with_git_repo(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  run: fn(String) -> Response,
) -> Response {
  case org_access.require_member(ctx, user_id(ctx), org_slug) {
    Error(_) -> wisp.response(403)
    Ok(_) ->
      case database.get_repo(ctx.repo(), org_slug, repo_name) {
        Ok(option.None) -> wisp.not_found()
        Ok(option.Some(repo)) ->
          case git_dir(ctx, repo) {
            Error(e) -> repo_browse_routes.git_error_response(e)
            Ok(dir) -> run(dir)
          }
        Error(_) -> wisp.internal_server_error()
      }
  }
}

fn query_param(req: Request, key: String) -> String {
  case list.find(wisp.get_query(req), fn(pair) { pair.0 == key }) {
    Ok(#(_, value)) -> value
    Error(_) -> ""
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

fn can_edit_issue(
  ctx: Context,
  org_slug: String,
  issue: database.IssueRow,
) -> Bool {
  issue.author_user_id == user_id(ctx)
  || database.member_can_write(ctx.repo(), user_id(ctx), org_slug)
}

fn can_edit_comment(ctx: Context, comment: database.IssueCommentRow) -> Bool {
  comment.author_user_id == user_id(ctx)
}

fn can_delete_comment(
  ctx: Context,
  org_slug: String,
  comment: database.IssueCommentRow,
) -> Bool {
  comment.author_user_id == user_id(ctx)
  || database.is_org_owner(ctx.repo(), user_id(ctx), org_slug)
}

fn respond_issue(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  issue: database.IssueRow,
  status: Int,
) -> Response {
  case database.enrich_issue(ctx.repo(), org_slug, repo_name, issue) {
    Ok(enriched) -> {
      let enriched = hydrate_issue(ctx, enriched)
      json_ok(json_api.issue_json(enriched), status)
    }
    Error(_) -> wisp.internal_server_error()
  }
}

fn respond_issues(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  issues: List(database.IssueRow),
) -> Response {
  case database.enrich_issues(ctx.repo(), org_slug, repo_name, issues) {
    Ok(enriched) ->
      json_ok(json_api.issues_json(hydrate_issues(ctx, enriched)), 200)
    Error(_) -> wisp.internal_server_error()
  }
}

fn decode_create_issue_metadata(
  body: dynamic.Dynamic,
) -> #(List(String), List(String)) {
  let metadata_decoder = {
    use label_ids <- decode.optional_field(
      "label_ids",
      [],
      decode.list(decode.string),
    )
    use assignee_user_ids <- decode.optional_field(
      "assignee_user_ids",
      [],
      decode.list(decode.string),
    )
    decode.success(#(label_ids, assignee_user_ids))
  }
  case decode.run(body, metadata_decoder) {
    Ok(#(labels, assignees)) -> #(labels, assignees)
    Error(_) -> #([], [])
  }
}

fn apply_issue_metadata(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  issue: database.IssueRow,
  label_ids: List(String),
  assignee_user_ids: List(String),
) -> Result(database.IssueRow, database.LabelError) {
  case label_ids {
    [] -> Ok(Nil)
    ids ->
      database.set_issue_labels(ctx.repo(), org_slug, repo_name, issue.id, ids)
  }
  |> result.try(fn(_) {
    case assignee_user_ids {
      [] -> Ok(Nil)
      ids -> database.set_issue_assignees(ctx.repo(), org_slug, issue.id, ids)
    }
  })
  |> result.map(fn(_) { issue })
}

fn decode_milestone_id_patch(
  body: dynamic.Dynamic,
) -> option.Option(option.Option(String)) {
  case decode.run(body, decode.at(["milestone_id"], decode.dynamic)) {
    Error(_) -> option.None
    Ok(value) ->
      case decode.run(value, decode.optional(decode.string)) {
        Ok(id) -> option.Some(id)
        Error(_) -> option.None
      }
  }
}

fn apply_optional_issue_milestone(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  issue: database.IssueRow,
  milestone_id: option.Option(option.Option(String)),
) -> Result(database.IssueRow, Response) {
  case milestone_id {
    option.None -> Ok(issue)
    option.Some(next_id) -> {
      let current_id = case issue.milestone {
        option.Some(milestone) -> option.Some(milestone.id)
        option.None -> option.None
      }
      case next_id == current_id {
        True -> Ok(issue)
        False ->
          case
            database.set_issue_milestone(
              ctx.repo(),
              org_slug,
              repo_name,
              issue.number,
              next_id,
            )
          {
            Ok(issue) -> Ok(issue)
            Error(e) -> Error(milestone_routes.milestone_error_response(e))
          }
      }
    }
  }
}

fn apply_optional_issue_metadata(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  issue: database.IssueRow,
  label_ids: option.Option(List(String)),
  assignee_user_ids: option.Option(List(String)),
) -> Result(database.IssueRow, Response) {
  let label_result = case label_ids {
    option.Some(ids) ->
      case database.issue_label_ids_on_issue(ctx.repo(), issue.id) {
        Error(e) -> Error(label_routes.label_error_response(e))
        Ok(current) ->
          case database.list_same_string_set(current, ids) {
            True -> Ok(Nil)
            False ->
              case
                database.set_issue_labels(
                  ctx.repo(),
                  org_slug,
                  repo_name,
                  issue.id,
                  ids,
                )
              {
                Error(e) -> Error(label_routes.label_error_response(e))
                Ok(Nil) -> Ok(Nil)
              }
          }
      }
    option.None -> Ok(Nil)
  }
  case label_result {
    Error(response) -> Error(response)
    Ok(Nil) ->
      case assignee_user_ids {
        option.Some(ids) ->
          case database.issue_assignee_ids_on_issue(ctx.repo(), issue.id) {
            Error(e) -> Error(label_routes.label_error_response(e))
            Ok(current) ->
              case database.list_same_string_set(current, ids) {
                True -> Ok(issue)
                False ->
                  case
                    database.set_issue_assignees(
                      ctx.repo(),
                      org_slug,
                      issue.id,
                      ids,
                    )
                  {
                    Error(e) -> Error(label_routes.label_error_response(e))
                    Ok(Nil) -> Ok(issue)
                  }
              }
          }
        option.None -> Ok(issue)
      }
  }
}

pub fn get_issue_template(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      with_git_repo(ctx, org_slug, repo_name, fn(git_dir) {
        let ref_param = query_param(req, "ref")
        let resolved = case ref_param {
          "" -> git_exec.default_branch(git_dir)
          ref ->
            case git_path.normalize_ref(ref) {
              Ok(validated) -> Ok(validated)
              Error(_) -> Error(git_exec.InvalidPath)
            }
        }
        case resolved {
          Error(e) -> repo_browse_routes.git_error_response(e)
          Ok(ref) ->
            case git_exec.find_issue_templates(git_dir, ref) {
              Ok(templates) ->
                json_ok(
                  json_api.merge_request_templates_json(ref, templates),
                  200,
                )
              Error(e) -> repo_browse_routes.git_error_response(e)
            }
        }
      })
  }
}

fn list_query_error_response(error: list_query.ParseError) -> Response {
  json.object([#("error", json.string(list_query.parse_error_message(error)))])
  |> json.to_string
  |> wisp.json_response(400)
}

fn resolve_issue_list_query(
  ctx: Context,
  req: Request,
  org_slug: String,
  repo_name: String,
) -> Result(list_query.IssueListQuery, Response) {
  use base <- result.try(
    list_query.parse_issue_list_query(req)
    |> result.map_error(list_query_error_response),
  )
  use label_ids <- result.try(
    resolve_list_label_ids(ctx, org_slug, repo_name, list_query.label_params(req)),
  )
  use milestone_id <- result.try(
    resolve_list_milestone_id(ctx, org_slug, repo_name, list_query.milestone_param(req)),
  )
  Ok(list_query.IssueListQuery(..base, label_ids:, milestone_id:))
}

fn resolve_list_milestone_id(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  param: option.Option(String),
) -> Result(option.Option(String), Response) {
  case param {
    option.None -> Ok(option.None)
    option.Some(value) ->
      case database.list_milestones(ctx.repo(), org_slug, repo_name) {
        Error(_) -> Error(wisp.internal_server_error())
        Ok(milestones) ->
          database.resolve_milestone_id(milestones, value)
          |> result.map(option.Some)
          |> result.map_error(fn(_) {
            list_query_error_response(list_query.UnknownMilestone(value))
          })
      }
  }
}

fn resolve_list_label_ids(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  params: List(String),
) -> Result(List(String), Response) {
  case params {
    [] -> Ok([])
    _ ->
      case database.list_repo_labels(ctx.repo(), org_slug, repo_name) {
        Error(_) -> Error(wisp.internal_server_error())
        Ok(labels) -> {
          let pairs =
            list.map(labels, fn(label) { #(label.id, label.name) })
          list_query.resolve_label_ids(pairs, params)
          |> result.map_error(list_query_error_response)
        }
      }
  }
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
        case resolve_issue_list_query(ctx, req, org_slug, repo_name) {
          Error(response) -> response
          Ok(query) ->
            case
              database.list_issues_filtered(
                ctx.repo(),
                org_slug,
                repo_name,
                query,
              )
            {
              Ok(issues) -> respond_issues(ctx, org_slug, repo_name, issues)
              Error(_) -> wisp.internal_server_error()
            }
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
                    let #(label_ids, assignee_user_ids) =
                      decode_create_issue_metadata(json_body)
                    case label_ids, assignee_user_ids {
                      [], [] ->
                        respond_issue(ctx, org_slug, repo_name, issue, 201)
                      _, _ ->
                        case
                          apply_issue_metadata(
                            ctx,
                            org_slug,
                            repo_name,
                            issue,
                            label_ids,
                            assignee_user_ids,
                          )
                        {
                          Ok(issue) ->
                            respond_issue(ctx, org_slug, repo_name, issue, 201)
                          Error(e) -> label_routes.label_error_response(e)
                        }
                    }
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
            case database.enrich_issue(ctx.repo(), org_slug, repo_name, issue) {
              Ok(enriched) -> {
                let enriched = hydrate_issue(ctx, enriched)
                let linked_mrs =
                  case
                    database.list_linked_merge_requests_for_issue(
                      ctx.repo(),
                      enriched.id,
                    )
                  {
                    Ok(rows) -> rows
                    Error(_) -> []
                  }
                json.object([
                  #("issue", json_api.issue_json(enriched)),
                  #(
                    "linked_merge_requests",
                    json.array(linked_mrs, json_api.linked_merge_request_json),
                  ),
                ])
                |> json_ok(200)
              }
              Error(_) -> wisp.internal_server_error()
            }
          })
      }
  }
}

pub fn update_issue(
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
      case parse_issue_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_issue(ctx, org_slug, repo_name, number, fn(issue) {
            case can_edit_issue(ctx, org_slug, issue) {
              False -> wisp.response(403)
              True -> {
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
                  use label_ids <- decode.optional_field(
                    "label_ids",
                    option.None,
                    decode.optional(decode.list(decode.string)),
                  )
                  use assignee_user_ids <- decode.optional_field(
                    "assignee_user_ids",
                    option.None,
                    decode.optional(decode.list(decode.string)),
                  )
                  decode.success(#(
                    title,
                    description,
                    label_ids,
                    assignee_user_ids,
                  ))
                }
                case decode.run(json_body, decoder) {
                  Error(_) -> wisp.bad_request("Invalid JSON body")
                  Ok(#(title, description, label_ids, assignee_user_ids)) -> {
                    let milestone_id = decode_milestone_id_patch(json_body)
                    let next_title = case title {
                      option.Some(t) -> string.trim(t)
                      option.None -> issue.title
                    }
                    case next_title {
                      "" -> wisp.bad_request("Title is required")
                      _ -> {
                        let next_description = case description {
                          option.Some(d) -> option.Some(d)
                          option.None -> issue.description
                        }
                        let issue_result = case
                          next_title == issue.title
                          && next_description == issue.description
                        {
                          True -> Ok(issue)
                          False ->
                            database.update_issue(
                              ctx.repo(),
                              org_slug,
                              repo_name,
                              number,
                              next_title,
                              next_description,
                            )
                        }
                        case issue_result {
                          Error(_) -> wisp.internal_server_error()
                          Ok(issue_row) ->
                            case
                              apply_optional_issue_metadata(
                                ctx,
                                org_slug,
                                repo_name,
                                issue_row,
                                label_ids,
                                assignee_user_ids,
                              )
                            {
                              Error(response) -> response
                              Ok(issue_row) ->
                                case
                                  apply_optional_issue_milestone(
                                    ctx,
                                    org_slug,
                                    repo_name,
                                    issue_row,
                                    milestone_id,
                                  )
                                {
                                  Error(response) -> response
                                  Ok(issue) ->
                                    respond_issue(
                                      ctx,
                                      org_slug,
                                      repo_name,
                                      issue,
                                      200,
                                    )
                                }
                            }
                        }
                      }
                    }
                  }
                }
              }
            }
          })
      }
  }
}

pub fn reopen_issue_route(
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
            case can_edit_issue(ctx, org_slug, issue) {
              False -> wisp.response(403)
              True ->
                case issue.state {
                  "closed" ->
                    case
                      database.reopen_issue(
                        ctx.repo(),
                        org_slug,
                        repo_name,
                        number,
                      )
                    {
                      Ok(updated) ->
                        respond_issue(ctx, org_slug, repo_name, updated, 200)
                      Error(_) -> wisp.internal_server_error()
                    }
                  _ -> wisp.unprocessable_content()
                }
            }
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
              issue.state == "open" && can_edit_issue(ctx, org_slug, issue)
            case can_close {
              False -> wisp.response(403)
              True ->
                case
                  database.close_issue(ctx.repo(), org_slug, repo_name, number)
                {
                  Ok(updated) ->
                    respond_issue(ctx, org_slug, repo_name, updated, 200)
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
                json_ok(
                  json_api.issue_comments_json(comments, fn(comment) {
                    mention_usernames(ctx, comment)
                  }),
                  200,
                )
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
                      insert_issue_comment_with_mentions(
                        ctx,
                        org_slug,
                        repo_name,
                        number,
                        body,
                      )
                    {
                      Ok(comment) -> {
                        let comment = case hydrate_comments(ctx, [comment]) {
                          [hydrated] -> hydrated
                          _ -> comment
                        }
                        json_ok(comment_json(ctx, comment), 201)
                      }
                      Error(response) -> response
                    }
                  })
              }
          }
        }
      }
  }
}

pub fn update_comment(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
  comment_id: String,
) -> Response {
  use <- wisp.require_method(req, http.Patch)
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
                trimmed ->
                  with_issue(ctx, org_slug, repo_name, number, fn(_issue) {
                    case
                      database.get_issue_comment(
                        ctx.repo(),
                        org_slug,
                        repo_name,
                        number,
                        comment_id,
                      )
                    {
                      Error(_) -> wisp.internal_server_error()
                      Ok(option.None) -> wisp.not_found()
                      Ok(option.Some(comment)) ->
                        case can_edit_comment(ctx, comment) {
                          False -> wisp.response(403)
                          True ->
                            case
                              update_issue_comment_with_mentions(
                                ctx,
                                org_slug,
                                repo_name,
                                number,
                                comment_id,
                                trimmed,
                              )
                            {
                              Ok(updated) -> {
                                let updated = case
                                  hydrate_comments(ctx, [updated])
                                {
                                  [hydrated] -> hydrated
                                  _ -> updated
                                }
                                json_ok(comment_json(ctx, updated), 200)
                              }
                              Error(response) -> response
                            }
                        }
                    }
                  })
              }
          }
        }
      }
  }
}

pub fn delete_comment(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number_str: String,
  comment_id: String,
) -> Response {
  use <- wisp.require_method(req, http.Delete)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case parse_issue_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_issue(ctx, org_slug, repo_name, number, fn(_issue) {
            case
              database.get_issue_comment(
                ctx.repo(),
                org_slug,
                repo_name,
                number,
                comment_id,
              )
            {
              Error(_) -> wisp.internal_server_error()
              Ok(option.None) -> wisp.not_found()
              Ok(option.Some(comment)) ->
                case can_delete_comment(ctx, org_slug, comment) {
                  False -> wisp.response(403)
                  True ->
                    case
                      database.delete_issue_comment(
                        ctx.repo(),
                        org_slug,
                        repo_name,
                        number,
                        comment_id,
                      )
                    {
                      Ok(True) -> wisp.response(204)
                      Ok(False) -> wisp.not_found()
                      Error(_) -> wisp.internal_server_error()
                    }
                }
            }
          })
      }
  }
}
