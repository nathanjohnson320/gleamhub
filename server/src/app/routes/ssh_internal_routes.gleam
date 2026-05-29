import app/database
import app/git_exec
import app/git_path
import app/json_api
import app/org_access
import app/ref_update_policy
import app/web.{type Context}
import gleam/http
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import wisp.{type Request, type Response}

pub fn authorized_keys(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Get)
  let key_blob = query_param(req, "k")
  case key_blob {
    "" -> plain_text("", 200)
    blob -> {
      case database.authorized_key_line(ctx.repo(), blob) {
        Ok(option.Some(line)) -> plain_text(line <> "\n", 200)
        Ok(option.None) -> plain_text("", 200)
        Error(_) -> wisp.internal_server_error()
      }
    }
  }
}

pub fn access_check(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Get)
  let org = query_param(req, "org")
  let repo = query_param(req, "repo")
  let user_id = query_param(req, "user_id")
  let op = query_param(req, "op")

  let receive_pack = op == "receive-pack"

  let access = org_access.git_access(ctx, user_id, org, repo, receive_pack)

  let allowed = case receive_pack {
    True -> access.write
    False -> access.read
  }

  case allowed {
    True ->
      json_api.access_json(access.read, access.write)
      |> json.to_string
      |> wisp.json_response(200)
    False -> wisp.response(403)
  }
}

pub fn ref_update_check(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Get)
  let org = query_param(req, "org")
  let repo = query_param(req, "repo")
  let user_id = query_param(req, "user_id")
  let oldrev = query_param(req, "oldrev")
  let newrev = query_param(req, "newrev")
  let ref = query_param(req, "ref")

  let access = org_access.git_access(ctx, user_id, org, repo, True)
  case access.write {
    False -> deny("access denied")
    True ->
      case database.get_repo(ctx.repo(), org, repo) {
        Ok(option.None) -> deny("repository not found")
        Error(_) -> wisp.internal_server_error()
        Ok(option.Some(repo_row)) -> {
          case git_exec.repo_path(org_access.git_repos_root(ctx), repo_row.disk_path) {
            Error(_) -> deny("repository not found")
            Ok(git_dir) ->
              case normalize_rev(oldrev), normalize_rev(newrev) {
                Ok(valid_oldrev), Ok(valid_newrev) ->
                  evaluate_ref_update(
                    ctx,
                    org,
                    repo,
                    git_dir,
                    valid_oldrev,
                    valid_newrev,
                    ref,
                  )
                _, _ -> deny("invalid revision")
              }
          }
        }
      }
  }
}

fn evaluate_ref_update(
  ctx: Context,
  org: String,
  repo: String,
  git_dir: String,
  oldrev: String,
  newrev: String,
  ref: String,
) -> Response {
  case string.starts_with(ref, "refs/heads/") {
    False -> allow()
    True -> {
      let branch = string.drop_start(ref, 11)
      case git_path.normalize_branch(branch) {
        Error(_) -> deny("invalid branch name")
        Ok(branch_name) ->
          case database.is_branch_protected(ctx.repo(), org, repo, branch_name) {
            Error(_) -> wisp.internal_server_error()
            Ok(False) -> allow()
            Ok(True) ->
              case git_exec.is_ancestor(git_dir, oldrev, newrev) {
                Ok(fast_forward) ->
                  case
                    ref_update_policy.check_protected_branch(
                      branch_name,
                      oldrev,
                      newrev,
                      fast_forward,
                    )
                  {
                    Ok(Nil) -> allow()
                    Error(msg) -> deny(msg)
                  }
                Error(_) -> wisp.internal_server_error()
              }
          }
      }
    }
  }
}

fn allow() -> Response {
  json_api.ref_update_json(True, "")
  |> json.to_string
  |> wisp.json_response(200)
}

fn deny(message: String) -> Response {
  json_api.ref_update_json(False, message)
  |> json.to_string
  |> wisp.json_response(403)
}

fn plain_text(body: String, status: Int) -> Response {
  wisp.response(status)
  |> wisp.set_header("content-type", "text/plain; charset=utf-8")
  |> wisp.string_body(body)
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

fn normalize_rev(rev: String) -> Result(String, Nil) {
  case git_exec.is_zero_sha(rev) {
    True -> Ok(git_exec.zero_sha_value())
    False ->
      case git_path.normalize_sha(rev) {
        Ok(sha) -> Ok(sha)
        Error(_) -> Error(Nil)
      }
  }
}
