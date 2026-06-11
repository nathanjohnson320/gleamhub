import ci/stream_routes as pipeline_stream_routes
import cors_builder
import exception
import gleam/bytes_tree
import gleam/http/request.{type Request as HttpRequest}
import gleam/http/response as http_response
import gleam/int
import gleam/option
import gleam/result
import gleam/string
import http/clerk
import http/web.{type Context, cors}
import mist.{type Connection, type ResponseData}
import wisp
import wisp/internal

fn pipeline_stream_target(
  segments: List(String),
) -> option.Option(#(String, String, Int)) {
  case segments {
    [
      "api",
      "orgs",
      org,
      "repos",
      repo,
      "merge-requests",
      num_str,
      "pipeline",
      "stream",
    ] ->
      case int.parse(num_str) {
        Ok(num) -> option.Some(#(org, repo, num))
        Error(_) -> option.None
      }
    _ -> option.None
  }
}

pub fn handler(
  handle_request: fn(wisp.Request, Context) -> wisp.Response,
  secret_key_base: String,
  ctx: Context,
) -> fn(HttpRequest(Connection)) -> http_response.Response(ResponseData) {
  fn(request: HttpRequest(_)) {
    let connection =
      internal.make_connection(mist_body_reader(request), secret_key_base)
    let wisp_req = request.set_body(request, connection)

    use <- exception.defer(fn() {
      let assert Ok(_) = wisp.delete_temporary_files(wisp_req)
    })

    case pipeline_stream_target(wisp.path_segments(wisp_req)) {
      option.Some(#(org, repo, num)) ->
        cors_builder.mist_middleware(request, cors(), fn(_) {
          case clerk.authenticated(wisp_req, ctx) {
            Error(resp) -> mist_response(resp)
            Ok(auth_ctx) ->
              pipeline_stream_routes.serve(
                request,
                wisp_req,
                auth_ctx,
                org,
                repo,
                num,
              )
          }
        })
      option.None ->
        handle_request(wisp_req, ctx)
        |> mist_response
    }
  }
}

fn mist_body_reader(request: HttpRequest(Connection)) -> internal.Reader {
  case mist.stream(request) {
    Error(_) -> fn(_) { Ok(internal.ReadingFinished) }
    Ok(stream) -> fn(size) { wrap_mist_chunk(stream(size)) }
  }
}

fn wrap_mist_chunk(
  chunk: Result(mist.Chunk, mist.ReadError),
) -> Result(internal.Read, Nil) {
  chunk
  |> result.replace_error(Nil)
  |> result.map(fn(chunk) {
    case chunk {
      mist.Done -> internal.ReadingFinished
      mist.Chunk(data, consume) ->
        internal.Chunk(data, fn(size) { wrap_mist_chunk(consume(size)) })
    }
  })
}

fn mist_response(
  wisp_resp: wisp.Response,
) -> http_response.Response(ResponseData) {
  let body = case wisp_resp.body {
    wisp.Text(text) -> mist.Bytes(bytes_tree.from_string(text))
    wisp.Bytes(bytes) -> mist.Bytes(bytes)
    wisp.File(path:, offset:, limit:) -> mist_send_file(path, offset, limit)
  }
  wisp_resp
  |> http_response.set_body(body)
}

fn mist_send_file(
  path: String,
  offset: Int,
  limit: option.Option(Int),
) -> mist.ResponseData {
  case mist.send_file(path, offset:, limit:) {
    Ok(body) -> body
    Error(error) -> {
      wisp.log_error(string.inspect(error))
      mist.Bytes(bytes_tree.new())
    }
  }
}
