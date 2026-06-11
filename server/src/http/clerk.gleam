import database
import gleam/dynamic/decode
import gleam/http/request
import gleam/list
import gleam/option
import gleam/time/duration
import http/web
import wisp.{type Request, type Response}
import ywt
import ywt/claim

fn decoder() {
  use id <- decode.field("sub", decode.string)
  decode.success(id)
}

fn auth_claims(ctx: web.Context) -> List(claim.Claim) {
  let exp =
    claim.expires_at(max_age: duration.hours(1), leeway: duration.minutes(5))
  case ctx.clerk_issuer {
    option.Some(issuer) -> [exp, claim.issuer(issuer, [])]
    option.None -> [exp]
  }
}

fn bearer_token(req: Request) -> option.Option(String) {
  case request.get_header(req, "authorization") {
    Ok("Bearer " <> token) -> option.Some(token)
    _ -> option.None
  }
}

fn verify_token(
  token: String,
  ctx: web.Context,
) -> Result(web.Context, Response) {
  let decoded =
    ywt.decode(
      token,
      using: decoder(),
      claims: auth_claims(ctx),
      keys: ctx.clerk_keys,
    )
  case decoded {
    Ok(user_id) -> {
      case
        database.upsert_session_user(
          ctx.repo(),
          user_id,
          option.None,
          option.None,
        )
      {
        Ok(_) -> Ok(web.Context(..ctx, user_id: option.Some(user_id)))
        Error(_) -> Error(wisp.internal_server_error())
      }
    }
    Error(_) -> Error(wisp.response(401))
  }
}

fn query_token(req: Request) -> option.Option(String) {
  case list.find(wisp.get_query(req), fn(pair) { pair.0 == "token" }) {
    Ok(#(_, value)) ->
      case value {
        "" -> option.None
        token -> option.Some(token)
      }
    Error(_) -> option.None
  }
}

pub fn authenticated(
  req: Request,
  ctx: web.Context,
) -> Result(web.Context, Response) {
  case bearer_token(req) {
    option.Some(token) -> verify_token(token, ctx)
    option.None -> Error(wisp.response(401))
  }
}

/// Bearer header or `?token=` for browser navigations (e.g. raw file in a new tab).
pub fn authenticated_allow_query(
  req: Request,
  ctx: web.Context,
) -> Result(web.Context, Response) {
  case bearer_token(req) {
    option.Some(token) -> verify_token(token, ctx)
    option.None ->
      case query_token(req) {
        option.Some(token) -> verify_token(token, ctx)
        option.None -> Error(wisp.response(401))
      }
  }
}

pub fn middleware(
  req: Request,
  ctx: web.Context,
  handle_request: fn(web.Context) -> Response,
) -> Response {
  case authenticated(req, ctx) {
    Ok(ctx) -> handle_request(ctx)
    Error(resp) -> resp
  }
}

pub fn middleware_allow_query(
  req: Request,
  ctx: web.Context,
  handle_request: fn(web.Context) -> Response,
) -> Response {
  case authenticated_allow_query(req, ctx) {
    Ok(ctx) -> handle_request(ctx)
    Error(resp) -> resp
  }
}
