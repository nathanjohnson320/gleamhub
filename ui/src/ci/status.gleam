import gleam/option
import lustre/attribute as attr
import lustre/element.{type Element, text}
import lustre/element/html.{span}

/// Colorblind-friendly status disc (blue pass, red fail, light blue running).
pub fn status_circle(
  state: String,
  size: String,
  animated: Bool,
) -> Element(msg) {
  let motion = case animated {
    False -> ""
    True ->
      case state {
        "running" | "queued" -> " animate-pulse"
        _ -> ""
      }
  }
  let classes = case state {
    "success" ->
      size
      <> " shrink-0 border-2 border-gh-ink bg-blue-600"
      <> motion
    "failure" ->
      size
      <> " shrink-0 border-2 border-gh-ink bg-red-600"
      <> motion
    "running" | "queued" ->
      size <> " shrink-0 border-2 border-gh-ink bg-sky-400" <> motion
    "skipped" ->
      size
      <> " shrink-0 border-2 border-gh-ink bg-gh-muted"
      <> motion
    _ -> size <> " shrink-0 border-2 border-gh-ink bg-gh-muted" <> motion
  }
  span([attr.class(classes), attr.title(status_title(state))], [])
}

pub fn status_title(state: String) -> String {
  case state {
    "success" -> "Passed"
    "failure" -> "Failed"
    "running" -> "Running"
    "queued" -> "Queued"
    "skipped" -> "Skipped"
    _ -> state
  }
}

pub fn status_label(state: String) -> String {
  case state {
    "success" -> "Passed"
    "failure" -> "Failed"
    "running" -> "Running"
    "queued" -> "Queued"
    "skipped" -> "Skipped"
    _ -> state
  }
}

pub fn pipeline_cell(
  pipeline: option.Option(#(String, String)),
) -> Element(msg) {
  case pipeline {
    option.None ->
      span([attr.class("comic-state-badge comic-state-closed")], [text("-")])
    option.Some(#(state, _commit)) ->
      span([attr.class("ci-status-pill")], [
        status_circle(
          state,
          "h-2.5 w-2.5",
          state == "running" || state == "queued",
        ),
        span([], [text(status_label(state))]),
      ])
  }
}
