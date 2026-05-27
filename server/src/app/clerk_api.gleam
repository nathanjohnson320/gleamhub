import app/database.{
  type MergeRequestCommentRow, comment_with_author_name,
}
import dot_env/env
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri

pub type Client {
  Client(secret_key: String)
}

pub type ClerkError {
  MissingSecretKey
  BadUrl
  RequestFailed(httpc.HttpError)
  BadStatus(Int)
  InvalidResponse
}

pub type ClerkUser {
  ClerkUser(
    id: String,
    first_name: option.Option(String),
    last_name: option.Option(String),
    username: option.Option(String),
    primary_email_address_id: option.Option(String),
    email_addresses: List(ClerkEmail),
  )
}

pub type ClerkEmail {
  ClerkEmail(id: String, email_address: String)
}

pub fn client_from_env() -> option.Option(Client) {
  case env.get_string("CLERK_SECRET_KEY") {
    Ok(key) ->
      case string.trim(key) {
        "" -> option.None
        trimmed -> option.Some(Client(secret_key: trimmed))
      }
    Error(_) -> option.None
  }
}

pub fn hydrate_comments(
  client: Client,
  comments: List(MergeRequestCommentRow),
) -> List(MergeRequestCommentRow) {
  let author_ids =
    comments
    |> list.map(fn(comment) { comment.author_user_id })
    |> list.unique

  case lookup_display_names(client, author_ids) {
    Ok(names) ->
      list.map(comments, fn(comment) {
        let author_name = case dict.get(names, comment.author_user_id) {
          Ok(name) -> name
          Error(_) -> comment.author_user_id
        }
        comment_with_author_name(comment, author_name)
      })
    Error(_) -> comments
  }
}

pub fn profile_for_user(
  client: Client,
  user_id: String,
) -> Result(#(option.Option(String), option.Option(String)), ClerkError) {
  case fetch_users(client, [user_id]) {
    Ok(users) ->
      case list.first(users) {
        Ok(user) ->
          Ok(#(option.Some(display_name(user)), primary_email(user)))
        Error(_) -> Ok(#(option.None, option.None))
      }
    Error(err) -> Error(err)
  }
}

fn lookup_display_names(
  client: Client,
  user_ids: List(String),
) -> Result(Dict(String, String), ClerkError) {
  case user_ids {
    [] -> Ok(dict.new())
    ids ->
      fetch_users(client, ids)
      |> result.map(fn(users) {
        list.fold(users, dict.new(), fn(names, user) {
          dict.insert(names, user.id, display_name(user))
        })
      })
  }
}

fn fetch_users(
  client: Client,
  user_ids: List(String),
) -> Result(List(ClerkUser), ClerkError) {
  use response <- result.try(send_get(client, users_list_uri(user_ids)))
  case response.status {
    200 -> decode_users(response.body)
    status -> Error(BadStatus(status))
  }
}

fn send_get(
  client: Client,
  target: uri.Uri,
) -> Result(response.Response(String), ClerkError) {
  use req <- result.try(
    request.from_uri(target)
    |> result.map_error(fn(_) { BadUrl }),
  )
  let req =
    req
    |> request.set_header("authorization", "Bearer " <> client.secret_key)
    |> request.set_header("accept", "application/json")

  httpc.send(req)
  |> result.map_error(RequestFailed)
}

fn users_list_uri(user_ids: List(String)) -> uri.Uri {
  let user_params = list.map(user_ids, fn(user_id) { #("user_id[]", user_id) })
  let query_pairs = list.append(user_params, [#("limit", "500")])
  uri.Uri(
    scheme: option.Some("https"),
    userinfo: option.None,
    host: option.Some("api.clerk.com"),
    port: option.None,
    path: "/v1/users",
    query: option.Some(uri.query_to_string(query_pairs)),
    fragment: option.None,
  )
}

fn decode_users(body: String) -> Result(List(ClerkUser), ClerkError) {
  case json.parse(body, decode.list(user_decoder())) {
    Ok(users) -> Ok(users)
    Error(_) ->
      json.parse(body, decode.at(["data"], decode.list(user_decoder())))
      |> result.map_error(fn(_) { InvalidResponse })
  }
}

fn user_decoder() -> decode.Decoder(ClerkUser) {
  use id <- decode.field("id", decode.string)
  use first_name <- decode.field("first_name", decode.optional(decode.string))
  use last_name <- decode.field("last_name", decode.optional(decode.string))
  use username <- decode.field("username", decode.optional(decode.string))
  use primary_email_address_id <- decode.field(
    "primary_email_address_id",
    decode.optional(decode.string),
  )
  use email_addresses <- decode.field(
    "email_addresses",
    decode.list(email_decoder()),
  )
  decode.success(ClerkUser(
    id:,
    first_name:,
    last_name:,
    username:,
    primary_email_address_id:,
    email_addresses:,
  ))
}

fn email_decoder() -> decode.Decoder(ClerkEmail) {
  use id <- decode.field("id", decode.string)
  use email_address <- decode.field("email_address", decode.string)
  decode.success(ClerkEmail(id:, email_address:))
}

pub fn display_name(user: ClerkUser) -> String {
  let from_name = full_name(user.first_name, user.last_name)
  case from_name {
    option.Some(name) -> name
    option.None ->
      case user.username {
        option.Some(username) -> username
        option.None ->
          primary_email(user)
          |> option.unwrap(user.id)
      }
  }
}

fn full_name(
  first_name: option.Option(String),
  last_name: option.Option(String),
) -> option.Option(String) {
  case first_name, last_name {
    option.Some(first), option.Some(last) -> {
      let name = string.trim(first <> " " <> last)
      case name {
        "" -> option.None
        trimmed -> option.Some(trimmed)
      }
    }
    option.Some(first), option.None -> option.Some(first)
    option.None, option.Some(last) -> option.Some(last)
    option.None, option.None -> option.None
  }
}

fn primary_email(user: ClerkUser) -> option.Option(String) {
  case user.primary_email_address_id {
    option.Some(primary_id) -> find_email(user.email_addresses, primary_id)
    option.None -> first_email(user.email_addresses)
  }
}

fn find_email(emails: List(ClerkEmail), primary_id: String) -> option.Option(String) {
  case list.find(emails, fn(email) { email.id == primary_id }) {
    Ok(email) -> option.Some(email.email_address)
    Error(_) -> option.None
  }
}

fn first_email(emails: List(ClerkEmail)) -> option.Option(String) {
  case emails {
    [first, ..] -> option.Some(first.email_address)
    [] -> option.None
  }
}
