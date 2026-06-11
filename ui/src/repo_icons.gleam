import lustre/attribute as attr
import lustre/element.{type Element, unsafe_raw_html}

const icon_wrap = "repo-entry-icon"

fn folder_svg() -> String {
  "<svg class=\"pix-icon\" viewBox=\"0 0 16 16\" width=\"16\" height=\"16\" xmlns=\"http://www.w3.org/2000/svg\" aria-hidden=\"true\">"
  <> "<rect x=\"1\" y=\"5\" width=\"14\" height=\"10\" fill=\"#78be20\" stroke=\"#00205b\" stroke-width=\"2\"/>"
  <> "<rect x=\"1\" y=\"2\" width=\"8\" height=\"4\" fill=\"#ffd204\" stroke=\"#00205b\" stroke-width=\"2\"/>"
  <> "</svg>"
}

fn file_svg() -> String {
  "<svg class=\"pix-icon\" viewBox=\"0 0 16 16\" width=\"16\" height=\"16\" xmlns=\"http://www.w3.org/2000/svg\" aria-hidden=\"true\">"
  <> "<rect x=\"3\" y=\"1\" width=\"10\" height=\"14\" fill=\"#ffffff\" stroke=\"#00205b\" stroke-width=\"2\"/>"
  <> "<rect x=\"9\" y=\"1\" width=\"4\" height=\"4\" fill=\"#f8f8f2\" stroke=\"#00205b\" stroke-width=\"2\"/>"
  <> "<rect x=\"5\" y=\"7\" width=\"6\" height=\"2\" fill=\"#78be20\"/>"
  <> "<rect x=\"5\" y=\"10\" width=\"4\" height=\"2\" fill=\"#e8f5d6\"/>"
  <> "</svg>"
}

fn crate_svg() -> String {
  "<svg class=\"pix-icon\" viewBox=\"0 0 16 16\" width=\"16\" height=\"16\" xmlns=\"http://www.w3.org/2000/svg\" aria-hidden=\"true\">"
  <> "<rect x=\"2\" y=\"4\" width=\"12\" height=\"10\" fill=\"#ffd204\" stroke=\"#00205b\" stroke-width=\"2\"/>"
  <> "<rect x=\"2\" y=\"7\" width=\"12\" height=\"2\" fill=\"#00205b\"/>"
  <> "<rect x=\"7\" y=\"4\" width=\"2\" height=\"10\" fill=\"#00205b\"/>"
  <> "</svg>"
}

pub fn entry_icon(entry_type: String) -> Element(msg) {
  let svg = case entry_type {
    "tree" -> folder_svg()
    "submodule" -> crate_svg()
    _ -> file_svg()
  }
  unsafe_raw_html("", "span", [attr.class(icon_wrap)], svg)
}

pub fn entry_link_class(entry_type: String) -> String {
  case entry_type {
    "tree" -> "repo-entry-link repo-entry-dir"
    _ -> "repo-entry-link repo-entry-file"
  }
}
