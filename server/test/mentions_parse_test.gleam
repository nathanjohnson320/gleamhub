import gleeunit
import mentions/parse

pub fn main() {
  gleeunit.main()
}

pub fn handles_empty_body_test() {
  let assert [] = parse.handles("")
}

pub fn handles_single_mention_test() {
  let assert ["ada"] = parse.handles("Thanks @ada for the review")
}

pub fn handles_multiple_mentions_test() {
  let assert ["ada", "bob"] = parse.handles("@ada and @bob please look")
}

pub fn handles_mention_after_newline_test() {
  let assert ["ada"] = parse.handles("Hello\n\n@ada")
}

pub fn ignores_email_like_at_sign_test() {
  let assert [] = parse.handles("Email me at user@example.com")
}

pub fn handles_mention_in_parentheses_test() {
  let assert ["ada"] = parse.handles("FYI (@ada)")
}

pub fn deduplicates_repeated_handles_test() {
  let assert ["ada"] = parse.handles("@ada said hi to @ada")
}
