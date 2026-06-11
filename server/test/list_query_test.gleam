import gleam/http
import gleam/option
import gleeunit
import gleeunit/should
import http/list_query
import wisp.{type Request}
import wisp/simulate

pub fn main() {
  gleeunit.main()
}

fn request(query: String) -> Request {
  let path = case query {
    "" -> "/api/orgs/acme/repos/demo/issues"
    _ -> "/api/orgs/acme/repos/demo/issues?" <> query
  }
  simulate.request(http.Get, path)
}

pub fn parse_issue_defaults_test() {
  let assert Ok(query) = list_query.parse_issue_list_query(request(""))
  query.state |> should.equal("open")
  query.sort |> should.equal("number")
  query.order |> should.equal("desc")
}

pub fn parse_issue_state_and_sort_test() {
  let assert Ok(query) =
    list_query.parse_issue_list_query(
      request("state=closed&sort=updated&order=asc&q=bug"),
    )
  query.state |> should.equal("closed")
  query.sort |> should.equal("updated")
  query.order |> should.equal("asc")
  query.q |> should.equal(option.Some("bug"))
}

pub fn parse_issue_invalid_state_test() {
  let assert Error(list_query.InvalidState) =
    list_query.parse_issue_list_query(request("state=invalid"))
}

pub fn resolve_label_ids_by_name_test() {
  let labels = [#("id-1", "bug"), #("id-2", "enhancement")]
  let assert Ok(ids) = list_query.resolve_label_ids(labels, ["bug"])
  ids |> should.equal(["id-1"])
}

pub fn resolve_label_ids_unknown_test() {
  let labels = [#("id-1", "bug")]
  let assert Error(list_query.UnknownLabel("nope")) =
    list_query.resolve_label_ids(labels, ["nope"])
}
