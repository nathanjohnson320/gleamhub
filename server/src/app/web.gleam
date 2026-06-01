import app/clerk_api.{type Client}
import app/pipeline_events
import cors_builder as cors
import gleam/erlang/process
import gleam/bool
import gleam/http
import gleam/list
import gleam/option
import gleam/string
import pog
import wisp
import ywt/verify_key.{type VerifyKey}

fn cors() {
  cors.new()
  |> cors.allow_origin("http://localhost:5173")
  |> cors.allow_origin("http://127.0.0.1:5173")
  |> cors.allow_origin("http://localhost:9999")
  |> cors.allow_origin("http://127.0.0.1:9999")
  |> cors.allow_header("Content-Type")
  |> cors.allow_header("Authorization")
  |> cors.allow_method(http.Get)
  |> cors.allow_method(http.Post)
  |> cors.allow_method(http.Put)
  |> cors.allow_method(http.Patch)
  |> cors.allow_method(http.Delete)
}

pub type Context {
  Context(
    clerk_keys: List(VerifyKey),
    static_directory: String,
    repo: fn() -> pog.Connection,
    git_repos_root: String,
    git_host: String,
    user_id: option.Option(String),
    clerk: option.Option(Client),
    internal_api_token: String,
    clerk_issuer: option.Option(String),
    pipeline_events_name: process.Name(pipeline_events.Message),
  )
}

pub fn middleware(
  req: wisp.Request,
  ctx: Context,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use req <- cors.wisp_middleware(req, cors())
  use <- wisp.serve_static(req, under: "/static", from: ctx.static_directory)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  use <- default_responses

  handle_request(req)
}

fn response_is_json(response: wisp.Response) -> Bool {
  list.any(response.headers, fn(header) {
    let #(name, value) = header
    name == "content-type" && string.contains(value, "application/json")
  })
}

fn response_has_body(response: wisp.Response) -> Bool {
  case response.body {
    wisp.Text("") -> False
    wisp.Text(_) -> True
    wisp.Bytes(_) -> True
    wisp.File(_, _, _) -> True
  }
}

pub fn default_responses(handle_request: fn() -> wisp.Response) -> wisp.Response {
  let response = handle_request()

  use <- bool.guard(
    when: response_is_json(response) || response_has_body(response),
    return: response,
  )

  case response.status {
    404 | 405 ->
      "<h1>Not Found</h1>"
      |> wisp.html_body(response, _)

    400 | 422 ->
      "<h1>Bad request</h1>"
      |> wisp.html_body(response, _)

    413 ->
      "<h1>Request entity too large</h1>"
      |> wisp.html_body(response, _)

    500 ->
      "<h1>Internal server error</h1>"
      |> wisp.html_body(response, _)

    _ -> response
  }
}
