import ci/log_ansi as ci_log_ansi
import gleam/list
import gleam/string

/// Renders CI worker log text with ANSI colors as HTML (safe to use in `unsafe_raw_html`).
pub fn ansi_to_html(text: String) -> String {
  case string.trim(text) {
    "" -> ""
    _ -> ci_log_ansi.ansi_to_html(normalize_terminal_log(text))
  }
}

/// Dagger and other CLIs use `\r` to redraw progress lines; keep the final
/// segment on each physical line so streamed logs read top-to-bottom.
fn normalize_terminal_log(text: String) -> String {
  text
  |> string.split(on: "\n")
  |> list.map(final_carriage_segment)
  |> string.join("\n")
}

fn final_carriage_segment(line: String) -> String {
  case list.last(string.split(line, on: "\r")) {
    Ok(segment) -> segment
    Error(_) -> line
  }
}
