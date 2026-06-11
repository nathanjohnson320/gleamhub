import gleam/dynamic/decode
import gleam/json

pub fn encode_user_ids(user_ids: List(String)) -> json.Json {
  json.array(user_ids, of: json.string)
}

pub fn decode_user_ids(json_text: String) -> List(String) {
  case json.parse(json_text, decode.list(decode.string)) {
    Ok(ids) -> ids
    Error(_) -> []
  }
}

pub fn empty_json() -> json.Json {
  encode_user_ids([])
}
