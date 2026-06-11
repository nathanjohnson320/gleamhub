import ci_worker/config
import ci_worker/coordinator
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/otp/static_supervisor as supervisor

pub fn main() {
  let cfg = config.load()

  io.println(
    "[ci-worker] long-polling "
    <> cfg.api_url
    <> "/internal/ci/jobs/next (timeout "
    <> int.to_string(cfg.long_poll_timeout_secs)
    <> "s, log patch every "
    <> int.to_string(cfg.log_patch_seconds)
    <> "s)",
  )

  let name = process.new_name("gleamhub.ci_worker")
  let assert Ok(_) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(coordinator.supervised(cfg, name))
    |> supervisor.start

  process.sleep_forever()
}
