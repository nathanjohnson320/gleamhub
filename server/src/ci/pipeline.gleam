import ci/discovery as ci_discovery
import ci/events as pipeline_events
import database
import git/exec as git_exec
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import pog

const max_log_bytes = 262_144

pub fn truncate_log(text: String) -> String {
  case string.length(text) > max_log_bytes {
    True ->
      string.slice(text, 0, max_log_bytes)
      <> "\n\n[log truncated at "
      <> int.to_string(max_log_bytes)
      <> " bytes]"
    False -> text
  }
}

pub fn enqueue_for_merge_request(
  events_name: process.Name(pipeline_events.Message),
  db: pog.Connection,
  repository_id: String,
  merge_request_id: String,
  git_dir: String,
  source_branch: String,
  trigger: String,
) -> Result(database.PipelineRunRow, pog.QueryError) {
  case ci_discovery.branch_head_sha(git_dir, source_branch) {
    Ok(commit_sha) ->
      enqueue_for_merge_request_at_sha(
        events_name,
        db,
        repository_id,
        merge_request_id,
        git_dir,
        commit_sha,
        trigger,
      )
    Error(_) -> Error(pog.PostgresqlError("", "", "branch head not found"))
  }
}

pub fn enqueue_for_merge_request_at_sha(
  events_name: process.Name(pipeline_events.Message),
  db: pog.Connection,
  repository_id: String,
  merge_request_id: String,
  git_dir: String,
  commit_sha: String,
  trigger: String,
) -> Result(database.PipelineRunRow, pog.QueryError) {
  case trigger {
    "manual" ->
      insert_run(
        events_name,
        db,
        repository_id,
        merge_request_id,
        git_dir,
        commit_sha,
        trigger,
      )
    _ ->
      case
        database.pipeline_run_exists_for_sha(db, merge_request_id, commit_sha)
      {
        Ok(True) -> database.get_latest_pipeline_run(db, merge_request_id)
        Ok(False) ->
          insert_run(
            events_name,
            db,
            repository_id,
            merge_request_id,
            git_dir,
            commit_sha,
            trigger,
          )
        Error(e) -> Error(e)
      }
  }
}

fn insert_run(
  events_name: process.Name(pipeline_events.Message),
  db: pog.Connection,
  repository_id: String,
  merge_request_id: String,
  git_dir: String,
  commit_sha: String,
  trigger: String,
) -> Result(database.PipelineRunRow, pog.QueryError) {
  let module = ci_discovery.discover_module(git_dir, commit_sha)
  let #(state, module_path) = case module {
    option.None -> #("skipped", option.None)
    option.Some(path) -> #("queued", option.Some(path))
  }
  case
    database.insert_pipeline_run(
      db,
      repository_id,
      merge_request_id,
      commit_sha,
      module_path,
      ci_discovery.default_entry_function,
      state,
      trigger,
    )
  {
    Ok(run) -> {
      pipeline_events.publish_run(events_name, run)
      Ok(run)
    }
    Error(e) -> Error(e)
  }
}

pub fn enqueue_for_branch_push(
  events_name: process.Name(pipeline_events.Message),
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  git_dir: String,
  source_branch: String,
  commit_sha: String,
) -> Result(Nil, pog.QueryError) {
  use mrs <- result.try(database.list_open_merge_requests_by_source(
    db,
    org_slug,
    repo_name,
    source_branch,
  ))
  use repo <- result.try(database.get_repo(db, org_slug, repo_name))
  let assert option.Some(repo_row) = repo
  list.each(mrs, fn(mr) {
    let _ =
      enqueue_for_merge_request_at_sha(
        events_name,
        db,
        repo_row.id,
        mr.id,
        git_dir,
        commit_sha,
        "push",
      )
    Nil
  })
  let _ =
    enqueue_for_default_branch_push(
      events_name,
      db,
      repo_row.id,
      git_dir,
      source_branch,
      commit_sha,
    )
  Ok(Nil)
}

pub fn enqueue_for_default_branch_push(
  events_name: process.Name(pipeline_events.Message),
  db: pog.Connection,
  repository_id: String,
  git_dir: String,
  branch: String,
  commit_sha: String,
) -> Result(Nil, pog.QueryError) {
  case git_exec.default_branch(git_dir) {
    Ok(default_branch) ->
      case default_branch == branch {
        False -> Ok(Nil)
        True ->
          case
            database.pipeline_run_exists_for_branch_sha(
              db,
              repository_id,
              branch,
              commit_sha,
            )
          {
            Ok(True) -> Ok(Nil)
            Ok(False) -> insert_branch_run(
              events_name,
              db,
              repository_id,
              git_dir,
              branch,
              commit_sha,
            )
            Error(e) -> Error(e)
          }
      }
    Error(_) -> Ok(Nil)
  }
}

fn insert_branch_run(
  events_name: process.Name(pipeline_events.Message),
  db: pog.Connection,
  repository_id: String,
  git_dir: String,
  branch: String,
  commit_sha: String,
) -> Result(Nil, pog.QueryError) {
  let module = ci_discovery.discover_module(git_dir, commit_sha)
  let #(state, module_path) = case module {
    option.None -> #("skipped", option.None)
    option.Some(path) -> #("queued", option.Some(path))
  }
  case
    database.insert_branch_pipeline_run(
      db,
      repository_id,
      branch,
      commit_sha,
      module_path,
      ci_discovery.default_entry_function,
      state,
      "push",
    )
  {
    Ok(run) -> {
      pipeline_events.publish_run(events_name, run)
      Ok(Nil)
    }
    Error(e) -> Error(e)
  }
}
