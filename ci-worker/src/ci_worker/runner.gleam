import ci_worker/api_client
import ci_worker/config.{type Config}
import ci_worker/exec
import ci_worker/job.{type Job}
import gleam/erlang/process
import gleam/int
import gleam/io

pub type Outcome {
  Success
  Failure
  Skipped
  Cancelled
}

pub type JobAborted {
  JobAborted
}

pub fn run(
  config: Config,
  job: Job,
  patch_running: fn(String) -> Bool,
) -> Outcome {
  exec.set_dagger_host(config.dagger_engine_host)

  let checkout = exec.temp_dir()
  let log_file = exec.temp_file()
  let bare_repo = config.repos_root <> "/" <> job.disk_path

  append_header(job, log_file)
  let _ = patch_running(read_log(log_file))

  case clone_and_checkout(bare_repo, checkout, job.commit_sha, log_file) {
    Error(Nil) -> finish(config, job.id, log_file, checkout, Failure)
    Ok(Nil) ->
      case job.module_path {
        "" -> {
          exec.append_line(log_file, "No Dagger module at commit")
          finish(config, job.id, log_file, checkout, Skipped)
        }
        module_path -> {
          let module_dir = checkout <> "/" <> module_path
          case exec.file_exists(module_dir <> "/dagger.json") {
            False -> {
              exec.append_line(
                log_file,
                "Module path " <> module_path <> " missing dagger.json",
              )
              finish(config, job.id, log_file, checkout, Failure)
            }
            True ->
              run_dagger(
                config,
                job,
                checkout,
                log_file,
                module_dir,
                patch_running,
              )
          }
        }
      }
  }
}

fn append_header(job: Job, log_file: String) -> Nil {
  exec.append_line(log_file, "=== Gleamhub CI ===")
  exec.append_line(
    log_file,
    "Repository: "
      <> job.org_slug
      <> "/"
      <> job.repo_name
      <> " @ "
      <> job.short_sha(job.commit_sha),
  )
}

fn clone_and_checkout(
  bare_repo: String,
  checkout: String,
  commit_sha: String,
  log_file: String,
) -> Result(Nil, Nil) {
  exec.append_line(log_file, "Cloning bare repository...")
  case exec.git_clone(bare_repo, checkout) {
    Error(msg) -> {
      exec.append_line(log_file, msg)
      Error(Nil)
    }
    Ok(Nil) -> {
      exec.append_line(log_file, "Checking out " <> commit_sha <> "...")
      case exec.git_checkout(checkout, commit_sha) {
        Error(msg) -> {
          exec.append_line(log_file, msg)
          Error(Nil)
        }
        Ok(Nil) -> Ok(Nil)
      }
    }
  }
}

fn run_dagger(
  config: Config,
  job: Job,
  checkout: String,
  log_file: String,
  module_dir: String,
  patch_running: fn(String) -> Bool,
) -> Outcome {
  exec.append_line(log_file, "")
  exec.append_line(
    log_file,
    "Running: dagger call -m "
      <> module_dir
      <> " "
      <> job.entry_function
      <> " --source="
      <> checkout,
  )

  let _ = patch_running(read_log(log_file))

  case
    exec.start_dagger(
      module_dir,
      job.entry_function,
      checkout,
      log_file,
      config.job_timeout_seconds,
    )
  {
    Error(msg) -> {
      exec.append_line(log_file, msg)
      finish(config, job.id, log_file, checkout, Failure)
    }
    Ok(dagger_pid) ->
      case wait_for_dagger(config, log_file, dagger_pid, patch_running) {
        Error(JobAborted) -> {
          exec.append_line(
            log_file,
            "CI worker stopped: job reclaimed or cancelled",
          )
          exec.kill_process(dagger_pid)
          cleanup(log_file, checkout)
          Cancelled
        }
        Ok(exit_code) -> {
          let outcome = outcome_from_exit(exit_code, config, log_file)
          finish(config, job.id, log_file, checkout, outcome)
        }
      }
  }
}

fn wait_for_dagger(
  config: Config,
  log_file: String,
  dagger_pid: process.Pid,
  patch_running: fn(String) -> Bool,
) -> Result(Int, JobAborted) {
  case exec.process_alive(dagger_pid) {
    False -> wait_exit_code(dagger_pid)
    True -> {
      case patch_running(read_log(log_file)) {
        False -> Error(JobAborted)
        True -> {
          process.sleep(config.log_patch_ms(config))
          wait_for_dagger(config, log_file, dagger_pid, patch_running)
        }
      }
    }
  }
}

fn wait_exit_code(dagger_pid: process.Pid) -> Result(Int, JobAborted) {
  wait_exit_code_loop(dagger_pid, 0)
}

fn wait_exit_code_loop(
  dagger_pid: process.Pid,
  attempts: Int,
) -> Result(Int, JobAborted) {
  case exec.exit_code(dagger_pid) {
    Ok(code) -> Ok(code)
    Error(exec.NotReady) ->
      case attempts >= 50 {
        True -> Ok(1)
        False -> {
          process.sleep(100)
          wait_exit_code_loop(dagger_pid, attempts + 1)
        }
      }
  }
}

fn outcome_from_exit(
  exit_code: Int,
  config: Config,
  log_file: String,
) -> Outcome {
  case exit_code {
    0 -> Success
    124 -> {
      exec.append_line(log_file, "")
      exec.append_line(
        log_file,
        "[job timed out after "
          <> int.to_string(config.job_timeout_seconds)
          <> "s]",
      )
      Failure
    }
    _ -> Failure
  }
}

fn finish(
  config: Config,
  job_id: String,
  log_file: String,
  checkout: String,
  outcome: Outcome,
) -> Outcome {
  let state = state_for_outcome(outcome)
  let _ = api_client.patch_job(config, job_id, state, read_log(log_file))
  cleanup(log_file, checkout)
  outcome
}

fn state_for_outcome(outcome: Outcome) -> String {
  case outcome {
    Success -> "success"
    Failure -> "failure"
    Skipped -> "skipped"
    Cancelled -> "failure"
  }
}

fn read_log(log_file: String) -> String {
  exec.read_file(log_file)
}

fn cleanup(log_file: String, checkout: String) -> Nil {
  exec.remove_path(log_file)
  exec.remove_path(checkout)
}

pub fn log_outcome(job: Job, outcome: Outcome) -> Nil {
  let label = case outcome {
    Success -> "success"
    Failure -> "failure"
    Skipped -> "skipped"
    Cancelled -> "cancelled"
  }
  io.println(
    "[ci-worker] finished job "
    <> job.id
    <> " for "
    <> job.org_slug
    <> "/"
    <> job.repo_name
    <> "@"
    <> job.commit_sha
    <> " ("
    <> label
    <> ")",
  )
}
