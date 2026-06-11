import database.{
  type RepoRow, get_latest_branch_pipeline_run_optional, get_repo,
  get_required_approvals, reclaim_stale_pipeline_runs,
}
import git/exec as git_exec
import git/mime
import git/path as git_path
import git/url as git_url
import gleam/http
import gleam/json
import gleam/list
import gleam/option
import gleam/result
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

fn query_param(req: Request, name: String) -> String {
  case
    list.find(wisp.get_query(req), fn(pair) {
      let #(key, _) = pair
      key == name
    })
  {
    Ok(#(_, value)) -> value
    Error(_) -> ""
  }
}

fn join_path_segments(segments: List(String)) -> String {
  string.join(segments, with: "/")
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

fn resolve_ref(
  git_dir: String,
  ref_param: String,
) -> Result(String, git_exec.GitError) {
  case ref_param {
    "" -> git_exec.default_branch(git_dir)
    ref ->
      case git_path.normalize_ref(ref) {
        Error(_) -> Error(git_exec.InvalidPath)
        Ok(validated) -> Ok(validated)
      }
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
    git_exec.MergeConflict(msg) ->
      wisp.response(409) |> wisp.json_body(error_json(msg))
    git_exec.AlreadyUpToDate ->
      wisp.unprocessable_content()
      |> wisp.json_body(error_json("Branch is already up to date"))
    git_exec.GitCommandFailed(msg) ->
      wisp.response(500) |> wisp.json_body(error_json(msg))
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
        reclaim_stale_pipeline_runs(ctx.repo())
        let url = git_url.clone_url(ctx, org_slug, name)
        let default_branch = case git_exec.default_branch(git_dir) {
          Ok(ref) -> option.Some(ref)
          Error(_) -> option.None
        }
        let default_branch_pipeline = case default_branch {
          option.Some(branch) ->
            case
              get_latest_branch_pipeline_run_optional(
                ctx.repo(),
                repo.id,
                branch,
              )
            {
              Ok(run) -> run
              Error(_) -> option.None
            }
          option.None -> option.None
        }
        let required_approvals =
          case get_required_approvals(ctx.repo(), org_slug, name) {
            Ok(count) -> count
            Error(_) -> 0
          }
        json_api.repo_detail_json(
          repo,
          url,
          default_branch,
          default_branch_pipeline,
          required_approvals,
        )
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
            case
              git_exec.commit_count(git_dir, ref),
              git_exec.commits_on_ref(git_dir, ref)
            {
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

fn parse_ref_and_repo_path(
  req: Request,
  path_segments: List(String),
) -> Result(#(String, List(String)), Response) {
  let query_ref = query_param(req, "ref")
  case query_ref {
    "" -> Ok(#("", path_segments))
    ref -> Ok(#(ref, path_segments))
  }
}

fn resolve_tree_ref_and_path(
  git_dir: String,
  query_ref: String,
  path_segments: List(String),
) -> Result(#(String, String), git_exec.GitError) {
  case query_ref {
    "" -> resolve_legacy_ref_and_path(git_dir, path_segments, 0)
    ref -> {
      let path = join_path_segments(path_segments)
      use resolved <- result.try(resolve_ref(git_dir, ref))
      Ok(#(resolved, path))
    }
  }
}

fn resolve_legacy_ref_and_path(
  git_dir: String,
  segments: List(String),
  min_path_parts: Int,
) -> Result(#(String, String), git_exec.GitError) {
  case segments {
    [] -> Error(git_exec.InvalidPath)
    _ -> {
      let max_ref_parts = list.length(segments) - min_path_parts
      try_ref_path_split(git_dir, segments, 1, max_ref_parts)
    }
  }
}

fn parse_ref_and_file_path(
  req: Request,
  path_segments: List(String),
) -> Result(#(String, String), Response) {
  let query_ref = query_param(req, "ref")
  case query_ref {
    "" -> Ok(#("", join_path_segments(path_segments)))
    ref ->
      case join_path_segments(path_segments) {
        "" -> Error(wisp.bad_request("Path required"))
        path -> Ok(#(ref, path))
      }
  }
}

fn resolve_blob_ref_and_path(
  git_dir: String,
  query_ref: String,
  path_segments: List(String),
) -> Result(#(String, String), git_exec.GitError) {
  case query_ref {
    "" -> resolve_legacy_ref_and_path(git_dir, path_segments, 1)
    ref -> {
      case join_path_segments(path_segments) {
        "" -> Error(git_exec.InvalidPath)
        path -> {
          use resolved <- result.try(resolve_ref(git_dir, ref))
          Ok(#(resolved, path))
        }
      }
    }
  }
}

fn try_ref_path_split(
  git_dir: String,
  segments: List(String),
  ref_parts: Int,
  max_ref_parts: Int,
) -> Result(#(String, String), git_exec.GitError) {
  case ref_parts > max_ref_parts {
    True -> Error(git_exec.NotFound)
    False -> {
      let ref =
        segments
        |> list.take(ref_parts)
        |> list.map(decode_ref_segment)
        |> string.join(with: "/")
      let path =
        segments
        |> list.drop(ref_parts)
        |> string.join(with: "/")
      case git_exec.branch_exists(git_dir, ref) {
        Ok(validated) -> {
          use resolved <- result.try(resolve_ref(git_dir, validated))
          Ok(#(resolved, path))
        }
        Error(_) ->
          try_ref_path_split(git_dir, segments, ref_parts + 1, max_ref_parts)
      }
    }
  }
}

fn decode_ref_segment(segment: String) -> String {
  case uri.percent_decode(segment) {
    Ok(decoded) -> decoded
    Error(_) -> segment
  }
}

pub fn get_repo_tree_root(
  req: Request,
  ctx: Context,
  org_slug: String,
  name: String,
) -> Response {
  get_repo_tree_at(req, ctx, org_slug, name, query_param(req, "ref"), "")
}

pub fn get_repo_tree(
  req: Request,
  ctx: Context,
  org_slug: String,
  name: String,
  path_segments: List(String),
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case parse_ref_and_repo_path(req, path_segments) {
    Error(r) -> r
    Ok(#(query_ref, segments)) ->
      case ensure_user(ctx) {
        Error(r) -> r
        Ok(_) ->
          with_repo(ctx, org_slug, name, fn(git_dir, _repo) {
            case resolve_tree_ref_and_path(git_dir, query_ref, segments) {
              Error(e) -> git_error_response(e)
              Ok(#(resolved_ref, path)) ->
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
}

fn get_repo_tree_at(
  req: Request,
  ctx: Context,
  org_slug: String,
  name: String,
  ref: String,
  path: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
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

fn download_requested(req: Request) -> Bool {
  case query_param(req, "download") {
    "1" | "true" | "yes" -> True
    _ -> False
  }
}

fn content_disposition(filename: String, download: Bool) -> String {
  let kind = case download {
    True -> "attachment"
    False -> "inline"
  }
  kind <> "; filename=\"" <> escape_disposition_filename(filename) <> "\""
}

fn escape_disposition_filename(filename: String) -> String {
  filename
  |> string.replace(each: "\"", with: "")
  |> string.replace(each: "\n", with: "")
}

fn archive_filename(
  repo_name: String,
  ref: String,
  format: git_exec.ArchiveFormat,
) -> String {
  let safe_ref =
    ref
    |> string.replace(each: "/", with: "-")
    |> string.replace(each: "\\", with: "-")
  case format {
    git_exec.ArchiveZip -> repo_name <> "-" <> safe_ref <> ".zip"
    git_exec.ArchiveTarGz -> repo_name <> "-" <> safe_ref <> ".tar.gz"
  }
}

fn raw_blob_response(
  path: String,
  content: String,
  download: Bool,
) -> Response {
  let filename = mime.basename(path)
  wisp.response(200)
  |> wisp.set_header("content-type", mime.content_type_for_path(path))
  |> wisp.set_header(
    "content-disposition",
    content_disposition(filename, download),
  )
  |> wisp.string_body(content)
}

fn browser_raw_blob_response(path: String, content: String) -> Response {
  wisp.response(200)
  |> wisp.set_header("content-type", mime.content_type_for_path(path))
  |> wisp.string_body(content)
}

fn get_repo_raw_response(
  req: Request,
  ctx: Context,
  org_slug: String,
  name: String,
  path_segments: List(String),
  browser: Bool,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case parse_ref_and_file_path(req, path_segments) {
    Error(r) -> r
    Ok(#(query_ref, _)) ->
      case ensure_user(ctx) {
        Error(r) -> r
        Ok(_) ->
          with_repo(ctx, org_slug, name, fn(git_dir, _repo) {
            case resolve_blob_ref_and_path(git_dir, query_ref, path_segments) {
              Error(e) -> git_error_response(e)
              Ok(#(resolved_ref, path)) -> {
                let _ = resolved_ref
                case git_exec.read_blob_bytes(git_dir, resolved_ref, path) {
                  Ok(#(content, _)) ->
                    case browser {
                      True -> browser_raw_blob_response(path, content)
                      False ->
                        raw_blob_response(
                          path,
                          content,
                          download_requested(req),
                        )
                    }
                  Error(e) -> git_error_response(e)
                }
              }
            }
          })
      }
  }
}

pub fn get_repo_raw(
  req: Request,
  ctx: Context,
  org_slug: String,
  name: String,
  path_segments: List(String),
) -> Response {
  get_repo_raw_response(req, ctx, org_slug, name, path_segments, False)
}

pub fn get_repo_raw_browser(
  req: Request,
  ctx: Context,
  org_slug: String,
  name: String,
  path_segments: List(String),
) -> Response {
  get_repo_raw_response(req, ctx, org_slug, name, path_segments, True)
}

pub fn get_repo_archive(
  req: Request,
  ctx: Context,
  org_slug: String,
  name: String,
  ref_archive: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case parse_archive_ref(ref_archive) {
    Error(r) -> r
    Ok(#(ref, format)) ->
      case ensure_user(ctx) {
        Error(r) -> r
        Ok(_) ->
          with_repo(ctx, org_slug, name, fn(git_dir, _repo) {
            case git_exec.archive_to_file(git_dir, ref, format) {
              Ok(path) ->
                wisp.response(200)
                |> wisp.set_header("content-type", archive_content_type(format))
                |> wisp.set_header(
                  "content-disposition",
                  content_disposition(
                    archive_filename(name, ref, format),
                    True,
                  ),
                )
                |> wisp.set_body(wisp.File(path:, offset: 0, limit: option.None))
              Error(e) -> git_error_response(e)
            }
          })
      }
  }
}

fn archive_content_type(format: git_exec.ArchiveFormat) -> String {
  case format {
    git_exec.ArchiveZip -> "application/zip"
    git_exec.ArchiveTarGz -> "application/gzip"
  }
}

fn parse_archive_ref(ref_archive: String) -> Result(#(String, git_exec.ArchiveFormat), Response) {
  case string.ends_with(ref_archive, ".tar.gz") {
    True -> {
      let ref = string.drop_end(ref_archive, 7)
      case ref {
        "" -> Error(wisp.bad_request("Invalid archive ref"))
        _ -> Ok(#(decode_ref_segment(ref), git_exec.ArchiveTarGz))
      }
    }
    False ->
      case string.ends_with(ref_archive, ".zip") {
        True -> {
          let ref = string.drop_end(ref_archive, 4)
          case ref {
            "" -> Error(wisp.bad_request("Invalid archive ref"))
            _ -> Ok(#(decode_ref_segment(ref), git_exec.ArchiveZip))
          }
        }
        False ->
          Error(wisp.bad_request("Archive ref must end with .zip or .tar.gz"))
      }
  }
}

pub fn get_repo_blob(
  req: Request,
  ctx: Context,
  org_slug: String,
  name: String,
  path_segments: List(String),
) -> Response {
  use <- wisp.require_method(req, http.Get)
  case parse_ref_and_file_path(req, path_segments) {
    Error(r) -> r
    Ok(#(query_ref, _)) ->
      case ensure_user(ctx) {
        Error(r) -> r
        Ok(_) ->
          with_repo(ctx, org_slug, name, fn(git_dir, _repo) {
            case resolve_blob_ref_and_path(git_dir, query_ref, path_segments) {
              Error(e) -> git_error_response(e)
              Ok(#(resolved_ref, path)) ->
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
