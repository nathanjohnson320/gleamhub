import gleam/string
import gleeunit
import http/web
import wisp

pub fn main() {
  gleeunit.main()
}

pub fn default_responses_wraps_empty_404_with_html_test() {
  let response = web.default_responses(fn() { wisp.response(404) })
  let assert 404 = response.status
  let assert wisp.Text(body) = response.body
  let assert True = string.contains(body, "Not Found")
}

pub fn default_responses_wraps_empty_405_with_html_test() {
  let response = web.default_responses(fn() { wisp.response(405) })
  let assert 405 = response.status
  let assert wisp.Text(body) = response.body
  let assert True = string.contains(body, "Not Found")
}

pub fn default_responses_keeps_json_body_test() {
  let response =
    web.default_responses(fn() { wisp.json_response("{\"ok\":true}", 404) })
  let assert 404 = response.status
  let assert wisp.Text(body) = response.body
  let assert "{\"ok\":true}" = body
}

pub fn default_responses_wraps_empty_500_with_html_test() {
  let response = web.default_responses(fn() { wisp.internal_server_error() })
  let assert 500 = response.status
  let assert wisp.Text(body) = response.body
  let assert True = string.contains(body, "Internal server error")
}
