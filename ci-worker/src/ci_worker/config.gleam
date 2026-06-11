import envie

pub type Config {
  Config(
    api_url: String,
    internal_token: String,
    repos_root: String,
    long_poll_timeout_secs: Int,
    poll_seconds: Int,
    log_patch_seconds: Int,
    job_timeout_seconds: Int,
    dagger_engine_host: String,
  )
}

pub fn load() -> Config {
  let _ = envie.load()

  Config(
    api_url: envie.get_string(
      "GLEAMHUB_API_URL",
      "http://host.docker.internal:9999",
    ),
    internal_token: env_required("INTERNAL_API_TOKEN"),
    repos_root: envie.get_string("GIT_REPOS_ROOT", "/data/repos"),
    long_poll_timeout_secs: envie.get_int("CI_LONG_POLL_TIMEOUT", 55),
    poll_seconds: envie.get_int("CI_POLL_SECONDS", 5),
    log_patch_seconds: envie.get_int("CI_LOG_PATCH_SECONDS", 3),
    job_timeout_seconds: envie.get_int("CI_JOB_TIMEOUT_SECONDS", 1800),
    dagger_engine_host: envie.get_string(
      "_EXPERIMENTAL_DAGGER_RUNNER_HOST",
      "container://gleamhub-dagger-engine",
    ),
  )
}

fn env_required(name: String) -> String {
  case envie.get(name) {
    Ok(value) -> value
    Error(_) -> panic
  }
}

pub fn long_poll_http_timeout_ms(config: Config) -> Int {
  config.long_poll_timeout_secs * 1000 + 10_000
}

pub fn log_patch_ms(config: Config) -> Int {
  config.log_patch_seconds * 1000
}
