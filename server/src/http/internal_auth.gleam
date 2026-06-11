import gleam/http/request
import http/web.{type Context}
import wisp.{type Request, type Response}

/// Shared secret for `/internal/*` routes used by git-ssh and hooks.
pub fn with_token(
  req: Request,
  ctx: Context,
  handler: fn() -> Response,
) -> Response {
  case request.get_header(req, "x-gleamhub-internal-token") {
    Ok(token) if token == ctx.internal_api_token -> handler()
    _ -> wisp.response(401)
  }
}
