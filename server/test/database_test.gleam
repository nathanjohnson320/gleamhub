import database
import gleam/option
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn display_name_from_email_test() {
  let assert option.Some("alice") =
    database.display_name_from_email(option.Some("alice@example.com"))
  let assert option.None = database.display_name_from_email(option.None)
  let assert option.Some("no-at") =
    database.display_name_from_email(option.Some("no-at"))
}

pub fn comment_with_author_name_test() {
  let comment =
    database.MergeRequestCommentRow(
      id: "c1",
      author_user_id: "u1",
      author_name: "",
      body: "looks good",
      file_path: option.None,
      line: option.None,
      mentioned_user_ids: [],
      created_at: "2026-01-01",
      updated_at: "2026-01-01",
    )
  let updated = database.comment_with_author_name(comment, "Alice")
  let assert "Alice" = updated.author_name
  let assert "looks good" = updated.body
}
