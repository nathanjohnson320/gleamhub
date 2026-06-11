import components
import gleam/option
import http/api
import http/lustre_http
import lustre/attribute as attr
import lustre/element.{type Element, text}
import lustre/element/html.{a, div}

pub type Gate {
  Pending
  Allowed(role: option.Option(String), name: String)
  Forbidden
  NotFound
  Failed(String)
}

pub fn gate_from_org(result: Result(api.Org, lustre_http.HttpError)) -> Gate {
  case result {
    Ok(org) -> Allowed(org.role, org.name)
    Error(err) -> gate_from_error(err)
  }
}

pub fn gate_from_error(err: lustre_http.HttpError) -> Gate {
  case err {
    lustre_http.Unauthorized ->
      Failed("Session expired - refresh the page or sign in again.")
    lustre_http.NotFound -> NotFound
    lustre_http.OtherError(403, _) -> Forbidden
    lustre_http.OtherError(_, body) ->
      Failed(api.error_message_from_json(body, "Failed to load organization."))
    _ -> Failed("Failed to load organization.")
  }
}

pub fn pending_view() -> Element(msg) {
  div([attr.class(components.page)], [components.loading_state()])
}

pub fn forbidden_view() -> Element(msg) {
  div([attr.class(components.page)], [
    components.breadcrumb_back("/orgs", "Organizations"),
    components.page_header(
      "Access denied",
      "You are not a member of this organization.",
    ),
    a([attr.class(components.btn_primary), attr.href("/orgs")], [
      text("Back to organizations"),
    ]),
  ])
}

pub fn not_found_view() -> Element(msg) {
  div([attr.class(components.page)], [
    components.breadcrumb_back("/orgs", "Organizations"),
    components.page_header("Not found", "That organization does not exist."),
    a([attr.class(components.btn_primary), attr.href("/orgs")], [
      text("Back to organizations"),
    ]),
  ])
}

pub fn failed_view(message: String) -> Element(msg) {
  div([attr.class(components.page)], [
    components.breadcrumb_back("/orgs", "Organizations"),
    components.error_alert(message),
    a(
      [
        attr.class(components.btn_primary <> " mt-4 inline-block"),
        attr.href("/orgs"),
      ],
      [
        text("Back to organizations"),
      ],
    ),
  ])
}
