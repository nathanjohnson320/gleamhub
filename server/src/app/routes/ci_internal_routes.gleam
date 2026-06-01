import app/ci_long_poll
import app/ci_pipeline
import app/pipeline_events
import app/database
import app/git_exec
import app/json_api
import app/org_access
import app/web.{type Context}
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import pog
import wisp.{type Request, type Response}

fn query_param(req: Request, name: String) -> String {
  case list.find(wisp.get_query(req), fn(pair) {
    let #(key, _) = pair
    key == name
  }) {
    Ok(#(_, value)) -> value
    Error(_) -> ""
  }
}

fn branch_from_ref(refname: String) -> option.Option(String) {
  case string.starts_with(refname, "refs/heads/") {
    True -> option.Some(string.drop_start(refname, 11))
    False -> option.None
  }
}

pub fn enqueue(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Post)
  let org = query_param(req, "org")
  let repo = query_param(req, "repo")
  let branch = query_param(req, "branch")
  let commit_sha = query_param(req, "commit_sha")
  let refname = query_param(req, "ref")

  let source_branch = case branch {
    "" ->
      case branch_from_ref(refname) {
        option.Some(name) -> name
        option.None -> ""
      }
    name -> name
  }

  case org, repo, source_branch, commit_sha {
    "", _, _, _ | _, "", _, _ | _, _, "", _ | _, _, _, "" ->
      wisp.bad_request("org, repo, branch, and commit_sha are required")
    _, _, _, _ ->
      case database.get_repo(ctx.repo(), org, repo) {
        Ok(option.None) -> wisp.not_found()
        Error(_) -> wisp.internal_server_error()
        Ok(option.Some(repo_row)) ->
          case
            git_exec.repo_path(org_access.git_repos_root(ctx), repo_row.disk_path)
          {
            Error(_) -> wisp.internal_server_error()
            Ok(git_dir) ->
              case
                ci_pipeline.enqueue_for_branch_push(
                  ctx.pipeline_events_name,
                  ctx.repo(),
                  org,
                  repo,
                  git_dir,
                  source_branch,
                  commit_sha,
                )
              {
                Ok(Nil) -> wisp.response(204)
                Error(_) -> wisp.internal_server_error()
              }
          }
      }
  }
}

pub fn next_job(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Get)
  let timeout_secs = ci_long_poll.timeout_secs_from_query(query_param(req, "timeout"))
  case ci_long_poll.wait_for_job(ctx.repo(), timeout_secs) {
    Ok(option.None) -> wisp.response(204)
    Error(_) -> wisp.internal_server_error()
    Ok(option.Some(claimed)) -> {
      case
        database.get_latest_pipeline_run_optional(
          ctx.repo(),
          claimed.merge_request_id,
        )
      {
        Ok(option.Some(run)) ->
          pipeline_events.publish_run(ctx.pipeline_events_name, run)
        _ -> Nil
      }
      case database.get_pipeline_run_job(ctx.repo(), claimed.id) {
        Ok(option.Some(job)) -> json_ok(job_json(job), 200)
        Ok(option.None) -> wisp.internal_server_error()
        Error(_) -> wisp.internal_server_error()
      }
    }
  }
}

pub fn update_job(req: Request, ctx: Context, run_id: String) -> Response {
  use <- wisp.require_method(req, http.Patch)
  use body <- wisp.require_json(req)
  let decoder = {
    use state <- decode.field("state", decode.string)
    use log <- decode.optional_field("log", "", decode.string)
    decode.success(#(state, log))
  }
  case decode.run(body, decoder) {
    Error(_) -> wisp.bad_request("Invalid JSON body")
    Ok(#(state, log)) ->
      case database.update_pipeline_run(
        ctx.repo(),
        run_id,
        state,
        ci_pipeline.truncate_log(log),
      ) {
        Ok(run) -> {
          pipeline_events.publish_run(ctx.pipeline_events_name, run)
          json_ok(json_api.pipeline_run_json(run), 200)
        }
        Error(pog.ConstraintViolated(..)) -> wisp.response(409)
        Error(_) -> wisp.internal_server_error()
      }
  }
}

fn job_json(job: database.PipelineRunJobRow) -> json.Json {
  json.object([
    #("id", json.string(job.id)),
    #("org_slug", json.string(job.org_slug)),
    #("repo_name", json.string(job.repo_name)),
    #("disk_path", json.string(job.disk_path)),
    #("commit_sha", json.string(job.commit_sha)),
    #("module_path", json.string(job.module_path)),
    #("entry_function", json.string(job.entry_function)),
    #("merge_request_id", json.string(job.merge_request_id)),
  ])
}

fn json_ok(body: json.Json, status: Int) -> Response {
  json.to_string(body) |> wisp.json_response(status)
}
