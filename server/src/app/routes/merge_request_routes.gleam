import app/database as database
import app/git_exec
import app/json_api
import app/org_access
import app/routes/repo_browse_routes
import app/web.{type Context}
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import wisp.{type Request, type Response}

fn user_id(ctx: Context) -> String {
  let assert option.Some(id) = ctx.user_id
  id
}

fn ensure_user(ctx: Context) -> Result(Nil, Response) {
  case ctx.user_id {
    option.Some(id) -> {
      let _ = database.upsert_user(ctx.repo(), id, option.None, ctx.email)
      Ok(Nil)
    }
    option.None -> Error(wisp.response(401))
  }
}

fn git_dir(ctx: Context, repo: database.RepoRow) -> String {
  git_exec.repo_path(org_access.git_repos_root(ctx), repo.disk_path)
}

fn with_repo(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  run: fn(database.RepoRow, String) -> Response,
) -> Response {
  case org_access.require_member(ctx, user_id(ctx), org_slug) {
    Error(_) -> wisp.response(403)
    Ok(_) ->
      case database.get_repo(ctx.repo(), org_slug, repo_name) {
        Ok(option.None) -> wisp.not_found()
        Ok(option.Some(repo)) -> run(repo, git_dir(ctx, repo))
        Error(_) -> wisp.internal_server_error()
      }
  }
}

fn with_mr(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number: Int,
  run: fn(database.MergeRequestRow, String) -> Response,
) -> Response {
  with_repo(ctx, org_slug, repo_name, fn(_repo, dir) {
    case database.get_merge_request(ctx.repo(), org_slug, repo_name, number) {
      Ok(option.None) -> wisp.not_found()
      Ok(option.Some(mr)) -> run(mr, dir)
      Error(_) -> wisp.internal_server_error()
    }
  })
}

fn parse_mr_number(num_str: String) -> Result(Int, Response) {
  case int.parse(num_str) {
    Ok(n) -> Ok(n)
    Error(_) -> Error(wisp.bad_request("Invalid merge request number"))
  }
}

fn json_ok(body: json.Json, status: Int) -> Response {
  json.to_string(body) |> wisp.json_response(status)
}

fn duplicate_mr_response(existing_number: Int) -> Response {
  json.object([
    #(
      "error",
      json.string("An open merge request already exists for these branches"),
    ),
    #("existing_number", json.int(existing_number)),
  ])
  |> json.to_string
  |> fn(body) { wisp.response(409) |> wisp.json_body(body) }
}

pub fn list_merge_requests(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      with_repo(ctx, org_slug, repo_name, fn(_repo, _dir) {
        case database.list_merge_requests(ctx.repo(), org_slug, repo_name) {
          Ok(mrs) -> json_ok(json_api.merge_requests_json(mrs), 200)
          Error(_) -> wisp.internal_server_error()
        }
      })
  }
}

pub fn create_merge_request(
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
        use source_branch <- decode.field("source_branch", decode.string)
        use target_branch <- decode.field("target_branch", decode.string)
        decode.success(#(title, description, source_branch, target_branch))
      }
      case decode.run(json_body, decoder) {
        Error(_) -> wisp.bad_request("Invalid JSON body")
        Ok(#(title, description, source, target)) ->
          case string.trim(title) {
            "" -> wisp.bad_request("Title is required")
            _ ->
              case source == target {
                True -> wisp.bad_request("Source and target branches must differ")
                False ->
                  with_repo(ctx, org_slug, repo_name, fn(_repo, git_dir) {
                    case
                      git_exec.branch_exists(git_dir, source),
                      git_exec.branch_exists(git_dir, target)
                    {
                      Ok(Nil), Ok(Nil) -> {
                        case
                          database.find_open_merge_request(
                            ctx.repo(),
                            org_slug,
                            repo_name,
                            source,
                            target,
                          )
                        {
                          Ok(option.Some(existing)) ->
                            duplicate_mr_response(existing)
                          Ok(option.None) ->
                            case
                              database.insert_merge_request(
                                ctx.repo(),
                                org_slug,
                                repo_name,
                                title,
                                description,
                                user_id(ctx),
                                source,
                                target,
                              )
                            {
                              Ok(mr) ->
                                json_ok(json_api.merge_request_json(mr), 201)
                              Error(_) -> wisp.internal_server_error()
                            }
                          Error(_) -> wisp.internal_server_error()
                        }
                      }
                      Error(git_exec.InvalidBranch), _ ->
                        wisp.bad_request("Invalid branch name")
                      _, Error(git_exec.InvalidBranch) ->
                        wisp.bad_request("Invalid branch name")
                      Error(git_exec.NotFound), _ ->
                        wisp.bad_request("Source branch not found")
                      _, Error(git_exec.NotFound) ->
                        wisp.bad_request("Target branch not found")
                      Error(e), _ | _, Error(e) ->
                        repo_browse_routes.git_error_response(e)
                    }
                  })
              }
          }
      }
    }
  }
}

pub fn get_merge_request_detail(
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
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_mr(ctx, org_slug, repo_name, number, fn(mr, git_dir) {
            case git_exec.can_merge(git_dir, mr.target_branch, mr.source_branch) {
              Ok(check) ->
                json.object([
                  #("merge_request", json_api.merge_request_json(mr)),
                  #("merge_check", json_api.merge_check_json(check)),
                ])
                |> json_ok(200)
              Error(e) -> repo_browse_routes.git_error_response(e)
            }
          })
      }
  }
}

pub fn list_commits(
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
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_mr(ctx, org_slug, repo_name, number, fn(mr, git_dir) {
            case
              git_exec.commits_between(
                git_dir,
                mr.target_branch,
                mr.source_branch,
              )
            {
              Ok(commits) -> json_ok(json_api.commits_json(commits), 200)
              Error(e) -> repo_browse_routes.git_error_response(e)
            }
          })
      }
  }
}

pub fn get_diff(
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
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_mr(ctx, org_slug, repo_name, number, fn(mr, git_dir) {
            let path = query_param(req, "path")
            case path {
              "" ->
                case
                  git_exec.diff_summary(
                    git_dir,
                    mr.target_branch,
                    mr.source_branch,
                  )
                {
                  Ok(files) -> json_ok(json_api.diff_files_json(files), 200)
                  Error(e) -> repo_browse_routes.git_error_response(e)
                }
              file_path ->
                case
                  git_exec.diff_patch(
                    git_dir,
                    mr.target_branch,
                    mr.source_branch,
                    file_path,
                  )
                {
                  Ok(patch) ->
                    json_ok(json_api.diff_patch_json(file_path, patch), 200)
                  Error(e) -> repo_browse_routes.git_error_response(e)
                }
            }
          })
      }
  }
}

fn merge_commit_message(mr: database.MergeRequestRow) -> String {
  case mr.description {
    option.Some(d) -> mr.title <> "\n\n" <> d
    option.None -> mr.title
  }
}

fn parse_merge_method(json_body) -> Result(git_exec.MergeMethod, Response) {
  let decoder = {
    use merge_method <- decode.field(
      "merge_method",
      decode.optional(decode.string),
    )
    decode.success(merge_method)
  }
  case decode.run(json_body, decoder) {
    Error(_) -> Ok(git_exec.MergeCommit)
    Ok(option.None) | Ok(option.Some("merge")) -> Ok(git_exec.MergeCommit)
    Ok(option.Some("squash")) -> Ok(git_exec.Squash)
    Ok(option.Some(_)) -> Error(wisp.bad_request("Invalid merge_method"))
  }
}

pub fn merge_merge_request(
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
      case database.member_can_write(ctx.repo(), user_id(ctx), org_slug) {
        False -> wisp.response(403)
        True ->
          case parse_merge_method(json_body) {
            Error(r) -> r
            Ok(method) ->
              case parse_mr_number(number_str) {
                Error(r) -> r
                Ok(number) ->
                  with_mr(ctx, org_slug, repo_name, number, fn(mr, git_dir) {
                    case mr.state {
                      "open" ->
                        case
                          git_exec.merge_branches(
                            git_dir,
                            mr.target_branch,
                            mr.source_branch,
                            method,
                            merge_commit_message(mr),
                          )
                        {
                          Ok(sha) ->
                            case
                              database.merge_merge_request(
                                ctx.repo(),
                                org_slug,
                                repo_name,
                                number,
                                sha,
                                user_id(ctx),
                              )
                            {
                              Ok(updated) ->
                                json_ok(json_api.merge_request_json(updated), 200)
                              Error(_) -> wisp.internal_server_error()
                            }
                          Error(e) -> repo_browse_routes.git_error_response(e)
                        }
                      _ -> wisp.unprocessable_content()
                    }
                  })
              }
          }
      }
  }
}

pub fn close_merge_request_route(
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
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_mr(ctx, org_slug, repo_name, number, fn(mr, _git_dir) {
            let can_close =
              mr.state == "open"
              && {
                mr.author_user_id == user_id(ctx)
                || database.member_can_write(
                  ctx.repo(),
                  user_id(ctx),
                  org_slug,
                )
              }
            case can_close {
              False -> wisp.response(403)
              True ->
                case database.close_merge_request(ctx.repo(), org_slug, repo_name, number) {
                  Ok(updated) ->
                    json_ok(json_api.merge_request_json(updated), 200)
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
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) ->
          with_mr(ctx, org_slug, repo_name, number, fn(_mr, _dir) {
            case
              database.list_merge_request_comments(
                ctx.repo(),
                org_slug,
                repo_name,
                number,
              )
            {
              Ok(comments) ->
                json_ok(json_api.merge_request_comments_json(comments), 200)
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
      case parse_mr_number(number_str) {
        Error(r) -> r
        Ok(number) -> {
          let decoder = {
            use body <- decode.field("body", decode.string)
            use file_path <- decode.field(
              "file_path",
              decode.optional(decode.string),
            )
            use line <- decode.field("line", decode.optional(decode.int))
            decode.success(#(body, file_path, line))
          }
          case decode.run(json_body, decoder) {
            Error(_) -> wisp.bad_request("Invalid JSON body")
            Ok(#(body, file_path, line)) ->
              case string.trim(body) {
                "" -> wisp.bad_request("Comment body is required")
                _ ->
                  with_mr(ctx, org_slug, repo_name, number, fn(_mr, _dir) {
                    case
                      database.insert_merge_request_comment(
                        ctx.repo(),
                        org_slug,
                        repo_name,
                        number,
                        user_id(ctx),
                        body,
                        file_path,
                        line,
                      )
                    {
                      Ok(comment) ->
                        json_ok(
                          json_api.merge_request_comment_json(comment),
                          201,
                        )
                      Error(_) -> wisp.internal_server_error()
                    }
                  })
              }
          }
        }
      }
  }
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
