import database
import envie
import gleam/option
import gleeunit
import http/clerk_api.{
  type ClerkEmail, type ClerkUser, ClerkEmail, ClerkUser, Client,
  client_from_env, decode_clerk_users, display_name, hydrate_comments, username,
}

pub fn main() {
  gleeunit.main()
}

fn user(
  first: option.Option(String),
  last: option.Option(String),
  username: option.Option(String),
  emails: List(ClerkEmail),
  primary_id: option.Option(String),
) -> ClerkUser {
  ClerkUser(
    id: "user_1",
    first_name: first,
    last_name: last,
    username: username,
    primary_email_address_id: primary_id,
    email_addresses: emails,
  )
}

pub fn display_name_from_full_name_test() {
  let assert "Ada Lovelace" =
    display_name(user(
      option.Some("Ada"),
      option.Some("Lovelace"),
      option.None,
      [],
      option.None,
    ))
}

pub fn display_name_prefers_username_over_full_name_test() {
  let assert "ada" =
    display_name(user(
      option.Some("Ada"),
      option.Some("Lovelace"),
      option.Some("ada"),
      [],
      option.None,
    ))
}

pub fn display_name_from_username_test() {
  let assert "ada" =
    display_name(user(
      option.None,
      option.None,
      option.Some("ada"),
      [],
      option.None,
    ))
}

pub fn display_name_from_primary_email_test() {
  let emails = [ClerkEmail(id: "em_1", email_address: "ada@example.com")]
  let assert "ada@example.com" =
    display_name(user(
      option.None,
      option.None,
      option.None,
      emails,
      option.Some("em_1"),
    ))
}

pub fn display_name_falls_back_to_user_id_test() {
  let assert "user_1" =
    display_name(user(option.None, option.None, option.None, [], option.None))
}

pub fn display_name_first_only_test() {
  let assert "Ada" =
    display_name(user(
      option.Some("Ada"),
      option.None,
      option.None,
      [],
      option.None,
    ))
}

pub fn display_name_last_only_test() {
  let assert "Lovelace" =
    display_name(user(
      option.None,
      option.Some("Lovelace"),
      option.None,
      [],
      option.None,
    ))
}

pub fn display_name_whitespace_name_ignored_test() {
  let assert "user_1" =
    display_name(user(
      option.Some("  "),
      option.Some("  "),
      option.None,
      [],
      option.None,
    ))
}

pub fn hydrate_comments_empty_test() {
  let client = Client(secret_key: "sk_test")
  let assert [] = hydrate_comments(client, [])
}

pub fn hydrate_comments_keeps_rows_on_lookup_failure_test() {
  let client = Client(secret_key: "sk_test_invalid")
  let comments = [
    database.MergeRequestCommentRow(
      id: "c1",
      author_user_id: "user_unknown",
      author_name: "",
      body: "note",
      file_path: option.None,
      line: option.None,
      mentioned_user_ids: [],
      created_at: "1",
      updated_at: "1",
    ),
  ]
  let result = hydrate_comments(client, comments)
  let assert [comment] = result
  let assert "note" = comment.body
}

pub fn client_from_env_reads_secret_test() {
  let _ = envie.set("CLERK_SECRET_KEY", "sk_test_key")
  let assert option.Some(client) = client_from_env()
  let assert "sk_test_key" = client.secret_key
}

pub fn client_from_env_empty_is_none_test() {
  let _ = envie.set("CLERK_SECRET_KEY", "   ")
  let assert option.None = client_from_env()
}

pub fn decode_clerk_users_list_response_test() {
  let body =
    "[{\"id\":\"user_1\",\"first_name\":\"Ada\",\"last_name\":\"Lovelace\",\"username\":null,\"primary_email_address_id\":null,\"email_addresses\":[]}]"
  let assert Ok([user]) = decode_clerk_users(body)
  let assert "Ada Lovelace" = display_name(user)
}

pub fn decode_clerk_users_wrapped_response_test() {
  let body =
    "{\"data\":[{\"id\":\"user_2\",\"first_name\":null,\"last_name\":null,\"username\":\"ada\",\"primary_email_address_id\":null,\"email_addresses\":[]}]}"
  let assert Ok([user]) = decode_clerk_users(body)
  let assert "ada" = display_name(user)
}

pub fn username_from_user_test() {
  let assert option.Some("ada") =
    username(user(option.None, option.None, option.Some("ada"), [], option.None))
}

pub fn decode_clerk_search_response_test() {
  let body =
    "[{\"id\":\"user_search_1\",\"object\":\"user\",\"username\":\"ada_lovelace\",\"first_name\":\"Ada\",\"last_name\":\"Lovelace\",\"primary_email_address_id\":\"idn_search_1\",\"email_addresses\":[{\"id\":\"idn_search_1\",\"object\":\"email_address\",\"email_address\":\"ada@example.com\",\"verification\":{\"object\":\"verification_from_oauth\",\"status\":\"verified\"}}]}]"
  let assert Ok([found]) = decode_clerk_users(body)
  let assert "ada_lovelace" = display_name(found)
}

pub fn decode_clerk_empty_search_response_test() {
  let assert Ok([]) = decode_clerk_users("[]")
}

pub fn decode_clerk_paginated_empty_search_response_test() {
  let assert Ok([]) = decode_clerk_users("{\"data\":null,\"total_count\":0}")
}

pub fn decode_clerk_user_without_email_addresses_test() {
  let body =
    "[{\"id\":\"user_1\",\"first_name\":\"Ada\",\"last_name\":null,\"username\":\"ada\",\"primary_email_address_id\":null}]"
  let assert Ok([user]) = decode_clerk_users(body)
  let assert "ada" = display_name(user)
}
