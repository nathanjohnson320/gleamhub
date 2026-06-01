import app/clerk_api.{type Client}
import app/router
import app/web
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/option
import gleam/string
import gleam/time/duration
import pog
import wisp
import wisp/simulate
import ywt
import ywt/algorithm
import ywt/claim
import ywt/sign_key.{type SignKey}
import ywt/verify_key.{type VerifyKey}
import youid/uuid

const static_directory = "priv/static"

const internal_api_token = "test-internal-token"

pub fn repos_root() -> String {
  "/tmp/gleamhub_route_" <> uuid.to_string(uuid.v7())
}

fn context(
  db: pog.Connection,
  git_repos_root: String,
  verify: VerifyKey,
  clerk: option.Option(Client),
) -> web.Context {
  web.Context(
    clerk_keys: [verify],
    static_directory:,
    repo: fn() { db },
    git_repos_root:,
    git_host: "git.test.local",
    user_id: option.None,
    clerk:,
    internal_api_token:,
    clerk_issuer: option.None,
  )
}

pub fn authenticated(
  db: pog.Connection,
  git_repos_root: String,
) -> #(web.Context, SignKey) {
  let sign = ywt.generate_key(algorithm.rs256)
  let verify = verify_key.derived(sign)
  #(context(db, git_repos_root, verify, option.None), sign)
}

pub fn authenticated_with_clerk(
  db: pog.Connection,
  git_repos_root: String,
  clerk: Client,
) -> #(web.Context, SignKey) {
  let sign = ywt.generate_key(algorithm.rs256)
  let verify = verify_key.derived(sign)
  #(context(db, git_repos_root, verify, option.Some(clerk)), sign)
}

pub fn bearer_token(sign: SignKey, user_id: String) -> String {
  ywt.encode(
    payload: [#("sub", json.string(user_id))],
    claims: [
      claim.expires_at(max_age: duration.hours(1), leeway: duration.minutes(5)),
    ],
    key: sign,
  )
}

pub fn internal_get(path: String) -> wisp.Request {
  simulate.request(http.Get, path)
  |> simulate.header("x-gleamhub-internal-token", internal_api_token)
}

pub fn internal_post(path: String) -> wisp.Request {
  simulate.request(http.Post, path)
  |> simulate.header("x-gleamhub-internal-token", internal_api_token)
}

pub fn internal_patch(path: String, body: json.Json) -> wisp.Request {
  simulate.request(http.Patch, path)
  |> simulate.header("x-gleamhub-internal-token", internal_api_token)
  |> simulate.json_body(body)
}

/// Claim and mark success on the next queued CI job (for integration tests).
pub fn complete_next_pipeline(ctx: web.Context) -> Nil {
  let next = dispatch(internal_get("/internal/ci/jobs/next"), ctx)
  case status(next) {
    200 -> {
      case json.parse(body(next), decode.at(["id"], decode.string)) {
        Ok(run_id) -> {
          let _ =
            dispatch(
              internal_patch(
                "/internal/ci/jobs/" <> run_id,
                json.object([
                  #("state", json.string("success")),
                  #("log", json.string("ok\n")),
                ]),
              ),
              ctx,
            )
          Nil
        }
        Error(_) -> Nil
      }
    }
    _ -> Nil
  }
}

pub fn get(path: String, token: option.Option(String)) -> wisp.Request {
  let req = simulate.request(http.Get, path)
  case token {
    option.Some(t) ->
      simulate.header(req, "authorization", "Bearer " <> t)
    option.None -> req
  }
}

pub fn post_json(
  path: String,
  token: String,
  body: json.Json,
) -> wisp.Request {
  simulate.request(http.Post, path)
  |> simulate.header("authorization", "Bearer " <> token)
  |> simulate.json_body(body)
}

pub fn put_json(path: String, token: String, body: json.Json) -> wisp.Request {
  simulate.request(http.Put, path)
  |> simulate.header("authorization", "Bearer " <> token)
  |> simulate.json_body(body)
}

pub fn delete(path: String, token: String) -> wisp.Request {
  simulate.request(http.Delete, path)
  |> simulate.header("authorization", "Bearer " <> token)
}

pub fn options(path: String, origin: String) -> wisp.Request {
  simulate.request(http.Options, path)
  |> simulate.header("origin", origin)
  |> simulate.header("access-control-request-method", "GET")
}

pub fn dispatch(req: wisp.Request, ctx: web.Context) -> wisp.Response {
  router.handle_request(req, ctx)
}

pub fn status(response: wisp.Response) -> Int {
  response.status
}

pub fn body(response: wisp.Response) -> String {
  simulate.read_body(response)
}

pub fn contains(response: wisp.Response, text: String) -> Bool {
  string.contains(body(response), text)
}

@external(erlang, "git_exec_test_ffi", "clone_fixture_to_bare")
fn clone_fixture_to_bare_ffi(root: String, disk_path: String) -> String

@external(erlang, "git_exec_test_ffi", "cleanup_fixture_repo")
pub fn cleanup_fixture_repo(path: String) -> Nil

/// Clone the shared git fixture into a bare repo under `root/disk_path`.
/// Returns the temporary worktree path to pass to `cleanup_fixture_repo`.
pub fn clone_git_fixture(root: String, disk_path: String) -> String {
  clone_fixture_to_bare_ffi(root, disk_path)
}

pub fn cleanup_repos_root(root: String) -> Nil {
  cleanup_fixture_repo(root)
}

@external(erlang, "git_exec_test_ffi", "rev_parse")
pub fn rev_parse(git_dir: String, git_ref: String) -> String
