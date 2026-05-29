import app/clerk_api.{
  type ClerkEmail, type ClerkUser, ClerkEmail, ClerkUser, display_name,
}
import gleam/option
import gleeunit

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
    display_name(user(
      option.None,
      option.None,
      option.None,
      [],
      option.None,
    ))
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
