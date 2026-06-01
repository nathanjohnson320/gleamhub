import app/database
import app/git_exec
import gleam/option

pub fn combine_merge_check(
  git: git_exec.MergeCheck,
  pipeline: option.Option(database.PipelineRunRow),
  head_sha: String,
) -> git_exec.MergeCheck {
  case git.mergeable {
    False -> git
    True ->
      case pipeline {
        option.None -> git
        option.Some(run) ->
          case run.state {
            "skipped" -> git
            "success" ->
              case run.commit_sha == head_sha {
                True -> git
                False ->
                  git_exec.MergeCheck(
                    mergeable: False,
                    message: "Checks stale — push to re-run",
                  )
              }
            "queued" | "running" ->
              git_exec.MergeCheck(mergeable: False, message: "Checks running")
            "failure" ->
              git_exec.MergeCheck(mergeable: False, message: "Checks failed")
            _ ->
              git_exec.MergeCheck(mergeable: False, message: "Checks incomplete")
          }
      }
  }
}

pub fn pipeline_message(run: database.PipelineRunRow) -> String {
  case run.state {
    "skipped" -> "CI not configured"
    "queued" -> "Checks queued"
    "running" -> "Checks running"
    "success" -> "Checks passed"
    "failure" -> "Checks failed"
    "cancelled" -> "Checks cancelled"
    _ -> "Checks incomplete"
  }
}

pub fn pipeline_has_module(run: database.PipelineRunRow) -> Bool {
  run.module_path != ""
}

pub fn pipeline_status_label(run: database.PipelineRunRow) -> String {
  case run.state {
    "success" -> "Checks passing"
    "failure" -> "Checks failed"
    "running" -> "Checks running…"
    "queued" -> "Checks queued…"
    "skipped" -> "CI not configured"
    _ -> pipeline_message(run)
  }
}
