import database
import git/exec as git_exec
import git/path as git_path
import git/url as git_url
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import gleam/option
import gleam/result
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
        Ok(option.Some(repo)) ->
          case
            git_exec.repo_path(org_access.git_repos_root(ctx), repo.disk_path)
          {
            Error(_) -> wisp.internal_server_error()
            Ok(git_dir) -> run(repo, git_dir)
          }
        Error(_) -> wisp.internal_server_error()
      }
  }
}

fn json_ok(body: json.Json, status: Int) -> Response {
  json.to_string(body) |> wisp.json_response(status)
}

fn normalize_branch_names(
  names: List(String),
) -> Result(List(String), Response) {
  list.fold(names, Ok([]), fn(acc, name) {
    case acc {
      Error(r) -> Error(r)
      Ok(normalized) -> {
        let trimmed = string.trim(name)
        case trimmed {
          "" -> Error(wisp.bad_request("Branch name cannot be empty"))
          _ ->
            case git_path.normalize_branch(trimmed) {
              Ok(branch) ->
                case list.contains(normalized, branch) {
                  True ->
                    Error(wisp.bad_request("Duplicate branch: " <> branch))
                  False -> Ok([branch, ..normalized])
                }
              Error(_) ->
                Error(wisp.bad_request("Invalid branch name: " <> trimmed))
            }
        }
      }
    }
  })
  |> result.map(list.reverse)
}

pub fn list_protected_branches(
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
        case database.list_protected_branches(ctx.repo(), org_slug, repo_name) {
          Ok(branches) ->
            json_ok(json_api.protected_branches_json(branches), 200)
          Error(_) -> wisp.internal_server_error()
        }
      })
  }
}

pub fn replace_protected_branches(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Put)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case org_access.require_owner(ctx, user_id(ctx), org_slug) {
        Error(_) -> wisp.response(403)
        Ok(_) -> {
          let decoder = {
            use branches <- decode.field("branches", decode.list(decode.string))
            decode.success(branches)
          }
          case decode.run(json_body, decoder) {
            Error(_) -> wisp.bad_request("Invalid JSON body")
            Ok(branches) ->
              case normalize_branch_names(branches) {
                Error(r) -> r
                Ok(normalized) ->
                  with_repo(ctx, org_slug, repo_name, fn(repo, _git_dir) {
                    case
                      git_exec.install_repo_hooks(
                        org_access.git_repos_root(ctx),
                        repo.disk_path,
                      )
                    {
                      Error(_) -> wisp.internal_server_error()
                      Ok(_) ->
                        case
                          database.replace_protected_branches(
                            ctx.repo(),
                            org_slug,
                            repo_name,
                            normalized,
                          )
                        {
                          Ok(updated) ->
                            json_ok(
                              json_api.protected_branches_json(updated),
                              200,
                            )
                          Error(_) -> wisp.internal_server_error()
                        }
                    }
                  })
              }
          }
        }
      }
  }
}

fn default_branch_error_response(error: git_exec.GitError) -> Response {
  case error {
    git_exec.NotFound -> wisp.bad_request("Branch not found")
    git_exec.InvalidBranch -> wisp.bad_request("Invalid branch name")
    _ -> wisp.internal_server_error()
  }
}

pub fn set_default_branch(
  req: Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
) -> Response {
  use <- wisp.require_method(req, http.Put)
  use json_body <- wisp.require_json(req)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      case org_access.require_owner(ctx, user_id(ctx), org_slug) {
        Error(_) -> wisp.response(403)
        Ok(_) -> {
          let decoder = {
            use branch <- decode.field("branch", decode.string)
            decode.success(branch)
          }
          case decode.run(json_body, decoder) {
            Error(_) -> wisp.bad_request("Invalid JSON body")
            Ok(branch) -> {
              let trimmed = string.trim(branch)
              case trimmed {
                "" -> wisp.bad_request("Branch name cannot be empty")
                _ ->
                  case git_path.normalize_branch(trimmed) {
                    Error(_) -> wisp.bad_request("Invalid branch name")
                    Ok(normalized) ->
                      with_repo(ctx, org_slug, repo_name, fn(repo, git_dir) {
                        case git_exec.set_default_branch(git_dir, normalized) {
                          Error(e) -> default_branch_error_response(e)
                          Ok(default_branch) -> {
                            let url =
                              git_url.clone_url(ctx, org_slug, repo.name)
                            let required_approvals =
                              case
                                database.get_required_approvals(
                                  ctx.repo(),
                                  org_slug,
                                  repo.name,
                                )
                              {
                                Ok(count) -> count
                                Error(_) -> 0
                              }
                            json_ok(
                              json_api.repo_detail_json(
                                repo,
                                url,
                                option.Some(default_branch),
                                option.None,
                                required_approvals,
                              ),
                              200,
                            )
                          }
                        }
                      })
                  }
              }
            }
          }
        }
      }
  }
}
