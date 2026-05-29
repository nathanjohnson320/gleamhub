import dot_env/env
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/json
import gleam/result
import gleam/uri
import ywt/verify_key.{type VerifyKey}

pub type Error {
  MissingUrl
  BadUrl
  RequestFailed(httpc.HttpError)
  BadStatus(Int)
  InvalidResponse
  EmptyKeySet
}

pub fn load_from_env() -> Result(List(VerifyKey), Error) {
  case env.get_string("CLERK_JWKS_URL") {
    Ok(url) -> fetch_keys(url)
    Error(_) -> Error(MissingUrl)
  }
}

pub fn fetch_keys(url: String) -> Result(List(VerifyKey), Error) {
  use target <- result.try(parse_url(url))
  use response <- result.try(send_get(target))
  case response.status {
    200 -> decode_keys(response.body)
    status -> Error(BadStatus(status))
  }
}

fn parse_url(url: String) -> Result(uri.Uri, Error) {
  uri.parse(url)
  |> result.map_error(fn(_) { BadUrl })
}

fn send_get(target: uri.Uri) -> Result(response.Response(String), Error) {
  use req <- result.try(
    request.from_uri(target)
    |> result.map_error(fn(_) { BadUrl }),
  )
  let req = request.set_header(req, "accept", "application/json")

  httpc.send(req)
  |> result.map_error(RequestFailed)
}

fn decode_keys(body: String) -> Result(List(VerifyKey), Error) {
  case json.parse(body, verify_key.set_decoder()) {
    Ok(keys) ->
      case keys {
        [] -> Error(EmptyKeySet)
        _ -> Ok(keys)
      }
    Error(_) -> Error(InvalidResponse)
  }
}

/// Decode a JWKS document (for tests).
pub fn decode_jwks(body: String) -> Result(List(VerifyKey), Error) {
  decode_keys(body)
}
