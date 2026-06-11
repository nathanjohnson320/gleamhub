import content/issue_refs
import gleam/string
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn link_issue_ref_in_paragraph_test() {
  let html = issue_refs.link("<p>Closes #3</p>", "acme", "demo")
  assert string.contains(html, "href=\"/orgs/acme/repos/demo/issues/3\"")
  assert string.contains(html, ">#3</a>")
}

pub fn link_multiple_issue_refs_test() {
  let html = issue_refs.link("<p>Fixes #1 and relates to #2</p>", "acme", "demo")
  assert string.contains(html, "/orgs/acme/repos/demo/issues/1")
  assert string.contains(html, "/orgs/acme/repos/demo/issues/2")
}

pub fn skip_issue_ref_inside_tag_attribute_test() {
  let html =
    issue_refs.link("<a href=\"#anchor\">link</a>", "acme", "demo")
  assert !string.contains(html, "/orgs/acme/repos/demo/issues/")
}

pub fn skip_bare_hash_without_digits_test() {
  let html = issue_refs.link("<p>Not an issue #</p>", "acme", "demo")
  assert !string.contains(html, "issue-ref")
}
