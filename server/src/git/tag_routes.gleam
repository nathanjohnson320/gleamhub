import database.{type RepoRow, get_repo}
import git/browse_routes as repo_browse_routes
import git/exec as git_exec
import gleam/http
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import gleam/uri
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

fn git_dir(ctx: Context, repo: RepoRow) -> Result(String, git_exec.GitError) {
  git_exec.repo_path(org_access.git_repos_root(ctx), repo.disk_path)
}

fn with_repo(
  ctx: Context,
  org_slug: String,
  repo_name: String,
  run: fn(String, RepoRow) -> Response,
) -> Response {
  case org_access.require_member(ctx, user_id(ctx), org_slug) {
    Error(_) -> wisp.response(403)
    Ok(_) ->
      case get_repo(ctx.repo(), org_slug, repo_name) {
        Ok(option.None) -> wisp.not_found()
        Ok(option.Some(repo)) ->
          case git_dir(ctx, repo) {
            Error(_) -> wisp.internal_server_error()
            Ok(dir) -> run(dir, repo)
          }
        Error(_) -> wisp.internal_server_error()
      }
  }
}

fn join_tag_segments(segments: List(String)) -> String {
  segments
  |> list.map(decode_tag_segment)
  |> string.join(with: "/")
}

fn decode_tag_segment(segment: String) -> String {
  case uri.percent_decode(segment) {
    Ok(decoded) -> decoded
    Error(_) -> segment
  }
}

pub fn list_repo_tags(
  req: Request,
  ctx: Context,
  org_slug: String,
  name: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      with_repo(ctx, org_slug, name, fn(git_dir, _repo) {
        case git_exec.list_tags(git_dir) {
          Ok(tags) ->
            json_api.tags_json(tags)
            |> json.to_string
            |> wisp.json_response(200)
          Error(e) -> repo_browse_routes.git_error_response(e)
        }
      })
  }
}

pub fn get_repo_tag(
  req: Request,
  ctx: Context,
  org_slug: String,
  name: String,
  tag_segments: List(String),
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      with_repo(ctx, org_slug, name, fn(git_dir, _repo) {
        let tag = join_tag_segments(tag_segments)
        case git_exec.tag_exists(git_dir, tag) {
          Error(e) -> repo_browse_routes.git_error_response(e)
          Ok(tag_name) ->
            case git_exec.resolve_tag_commit(git_dir, tag_name) {
              Error(e) -> repo_browse_routes.git_error_response(e)
              Ok(sha) ->
                case git_exec.list_tags(git_dir) {
                  Error(e) -> repo_browse_routes.git_error_response(e)
                  Ok(tags) ->
                    case list.find(tags, fn(t) { t.name == tag_name }) {
                      Error(_) -> wisp.not_found()
                      Ok(tag_info) ->
                        case git_exec.show_commit(git_dir, sha) {
                          Ok(commit) ->
                            json_api.tag_detail_json(tag_info, commit)
                            |> json.to_string
                            |> wisp.json_response(200)
                          Error(e) -> repo_browse_routes.git_error_response(e)
                        }
                    }
                }
            }
        }
      })
  }
}
