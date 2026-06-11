import gleam/list
import gleam/option
import gleeunit
import issues/link_parser

pub fn main() {
  gleeunit.main()
}

fn has_link(
  links: List(link_parser.ParsedLink),
  repo: option.Option(String),
  number: Int,
  link_type: link_parser.LinkType,
) -> Bool {
  list.any(links, fn(link) {
    link.repo == repo
    && link.number == number
    && link.link_type == link_type
  })
}

pub fn fixes_same_repo_test() {
  let links = link_parser.parse("acme", "Fixes #12")
  let assert True = has_link(links, option.None, 12, link_parser.Closes)
}

pub fn closes_same_repo_test() {
  let links = link_parser.parse("acme", "Closes #12")
  let assert True = has_link(links, option.None, 12, link_parser.Closes)
}

pub fn resolved_same_repo_test() {
  let links = link_parser.parse("acme", "Resolved #12")
  let assert True = has_link(links, option.None, 12, link_parser.Closes)
}

pub fn related_same_repo_test() {
  let links = link_parser.parse("acme", "Related #5")
  let assert True = has_link(links, option.None, 5, link_parser.Relates)
}

pub fn cross_repo_same_org_test() {
  let links = link_parser.parse("acme", "Fixes acme/other#3")
  let assert True =
    has_link(links, option.Some("other"), 3, link_parser.Closes)
}

pub fn cross_repo_wrong_org_ignored_test() {
  let links = link_parser.parse("acme", "Fixes otherorg/repo#1")
  let assert False = has_link(links, option.Some("repo"), 1, link_parser.Closes)
}

pub fn bare_issue_ref_ignored_test() {
  let links = link_parser.parse("acme", "See #12 for context")
  let assert 0 = list.length(links)
}

pub fn closes_wins_over_relates_test() {
  let links = link_parser.parse("acme", "Related #1\nFixes #1")
  let assert 1 = list.length(links)
  let assert True = has_link(links, option.None, 1, link_parser.Closes)
}

pub fn case_insensitive_keyword_test() {
  let links = link_parser.parse("acme", "FIXES #7")
  let assert True = has_link(links, option.None, 7, link_parser.Closes)
}
