@external(javascript, "./markdown_ffi.js", "render")
fn render_ffi(markdown: String) -> String

pub fn to_html(markdown: String) -> String {
  render_ffi(markdown)
}
