import lustre/attribute as attr
import lustre/element.{type Element, text}
import lustre/element/html.{span}
import gleam/option

/// Colorblind-friendly status disc (blue pass, red fail, light blue running).
pub fn status_circle(state: String, size: String, animated: Bool) -> Element(msg) {
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
      size <> " shrink-0 rounded-full bg-blue-600 ring-2 ring-blue-800/30" <> motion
    "failure" ->
      size <> " shrink-0 rounded-full bg-red-600 ring-2 ring-red-800/30" <> motion
    "running" | "queued" ->
      size <> " shrink-0 rounded-full bg-sky-300 ring-2 ring-sky-600" <> motion
    "skipped" ->
      size <> " shrink-0 rounded-full bg-slate-400 ring-2 ring-slate-500/40" <> motion
    _ -> size <> " shrink-0 rounded-full bg-slate-400" <> motion
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
      span([attr.class("text-xs text-gh-muted")], [text("—")])
    option.Some(#(state, _commit)) ->
      span([attr.class("inline-flex items-center gap-2")], [
        status_circle(state, "h-2.5 w-2.5", state == "running" || state == "queued"),
        span([attr.class("text-xs text-gh-muted")], [text(status_label(state))]),
      ])
  }
}
