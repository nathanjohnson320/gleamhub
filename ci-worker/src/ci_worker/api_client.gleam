import ci_worker/config.{type Config}
import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/int
import gleam/json
import gleam/option
import gleam/result
import gleam/string

pub type ApiError {
  HttpError(String)
  UnexpectedStatus(Int)
  BadUrl
}

pub type PatchResult {
  PatchOk
  PatchRejected
}

const max_log_bytes = 262_144

const patch_timeout_ms = 30_000

pub fn next_job(
  config: Config,
  timeout_secs: Int,
) -> Result(option.Option(String), ApiError) {
  let url =
    api_base(config.api_url)
    <> "/internal/ci/jobs/next?timeout="
    <> int.to_string(timeout_secs)

  use req <- result.try(build_get(config, url))
  use resp <- result.try(dispatch_safe(
    req,
    config.long_poll_http_timeout_ms(config),
  ))

  case resp.status {
    204 -> Ok(option.None)
    200 -> Ok(option.Some(resp.body))
    status -> Error(UnexpectedStatus(status))
  }
}

pub fn patch_job(
  config: Config,
  job_id: String,
  state: String,
  log: String,
) -> Result(PatchResult, ApiError) {
  let url = api_base(config.api_url) <> "/internal/ci/jobs/" <> job_id
  let body =
    json.object([
      #("state", json.string(state)),
      #("log", json.string(truncate_log(log))),
    ])
    |> json.to_string

  use req <- result.try(build_patch(config, url, body))
  use resp <- result.try(dispatch_safe(req, patch_timeout_ms))

  case resp.status {
    200 -> Ok(PatchOk)
    409 -> Ok(PatchRejected)
    status -> Error(UnexpectedStatus(status))
  }
}

fn build_get(
  config: Config,
  url: String,
) -> Result(request.Request(String), ApiError) {
  case request.to(url) {
    Ok(req) ->
      Ok(request.set_header(
        req,
        "x-gleamhub-internal-token",
        config.internal_token,
      ))
    Error(_) -> Error(BadUrl)
  }
}

fn build_patch(
  config: Config,
  url: String,
  body: String,
) -> Result(request.Request(String), ApiError) {
  case request.to(url) {
    Ok(req) ->
      Ok(
        req
        |> request.set_method(http.Patch)
        |> request.set_header(
          "x-gleamhub-internal-token",
          config.internal_token,
        )
        |> request.set_header("content-type", "application/json")
        |> request.set_body(body),
      )
    Error(_) -> Error(BadUrl)
  }
}

fn api_base(api_url: String) -> String {
  case string.ends_with(api_url, "/") {
    True -> string.drop_end(api_url, 1)
    False -> api_url
  }
}

fn truncate_log(text: String) -> String {
  let len = string.length(text)
  case len > max_log_bytes {
    True -> {
      let start = len - max_log_bytes
      "[log truncated to last 256KB]\n"
      <> string.slice(text, start, max_log_bytes)
    }
    False -> text
  }
}

@external(erlang, "ci_worker_http_ffi", "http_try")
fn http_try(
  run: fn() -> Result(a, httpc.HttpError),
) -> Result(Result(a, httpc.HttpError), String)

fn dispatch_safe(
  req: request.Request(String),
  timeout_ms: Int,
) -> Result(Response(String), ApiError) {
  case
    http_try(fn() {
      httpc.configure()
      |> httpc.timeout(timeout_ms)
      |> httpc.dispatch(req)
    })
  {
    Ok(Ok(resp)) -> Ok(resp)
    Ok(Error(err)) -> Error(http_error_message(err))
    Error(msg) -> Error(HttpError("http request failed: " <> msg))
  }
}

fn http_error_message(error: httpc.HttpError) -> ApiError {
  case error {
    httpc.InvalidUtf8Response -> HttpError("invalid utf-8 in response body")
    httpc.ResponseTimeout -> HttpError("response timeout")
    httpc.FailedToConnect(ip4:, ip6:) ->
      HttpError(
        "failed to connect (ipv4: "
        <> connect_error_message(ip4)
        <> ", ipv6: "
        <> connect_error_message(ip6)
        <> ")",
      )
  }
}

fn connect_error_message(error: httpc.ConnectError) -> String {
  case error {
    httpc.Posix(code:) -> code
    httpc.TlsAlert(code:, detail:) -> code <> ": " <> detail
  }
}
