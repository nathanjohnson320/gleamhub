import app/database.{type RepoRow, get_repo}
import app/git_exec
import app/git_path
import app/json_api
import app/org_access
import app/web.{type Context}
import gleam/http
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
    option.Some(_) -> Ok(Nil)
    option.None -> Error(wisp.response(401))
  }
}

fn clone_url(ctx: Context, org_slug: String, repo_name: String) -> String {
  "ssh://git@"
  <> org_access.git_host(ctx)
  <> ":2222/"
  <> org_slug
  <> "/"
  <> repo_name
  <> ".git"
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

fn join_path_segments(segments: List(String)) -> String {
  string.join(segments, with: "/")
}

fn git_dir(ctx: Context, repo: RepoRow) -> String {
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
        Ok(option.Some(repo)) -> run(git_dir(ctx, repo), repo)
        Error(_) -> wisp.internal_server_error()
      }
  }
}

fn resolve_ref(git_dir: String, ref_param: String) -> Result(String, git_exec.GitError) {
  case ref_param {
    "" -> git_exec.default_branch(git_dir)
    ref -> Ok(ref)
  }
}

pub fn git_error_response(error: git_exec.GitError) -> Response {
  case error {
    git_exec.NotFound -> wisp.not_found()
    git_exec.InvalidPath -> wisp.bad_request("Invalid path")
    git_exec.InvalidBranch -> wisp.bad_request("Invalid branch")
    git_exec.NotATree -> wisp.bad_request("Not a directory")
    git_exec.BlobTooLarge -> wisp.content_too_large()
    git_exec.NoBranches -> wisp.not_found()
    git_exec.MergeConflict(msg) -> wisp.response(409) |> wisp.json_body(error_json(msg))
    git_exec.GitCommandFailed(_) -> wisp.internal_server_error()
  }
}

fn error_json(message: String) -> String {
  json.object([#("error", json.string(message))])
  |> json.to_string
}

pub fn get_repo_detail(
  req: Request,
  ctx: Context,
  org_slug: String,
  name: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      with_repo(ctx, org_slug, name, fn(git_dir, repo) {
        let url = clone_url(ctx, org_slug, name)
        let default_branch = case git_exec.default_branch(git_dir) {
          Ok(ref) -> option.Some(ref)
          Error(_) -> option.None
        }
        json_api.repo_detail_json(repo, url, default_branch)
        |> json.to_string
        |> wisp.json_response(200)
      })
  }
}

pub fn list_repo_branches(
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
        case git_exec.list_branches(git_dir) {
          Ok(branches) ->
            json_api.branches_json(branches)
            |> json.to_string
            |> wisp.json_response(200)
          Error(e) -> git_error_response(e)
        }
      })
  }
}

pub fn get_repo_commit(
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
        case git_path.normalize_sha(query_param(req, "sha")) {
          Error(_) -> wisp.bad_request("Invalid commit SHA")
          Ok(sha) ->
            case git_exec.show_commit(git_dir, sha) {
              Ok(commit) ->
                json_api.single_commit_json(commit)
                |> json.to_string
                |> wisp.json_response(200)
              Error(e) -> git_error_response(e)
            }
        }
      })
  }
}

pub fn list_repo_commits(
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
        case resolve_ref(git_dir, query_param(req, "ref")) {
          Error(e) -> git_error_response(e)
          Ok(ref) ->
            case git_exec.commit_count(git_dir, ref), git_exec.commits_on_ref(git_dir, ref) {
              Ok(total), Ok(commits) ->
                json_api.repo_commits_json(total, commits)
                |> json.to_string
                |> wisp.json_response(200)
              Error(e), _ | _, Error(e) -> git_error_response(e)
            }
        }
      })
  }
}

pub fn get_repo_readme(
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
        case resolve_ref(git_dir, query_param(req, "ref")) {
          Error(e) -> git_error_response(e)
          Ok(ref) ->
            case git_exec.find_readme(git_dir, ref) {
              Ok(option.None) -> wisp.not_found()
              Ok(option.Some(readme)) ->
                json_api.readme_json(ref, readme.path, readme.content)
                |> json.to_string
                |> wisp.json_response(200)
              Error(e) -> git_error_response(e)
            }
        }
      })
  }
}

pub fn get_repo_tree_root(
  req: Request,
  ctx: Context,
  org_slug: String,
  name: String,
) -> Response {
  get_repo_tree(req, ctx, org_slug, name, query_param(req, "ref"), [])
}

pub fn get_repo_tree(
  req: Request,
  ctx: Context,
  org_slug: String,
  name: String,
  ref: String,
  path_segments: List(String),
) -> Response {
  use <- wisp.require_method(req, http.Get)
  let path = join_path_segments(path_segments)
  case ensure_user(ctx) {
    Error(r) -> r
    Ok(_) ->
      with_repo(ctx, org_slug, name, fn(git_dir, _repo) {
        case resolve_ref(git_dir, ref) {
          Error(e) -> git_error_response(e)
          Ok(resolved_ref) ->
            case git_exec.list_tree(git_dir, resolved_ref, path) {
              Ok(entries) ->
                json_api.tree_json(resolved_ref, path, entries)
                |> json.to_string
                |> wisp.json_response(200)
              Error(e) -> git_error_response(e)
            }
        }
      })
  }
}

pub fn get_repo_blob(
  req: Request,
  ctx: Context,
  org_slug: String,
  name: String,
  ref: String,
  path_segments: List(String),
) -> Response {
  use <- wisp.require_method(req, http.Get)
  let path = join_path_segments(path_segments)
  case path == "" {
    True -> wisp.bad_request("Path required")
    False ->
      case ensure_user(ctx) {
        Error(r) -> r
        Ok(_) ->
          with_repo(ctx, org_slug, name, fn(git_dir, _repo) {
            case resolve_ref(git_dir, ref) {
              Error(e) -> git_error_response(e)
              Ok(resolved_ref) ->
                case git_exec.read_blob(git_dir, resolved_ref, path) {
                  Ok(blob) ->
                    json_api.blob_json(resolved_ref, path, blob)
                    |> json.to_string
                    |> wisp.json_response(200)
                  Error(e) -> git_error_response(e)
                }
            }
          })
      }
  }
}
