import app/database
import app/json_api
import app/org_access
import app/pipeline_events
import app/web.{type Context, cors}
import cors_builder
import gleam/bytes_tree
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response as http_response
import gleam/json
import gleam/option
import gleam/otp/actor
import gleam/string_tree
import mist.{type Connection, type ResponseData}
import wisp

fn user_id(ctx: Context) -> String {
  let assert option.Some(id) = ctx.user_id
  id
}

fn terminal_state(state: String) -> Bool {
  state == "success" || state == "failure" || state == "skipped"
}

fn pipeline_state_decoder() {
  use state <- decode.field("state", decode.string)
  decode.success(state)
}

fn pipeline_state_from_payload(payload: String) -> option.Option(String) {
  case json.parse(payload, pipeline_state_decoder()) {
    Ok(state) -> option.Some(state)
    Error(_) -> option.None
  }
}

pub fn serve(
  mist_req: Request(Connection),
  wisp_req: wisp.Request,
  ctx: Context,
  org_slug: String,
  repo_name: String,
  number: Int,
) -> http_response.Response(ResponseData) {
  case wisp_req.method {
    http.Get ->
      case org_access.require_member(ctx, user_id(ctx), org_slug) {
        Error(_) -> error_response(mist_req, 403)
        Ok(_) ->
          case database.get_merge_request(ctx.repo(), org_slug, repo_name, number) {
            Ok(option.None) -> error_response(mist_req, 404)
            Error(_) -> error_response(mist_req, 500)
            Ok(option.Some(mr)) -> start_stream(mist_req, ctx, mr)
          }
      }
    _ -> error_response(mist_req, 405)
  }
}

fn request_origin(mist_req: Request(Connection)) -> String {
  case request.get_header(mist_req, "origin") {
    Ok(origin) -> origin
    Error(_) -> ""
  }
}

/// Mist `server_sent_events` writes `initial_response` headers to the socket
/// immediately; CORS must be on that response, not only on middleware afterward.
fn with_cors(
  mist_req: Request(Connection),
  response: http_response.Response(ResponseData),
) -> http_response.Response(ResponseData) {
  cors_builder.set_cors_multiple_origin(response, cors(), request_origin(mist_req))
}

fn error_response(
  mist_req: Request(Connection),
  status: Int,
) -> http_response.Response(ResponseData) {
  http_response.new(status)
  |> http_response.set_body(mist.Bytes(bytes_tree.new()))
  |> with_cors(mist_req, _)
}

fn start_stream(
  mist_req: Request(Connection),
  ctx: Context,
  mr: database.MergeRequestRow,
) -> http_response.Response(ResponseData) {
  let initial =
    http_response.new(200)
    |> http_response.set_body(mist.Bytes(bytes_tree.new()))
    |> with_cors(mist_req, _)

  mist.server_sent_events(
    mist_req,
    initial,
    init: fn(self) {
      pipeline_events.subscribe(ctx.pipeline_events_name, mr.id, self)
      case database.get_latest_pipeline_run_optional(ctx.repo(), mr.id) {
        Ok(option.Some(run)) -> {
          let payload = json.to_string(json_api.pipeline_run_json(run))
          process.send(self, payload)
          Ok(actor.initialised(StreamState(
            events_name: ctx.pipeline_events_name,
            merge_request_id: mr.id,
            subscriber: self,
          )))
        }
        Ok(option.None) ->
          Ok(actor.initialised(StreamState(
            events_name: ctx.pipeline_events_name,
            merge_request_id: mr.id,
            subscriber: self,
          )))
        Error(_) -> Error("database error")
      }
    },
    loop: fn(state, payload, conn) {
      let event =
        mist.event(string_tree.from_string(payload))
        |> mist.event_name("pipeline")
      let _ = mist.send_event(conn, event)
      case pipeline_state_from_payload(payload) {
        option.Some(pipeline_state) ->
          case terminal_state(pipeline_state) {
            True -> {
              pipeline_events.unsubscribe(
                state.events_name,
                state.merge_request_id,
                state.subscriber,
              )
              actor.stop()
            }
            False -> actor.continue(state)
          }
        option.None -> actor.continue(state)
      }
    },
  )
}

type StreamState {
  StreamState(
    events_name: process.Name(pipeline_events.Message),
    merge_request_id: String,
    subscriber: process.Subject(String),
  )
}
