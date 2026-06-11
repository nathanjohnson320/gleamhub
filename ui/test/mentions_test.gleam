import content/mentions
import gleam/string
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn highlight_single_mention_test() {
  let html =
    mentions.highlight("<p>Thanks @nate for the review</p>", ["nate"])
  assert string.contains(html, "<span class=\"mention")
  assert string.contains(html, ">@nate</span>")
}

pub fn highlight_multiple_same_mention_test() {
  let html =
    mentions.highlight("<p>@nate ping @nate again</p>", ["nate"])
  assert string.contains(html, "ping")
  assert string.contains(html, "again")
  assert string.contains(html, ">@nate</span>")
}

pub fn highlight_dedupes_case_variants_test() {
  let html =
    mentions.highlight("<p>@Nate hello</p>", ["nate", "Nate"])
  assert string.contains(html, ">@nate</span>")
  assert !string.contains(html, "<span class=\"mention\"><span")
}
