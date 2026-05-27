import app/web
import gleam/dynamic/decode
import gleam/http/request
import gleam/option
import wisp.{type Request, type Response}
import ywt

fn decoder() {
  use id <- decode.field("sub", decode.string)
  decode.success(id)
}

/// Middleware for authenticating requests coming from clerk (estonian).
pub fn middleware(
  req: Request,
  ctx: web.Context,
  handle_request: fn(web.Context) -> Response,
) -> Response {
  case request.get_header(req, "authorization") {
    Ok("Bearer " <> token) -> {
      let decoded =
        ywt.decode(token, using: decoder(), claims: [], keys: [ctx.clerk_key])
      case decoded {
        Ok(user_id) -> {
          let ctx =
            web.Context(..ctx, user_id: option.Some(user_id))
          handle_request(ctx)
        }
        Error(_) -> wisp.response(401)
      }
    }
    _ -> wisp.response(401)
  }
}
