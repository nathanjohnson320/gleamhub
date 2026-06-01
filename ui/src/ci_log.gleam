import gleam/string

@external(javascript, "./ci_log_ansi_ffi.js", "ansi_to_html")
fn ansi_to_html_ffi(text: String) -> String

/// Renders CI worker log text with ANSI colors as HTML (safe to use in `unsafe_raw_html`).
pub fn ansi_to_html(text: String) -> String {
  case string.trim(text) {
    "" -> ""
    _ -> ansi_to_html_ffi(text)
  }
}
