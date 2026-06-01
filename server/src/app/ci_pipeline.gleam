import app/ci_discovery
import app/database
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
        db,
        repository_id,
        merge_request_id,
        git_dir,
        commit_sha,
        trigger,
      )
    Error(_) ->
      Error(pog.PostgresqlError("", "", "branch head not found"))
  }
}

pub fn enqueue_for_merge_request_at_sha(
  db: pog.Connection,
  repository_id: String,
  merge_request_id: String,
  git_dir: String,
  commit_sha: String,
  trigger: String,
) -> Result(database.PipelineRunRow, pog.QueryError) {
  case trigger {
    "manual" ->
      insert_run(db, repository_id, merge_request_id, git_dir, commit_sha, trigger)
    _ ->
      case database.pipeline_run_exists_for_sha(db, merge_request_id, commit_sha) {
        Ok(True) -> database.get_latest_pipeline_run(db, merge_request_id)
        Ok(False) ->
          insert_run(db, repository_id, merge_request_id, git_dir, commit_sha, trigger)
        Error(e) -> Error(e)
      }
  }
}

fn insert_run(
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
}

pub fn enqueue_for_branch_push(
  db: pog.Connection,
  org_slug: String,
  repo_name: String,
  git_dir: String,
  source_branch: String,
  commit_sha: String,
) -> Result(Nil, pog.QueryError) {
  use mrs <- result.try(
    database.list_open_merge_requests_by_source(
      db,
      org_slug,
      repo_name,
      source_branch,
    ),
  )
  use repo <- result.try(database.get_repo(db, org_slug, repo_name))
  let assert option.Some(repo_row) = repo
  list.each(mrs, fn(mr) {
    let _ =
      enqueue_for_merge_request_at_sha(
        db,
        repo_row.id,
        mr.id,
        git_dir,
        commit_sha,
        "push",
      )
    Nil
  })
  Ok(Nil)
}
