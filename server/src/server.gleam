import ci/events as pipeline_events
import envie
import gleam/erlang/process
import gleam/option
import gleam/otp/static_supervisor as supervisor
import http/clerk_api
import http/clerk_jwks
import http/entry as http_entry
import http/router
import http/web.{Context}
import mist
import pog
import simplifile
import wisp

const app_name = "server"

pub fn main() {
  wisp.configure_logger()

  // Prefer values from server/.env over inherited shell env (empty CLERK_* exports
  // otherwise block keys that are present in the file).
  let _ = envie.load_override()

  let assert Ok(secret_key_base) = envie.get("SECRET_KEY_BASE")
  let assert Ok(db_url) = envie.get("DATABASE_URL")

  let assert Ok(clerk_keys) = clerk_jwks.load_from_env()

  let assert Ok(internal_api_token) = envie.get("INTERNAL_API_TOKEN")

  let clerk_issuer = case envie.get("CLERK_ISSUER") {
    Ok(issuer) -> option.Some(issuer)
    Error(_) -> option.None
  }

  let git_repos_root = envie.get_string("GIT_REPOS_ROOT", "./data/repos")

  let git_host = envie.get_string("GLEAMHUB_GIT_HOST", "localhost")

  let git_port = envie.get_int("GLEAMHUB_GIT_PORT", 2222)

  let port = envie.get_int("PORT", 9999)

  let pool_name = process.new_name(app_name)
  let pipeline_events_name = process.new_name("gleamhub.pipeline_events")
  let assert Ok(db_config) = pog.url_config(pool_name, db_url)

  let db =
    db_config
    |> pog.pool_size(15)
    |> pog.supervised

  let ctx =
    Context(
      clerk_keys: clerk_keys,
      static_directory: static_directory(),
      repo: fn() -> pog.Connection { pog.named_connection(pool_name) },
      git_repos_root: git_repos_root,
      git_host: git_host,
      git_port: git_port,
      user_id: option.None,
      clerk: clerk_api.client_from_env(),
      internal_api_token: internal_api_token,
      clerk_issuer: clerk_issuer,
      pipeline_events_name: pipeline_events_name,
    )

  let handler = http_entry.handler(router.handle_request, secret_key_base, ctx)

  let web =
    handler
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(port)
    |> mist.supervised()

  let assert Ok(_) =
    supervisor.new(supervisor.RestForOne)
    |> supervisor.add(db)
    |> supervisor.add(pipeline_events.supervised(pipeline_events_name))
    |> supervisor.add(web)
    |> supervisor.start

  process.sleep_forever()
}

fn static_directory() {
  case envie.get("STATIC_DIRECTORY") {
    Ok(dir) -> dir
    Error(_) -> {
      let dev_static = "./priv/static"
      case simplifile.read(dev_static <> "/index.html") {
        Ok(_) -> dev_static
        Error(_) -> {
          let assert Ok(priv_directory) = wisp.priv_directory(app_name)
          priv_directory <> "/static"
        }
      }
    }
  }
}
