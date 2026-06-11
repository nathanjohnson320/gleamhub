import ci/events as pipeline_events
import ci/long_poll as ci_long_poll
import ci/pipeline as ci_pipeline
import database
import git/exec as git_exec
import gleam/dynamic/decode
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
import notifications/create as notify
import pog
import wisp.{type Request, type Response}

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

fn branch_from_ref(refname: String) -> option.Option(String) {
  case string.starts_with(refname, "refs/heads/") {
    True -> option.Some(string.drop_start(refname, 11))
    False -> option.None
  }
}

type EnqueueRequest {
  EnqueueRequest(
    org: String,
    repo: String,
    source_branch: String,
    commit_sha: String,
  )
}

fn form_param(params: List(#(String, String)), name: String) -> String {
  params
  |> list.key_find(name)
  |> result.unwrap("")
}

fn resolve_source_branch(branch: String, refname: String) -> String {
  case branch {
    "" ->
      case branch_from_ref(refname) {
        option.Some(name) -> name
        option.None -> ""
      }
    name -> name
  }
}

fn enqueue_from_fields(
  org: String,
  repo: String,
  branch: String,
  commit_sha: String,
  refname: String,
) -> option.Option(EnqueueRequest) {
  let source_branch = resolve_source_branch(branch, refname)
  case org, repo, source_branch, commit_sha {
    "", _, _, _ | _, "", _, _ | _, _, "", _ | _, _, _, "" -> option.None
    _, _, _, _ ->
      option.Some(EnqueueRequest(org:, repo:, source_branch:, commit_sha:))
  }
}

fn enqueue_from_query(req: Request) -> option.Option(EnqueueRequest) {
  enqueue_from_fields(
    query_param(req, "org"),
    query_param(req, "repo"),
    query_param(req, "branch"),
    query_param(req, "commit_sha"),
    query_param(req, "ref"),
  )
}

fn enqueue_from_form(body: String) -> option.Option(EnqueueRequest) {
  case uri.parse_query(body) {
    Ok(params) ->
      enqueue_from_fields(
        form_param(params, "org"),
        form_param(params, "repo"),
        form_param(params, "branch"),
        form_param(params, "commit_sha"),
        form_param(params, "ref"),
      )
    Error(_) -> option.None
  }
}

fn run_enqueue(ctx: Context, request: EnqueueRequest) -> Response {
  case database.get_repo(ctx.repo(), request.org, request.repo) {
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
              request.org,
              request.repo,
              git_dir,
              request.source_branch,
              request.commit_sha,
            )
          {
            Ok(Nil) -> wisp.response(204)
            Error(_) -> wisp.internal_server_error()
          }
      }
  }
}

pub fn enqueue(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Post)
  case enqueue_from_query(req) {
    option.Some(request) -> run_enqueue(ctx, request)
    option.None -> enqueue_from_body(req, ctx)
  }
}

fn enqueue_from_body(req: Request, ctx: Context) -> Response {
  use body <- wisp.require_string_body(req)
  case enqueue_from_form(body) {
    option.Some(request) -> run_enqueue(ctx, request)
    option.None ->
      wisp.bad_request("org, repo, branch, and commit_sha are required")
  }
}

pub fn next_job(req: Request, ctx: Context) -> Response {
  use <- wisp.require_method(req, http.Get)
  let timeout_secs =
    ci_long_poll.timeout_secs_from_query(query_param(req, "timeout"))
  case ci_long_poll.wait_for_job(ctx.repo(), timeout_secs) {
    Ok(option.None) -> wisp.response(204)
    Error(_) -> wisp.internal_server_error()
    Ok(option.Some(claimed)) -> {
      case claimed.merge_request_id {
        "" -> Nil
        mr_id ->
          case
            database.get_latest_pipeline_run_optional(ctx.repo(), mr_id)
          {
            Ok(option.Some(run)) ->
              pipeline_events.publish_run(ctx.pipeline_events_name, run)
            _ -> Nil
          }
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
      case
        database.update_pipeline_run(
          ctx.repo(),
          run_id,
          state,
          ci_pipeline.truncate_log(log),
        )
      {
        Ok(run) -> {
          pipeline_events.publish_run(ctx.pipeline_events_name, run)
          notify_ci_if_terminal(ctx, run)
          json_ok(json_api.pipeline_run_json(run), 200)
        }
        Error(pog.ConstraintViolated(..)) -> wisp.response(409)
        Error(_) -> wisp.internal_server_error()
      }
  }
}

fn notify_ci_if_terminal(ctx: Context, run: database.PipelineRunRow) -> Nil {
  case run.merge_request_id, run.state {
    "", _ -> Nil
    _, "success" | _, "failure" | _, "cancelled" | _, "skipped" ->
      case database.get_merge_request_brief(ctx.repo(), run.merge_request_id) {
        Ok(option.Some(mr)) ->
          notify.ci_completed(
            ctx,
            mr.author_user_id,
            mr.org_slug,
            mr.repo_name,
            mr.number,
            mr.title,
            run.id,
            run.state,
            run.commit_sha,
          )
        _ -> Nil
      }
    _, _ -> Nil
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
