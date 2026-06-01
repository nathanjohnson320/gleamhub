import app/database
import app/web
import gleam/dynamic/decode
import gleam/http/request
import gleam/option
import gleam/time/duration
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

pub fn authenticated(
  req: Request,
  ctx: web.Context,
) -> Result(web.Context, Response) {
  case request.get_header(req, "authorization") {
    Ok("Bearer " <> token) -> {
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
            Ok(_) ->
              Ok(web.Context(..ctx, user_id: option.Some(user_id)))
            Error(_) -> Error(wisp.internal_server_error())
          }
        }
        Error(_) -> Error(wisp.response(401))
      }
    }
    _ -> Error(wisp.response(401))
  }
}

/// Middleware for authenticating requests coming from clerk (estonian).
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
