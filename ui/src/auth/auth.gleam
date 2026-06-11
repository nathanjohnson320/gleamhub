import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import gleam/string

pub type User {
  User(
    id: String,
    username: Option(String),
    full_name: Option(String),
    first_name: Option(String),
    last_name: Option(String),
    email: Option(String),
    image_url: Option(String),
    initials: String,
    token: String,
  )
}

pub fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.string)
  use username <- decode.field("username", decode.optional(decode.string))
  use full_name <- decode.field("fullName", decode.optional(decode.string))
  use first_name <- decode.field("firstName", decode.optional(decode.string))
  use last_name <- decode.field("lastName", decode.optional(decode.string))
  use email <- decode.field("email", decode.optional(decode.string))
  use image_url <- decode.field("imageUrl", decode.optional(decode.string))
  use initials <- decode.field("initials", decode.string)
  use token <- decode.field("token", decode.string)
  decode.success(User(
    id:,
    username:,
    full_name:,
    first_name:,
    last_name:,
    email:,
    image_url:,
    initials:,
    token:,
  ))
}

pub fn user_from_json(user_json: String) -> Option(User) {
  case json.parse(from: user_json, using: decode.optional(user_decoder())) {
    Ok(maybe) -> maybe
    Error(_) -> option.None
  }
}

pub fn display_name(user: User) -> String {
  case user.username {
    option.Some(username) ->
      case string.trim(username) {
        "" -> display_name_without_username(user)
        trimmed -> trimmed
      }
    option.None -> display_name_without_username(user)
  }
}

fn display_name_without_username(user: User) -> String {
  case user.full_name {
    option.Some(n) -> n
    option.None ->
      case user.first_name, user.last_name {
        option.Some(a), option.Some(b) -> string.trim(a <> " " <> b)
        option.Some(a), option.None -> a
        option.None, option.Some(b) -> b
        option.None, option.None ->
          case user.email {
            option.Some(e) -> e
            option.None -> "Signed-in user"
          }
      }
  }
}
