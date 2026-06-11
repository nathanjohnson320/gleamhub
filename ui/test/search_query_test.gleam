import gleam/option
import gleeunit
import gleeunit/should
import http/api.{Label, OrgMember}
import http/search_query

pub fn main() {
  gleeunit.main()
}

pub fn parse_free_text_test() {
  search_query.parse_issue_search("fix login bug")
  |> should.equal(search_query.IssueSearchParts(
    label_names: [],
    assignee: option.None,
    author: option.None,
    text: "fix login bug",
  ))
}

pub fn parse_issue_qualifiers_test() {
  search_query.parse_issue_search("label:hold,bug assignee:alice author:bob fix")
  |> should.equal(search_query.IssueSearchParts(
    label_names: ["hold", "bug"],
    assignee: option.Some("alice"),
    author: option.Some("bob"),
    text: "fix",
  ))
}

pub fn parse_quoted_label_test() {
  search_query.parse_issue_search("label:\"hold on\" bug")
  |> should.equal(search_query.IssueSearchParts(
    label_names: ["hold on"],
    assignee: option.None,
    author: option.None,
    text: "bug",
  ))
}

pub fn parse_mr_branch_qualifiers_test() {
  search_query.parse_merge_request_search(
    "source:feature/login target:main author:alice refactor",
  )
  |> should.equal(search_query.MergeRequestSearchParts(
    label_names: [],
    author: option.Some("alice"),
    source_branch: option.Some("feature/login"),
    target_branch: option.Some("main"),
    text: "refactor",
  ))
}

pub fn resolve_member_by_username_test() {
  let members = [
    OrgMember(
      user_id: "user_1",
      role: "member",
      display_name: "Alice Example",
      username: option.Some("alice"),
    ),
  ]
  search_query.resolve_member(option.Some("alice"), members)
  |> should.equal(option.Some("user_1"))
}

pub fn resolve_label_names_test() {
  let labels = [
    Label(id: "1", name: "bug", color: "ff0000"),
    Label(id: "2", name: "Hold", color: "00ff00"),
  ]
  search_query.resolve_label_names(["hold", "missing"], labels)
  |> should.equal(["Hold", "missing"])
}
