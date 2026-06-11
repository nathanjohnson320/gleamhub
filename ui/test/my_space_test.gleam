import gleam/option
import gleeunit
import http/api as api
import pages/my_space

pub fn main() {
  gleeunit.main()
}

pub fn notification_summary_includes_mr_details_test() {
  let notification =
    api.Notification(
      id: "n1",
      type_: "ci.complete",
      payload:
        "{\"org_slug\":\"nate\",\"repo_name\":\"gleamhub\",\"merge_request_number\":7,\"merge_request_title\":\"P1 Begins\",\"pipeline_state\":\"success\"}",
      read_at: option.None,
      created_at: "2026-06-08T12:00:00Z",
    )
  let summary = my_space.notification_summary(notification)
  assert summary == "CI passed on gleamhub #7 P1 Begins"
}

pub fn merge_request_label_without_title_test() {
  let label =
    my_space.merge_request_label(
      "{\"repo_name\":\"gleamhub\",\"merge_request_number\":7}",
    )
  assert label == "gleamhub #7"
}
