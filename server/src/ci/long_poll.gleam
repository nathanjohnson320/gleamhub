import database
import gleam/erlang/process
import gleam/int
import gleam/option
import pog

const poll_interval_ms = 500

const default_timeout_secs = 55

const max_timeout_secs = 120

const min_timeout_secs = 1

pub fn timeout_secs_from_query(value: String) -> Int {
  case int.parse(value) {
    Ok(secs) -> int.clamp(secs, min: min_timeout_secs, max: max_timeout_secs)
    Error(_) -> default_timeout_secs
  }
}

pub fn wait_for_job(
  db: pog.Connection,
  timeout_secs: Int,
) -> Result(option.Option(database.PipelineRunJobRow), pog.QueryError) {
  let max_attempts = int.max(1, timeout_secs * 1000 / poll_interval_ms)
  wait_loop(db, max_attempts)
}

fn wait_loop(
  db: pog.Connection,
  attempts_left: Int,
) -> Result(option.Option(database.PipelineRunJobRow), pog.QueryError) {
  case database.claim_next_pipeline_job(db) {
    Ok(option.Some(job)) -> Ok(option.Some(job))
    Ok(option.None) ->
      case attempts_left {
        1 -> Ok(option.None)
        n -> {
          process.sleep(poll_interval_ms)
          wait_loop(db, n - 1)
        }
      }
    Error(e) -> Error(e)
  }
}
