import ci/log_ansi as ci_log_ansi
import gleam/string
import gleeunit

const esc = "\u{1B}["

pub fn main() {
  gleeunit.main()
}

pub fn plain_text_is_escaped_test() {
  assert ci_log_ansi.ansi_to_html("a < b") == "a &lt; b"
}

pub fn colour_code_wraps_text_test() {
  assert ci_log_ansi.ansi_to_html(esc <> "31merr" <> esc <> "0m")
    == "<span style=\"color:#f87171\">err</span>"
}

pub fn bold_and_dim_test() {
  assert ci_log_ansi.ansi_to_html(esc <> "1;2mhi" <> esc <> "0m")
    == "<span style=\"font-weight:600;opacity:0.55\">hi</span>"
}

pub fn long_log_does_not_fail_test() {
  let line = esc <> "32mok" <> esc <> "0m\n"
  let log = string.repeat(line, 5000)
  let html = ci_log_ansi.ansi_to_html(log)
  assert string.contains(html, "ok")
}

pub fn dagger_progress_line_test() {
  let input =
    esc <> "95m1 : " <> esc <> "0m" <> esc <> "90;2m connect" <> esc <> "0m"
  let assert True =
    string.contains(
      ci_log_ansi.ansi_to_html(input),
      "<span style=\"color:#f0abfc\">1 : </span>",
    )
}

pub fn reset_after_colour_test() {
  let input = esc <> "31mred" <> esc <> "0m plain"
  assert ci_log_ansi.ansi_to_html(input)
    == "<span style=\"color:#f87171\">red</span> plain"
}

pub fn bright_cyan_colour_test() {
  assert ci_log_ansi.ansi_to_html(esc <> "96mnote" <> esc <> "0m")
    == "<span style=\"color:#67e8f9\">note</span>"
}

pub fn bold_and_colour_combined_test() {
  assert ci_log_ansi.ansi_to_html(esc <> "1;34minfo" <> esc <> "0m")
    == "<span style=\"font-weight:600;color:#60a5fa\">info</span>"
}

pub fn bold_reset_with_code_22_test() {
  let input = esc <> "1mbold" <> esc <> "22m normal"
  assert ci_log_ansi.ansi_to_html(input)
    == "<span style=\"font-weight:600\">bold</span> normal"
}

pub fn green_reset_test() {
  let input = esc <> "32mgreen" <> esc <> "0m after"
  assert ci_log_ansi.ansi_to_html(input)
    == "<span style=\"color:#4ade80\">green</span> after"
}

pub fn non_sgr_sequences_do_not_leave_escape_bytes_test() {
  let input = "log" <> esc <> "2J" <> esc <> "32mok" <> esc <> "0m"
  let html = ci_log_ansi.ansi_to_html(input)
  assert !string.contains(html, "\u{1B}")
  assert string.contains(html, "log")
  assert string.contains(html, "<span style=\"color:#4ade80\">ok</span>")
}

pub fn multiple_colour_segments_test() {
  let input = esc <> "31merr" <> esc <> "0m " <> esc <> "32mok" <> esc <> "0m"
  assert ci_log_ansi.ansi_to_html(input)
    == "<span style=\"color:#f87171\">err</span> <span style=\"color:#4ade80\">ok</span>"
}

pub fn escapes_html_entities_test() {
  assert ci_log_ansi.ansi_to_html("Tom & Jerry \"quotes\" <tag>")
    == "Tom &amp; Jerry &quot;quotes&quot; &lt;tag&gt;"
}

pub fn preserves_newlines_test() {
  let input = "line1\n" <> esc <> "33mline2" <> esc <> "0m\nline3"
  assert ci_log_ansi.ansi_to_html(input)
    == "line1\n<span style=\"color:#facc15\">line2</span>\nline3"
}

pub fn text_before_and_after_sequences_test() {
  let input = "prefix " <> esc <> "35mhighlight" <> esc <> "0m suffix"
  assert ci_log_ansi.ansi_to_html(input)
    == "prefix <span style=\"color:#e879f9\">highlight</span> suffix"
}

pub fn unknown_sgr_codes_are_ignored_test() {
  let input = esc <> "99mvisible" <> esc <> "0m"
  assert ci_log_ansi.ansi_to_html(input) == "visible"
}

pub fn literal_escape_without_bracket_is_preserved_test() {
  assert ci_log_ansi.ansi_to_html("\u{1B}not-ansi") == "\u{1B}not-ansi"
}

pub fn dim_without_bold_test() {
  assert ci_log_ansi.ansi_to_html(esc <> "2mfaint" <> esc <> "0m")
    == "<span style=\"opacity:0.55\">faint</span>"
}
