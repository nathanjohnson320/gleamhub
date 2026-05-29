import gleam/erlang/process
import gleam/io
import gleam/otp/actor
import pog

@external(erlang, "db_test_ffi", "fail")
fn fail_ffi(message: String) -> Nil

/// Ephemeral Postgres on port 5433 via docker-compose.test.yml.
/// `gleam test` starts it before all tests and tears it down after.
@external(erlang, "db_test_ffi", "start")
fn start_ffi() -> String

@external(erlang, "db_test_ffi", "stop")
fn stop_ffi() -> Nil

@external(erlang, "db_test_ffi", "database_url")
fn database_url_ffi() -> String

@external(erlang, "db_test_ffi", "reset")
fn reset_ffi(url: String) -> String

@external(erlang, "db_test_ffi", "store_pool_name")
fn store_pool_name_ffi(name: process.Name(pog.Message)) -> Nil

@external(erlang, "db_test_ffi", "pool_name")
fn pool_name_ffi() -> process.Name(pog.Message)

pub fn require_db() -> Nil {
  case start_ffi() {
    "ok" -> {
      let name = process.new_name("gleamhub_db_test")
      store_pool_name_ffi(name)
      let assert Ok(cfg) = pog.url_config(name, database_url_ffi())
      let assert Ok(actor.Started(_pid, _db)) = pog.start(cfg)
      io.println("test database: postgres on port 5433")
      Nil
    }
    msg ->
      fail_ffi(
        "Test database setup failed (gleam test requires Docker):\n" <> msg,
      )
  }
}

pub fn stop() -> Nil {
  stop_ffi()
}

pub fn with_db(run: fn(pog.Connection) -> Nil) -> Nil {
  let assert "ok" = reset_ffi(database_url_ffi())
  run(pog.named_connection(pool_name_ffi()))
}
