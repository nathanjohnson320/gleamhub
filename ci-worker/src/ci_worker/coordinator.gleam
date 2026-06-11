import ci_worker/api_client
import ci_worker/config.{type Config}
import ci_worker/job.{type Job}
import ci_worker/runner
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/option
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result

pub type Message {
  Poll
  JobFinished
}

type State {
  State(config: Config, self: process.Subject(Message))
}

@external(erlang, "ci_worker_spawn_ffi", "spawn_job")
fn spawn_job(job: fn() -> Nil, cleanup: fn(String) -> Nil) -> Nil

pub fn supervised(
  config: Config,
  name: process.Name(Message),
) -> supervision.ChildSpecification(Nil) {
  supervision.worker(fn() { start(config, name) })
}

pub fn start(
  config: Config,
  name: process.Name(Message),
) -> Result(actor.Started(Nil), actor.StartError) {
  actor.new_with_initialiser(1000, fn(self) {
    process.send(self, Poll)
    Ok(
      actor.initialised(State(config:, self:))
      |> actor.returning(Nil),
    )
  })
  |> actor.on_message(handle_message)
  |> actor.named(name)
  |> actor.start
  |> result.map(fn(started) { actor.Started(pid: started.pid, data: Nil) })
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Poll -> {
      handle_poll(state)
      actor.continue(state)
    }
    JobFinished -> {
      process.send(state.self, Poll)
      actor.continue(state)
    }
  }
}

fn handle_poll(state: State) -> Nil {
  case api_client.next_job(state.config, state.config.long_poll_timeout_secs) {
    Ok(option.None) -> process.send(state.self, Poll)
    Ok(option.Some(body)) -> run_claimed_job(state, body)
    Error(api_client.HttpError(msg)) -> {
      io.println("[ci-worker] jobs/next request failed: " <> msg)
      backoff_poll(state)
    }
    Error(api_client.BadUrl) -> {
      io.println("[ci-worker] jobs/next URL invalid")
      backoff_poll(state)
    }
    Error(api_client.UnexpectedStatus(status)) -> {
      io.println(
        "[ci-worker] jobs/next returned HTTP " <> int.to_string(status),
      )
      backoff_poll(state)
    }
  }
}

fn run_claimed_job(state: State, body: String) -> Nil {
  case job.decode(body) {
    Error(_) -> {
      io.println("[ci-worker] invalid job JSON from jobs/next")
      process.send(state.self, Poll)
    }
    Ok(claimed) -> {
      let config = state.config
      let self = state.self
      let _ =
        spawn_job(fn() { run_job_work(config, claimed, self) }, fn(reason) {
          run_job_crash(config, claimed, self, reason)
        })
      Nil
    }
  }
}

fn run_job_work(
  config: Config,
  claimed: Job,
  self: process.Subject(Message),
) -> Nil {
  let patch_running = fn(log) {
    case api_client.patch_job(config, claimed.id, "running", log) {
      Ok(api_client.PatchOk) -> True
      Ok(api_client.PatchRejected) -> False
      Error(_) -> True
    }
  }
  let outcome = runner.run(config, claimed, patch_running)
  runner.log_outcome(claimed, outcome)
  process.send(self, JobFinished)
}

fn run_job_crash(
  config: Config,
  claimed: Job,
  self: process.Subject(Message),
  reason: String,
) -> Nil {
  io.println("[ci-worker] job " <> claimed.id <> " crashed: " <> reason)
  let log = "CI worker job process crashed:\n" <> reason
  let _ = api_client.patch_job(config, claimed.id, "failure", log)
  runner.log_outcome(claimed, runner.Failure)
  process.send(self, JobFinished)
}

fn backoff_poll(state: State) -> Nil {
  process.sleep(state.config.poll_seconds * 1000)
  process.send(state.self, Poll)
}
