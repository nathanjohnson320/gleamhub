import app/clerk_api
import app/clerk_jwks
import app/router
import app/web.{Context}
import dot_env
import dot_env/env
import gleam/erlang/process
import gleam/option
import gleam/otp/static_supervisor as supervisor
import mist
import pog
import simplifile
import wisp
import wisp/wisp_mist
const app_name = "server"

pub fn main() {
  wisp.configure_logger()

  dot_env.new()
  |> dot_env.load()

  let assert Ok(secret_key_base) = env.get_string("SECRET_KEY_BASE")
  let assert Ok(db_url) = env.get_string("DATABASE_URL")

  let assert Ok(clerk_keys) = clerk_jwks.load_from_env()

  let assert Ok(internal_api_token) = env.get_string("INTERNAL_API_TOKEN")

  let clerk_issuer = case env.get_string("CLERK_ISSUER") {
    Ok(issuer) -> option.Some(issuer)
    Error(_) -> option.None
  }

  let git_repos_root = case env.get_string("GIT_REPOS_ROOT") {
    Ok(root) -> root
    Error(_) -> "./data/repos"
  }

  let git_host = case env.get_string("GLEAMHUB_GIT_HOST") {
    Ok(host) -> host
    Error(_) -> "localhost"
  }

  let port = case env.get_int("PORT") {
    Ok(port) -> port
    Error(_) -> 9999
  }

  let pool_name = process.new_name(app_name)
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
      user_id: option.None,
      clerk: clerk_api.client_from_env(),
      internal_api_token: internal_api_token,
      clerk_issuer: clerk_issuer,
    )

  let handler = router.handle_request(_, ctx)

  let web =
    wisp_mist.handler(handler, secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(port)
    |> mist.supervised()

  let assert Ok(_) =
    supervisor.new(supervisor.RestForOne)
    |> supervisor.add(db)
    |> supervisor.add(web)
    |> supervisor.start

  process.sleep_forever()
}

fn static_directory() {
  case env.get_string("STATIC_DIRECTORY") {
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
