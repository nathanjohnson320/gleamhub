import gleam/int
import gleam/list
import gleam/option
import gleam/string
import routes

/// Turn `#12` issue references into links after markdown rendering.
pub fn link(html: String, org: String, repo: String) -> String {
  link_scan(html, 0, "", False, org, repo)
}

fn link_scan(
  html: String,
  index: Int,
  acc: String,
  in_tag: Bool,
  org: String,
  repo: String,
) -> String {
  let html_len = string.length(html)
  case index >= html_len {
    True -> acc
    False ->
      case string.pop_grapheme(string.drop_start(html, index)) {
        Error(_) -> acc
        Ok(#(char, _)) ->
          case char, in_tag {
            "<", False ->
              link_scan(html, index + 1, acc <> char, True, org, repo)
            ">", True ->
              link_scan(html, index + 1, acc <> char, False, org, repo)
            "#", False ->
              case read_issue_ref(html, index, org, repo) {
                option.Some(#(replacement, next)) ->
                  link_scan(html, next, acc <> replacement, False, org, repo)
                option.None ->
                  link_scan(html, index + 1, acc <> char, False, org, repo)
              }
            _, _ ->
              link_scan(html, index + 1, acc <> char, in_tag, org, repo)
          }
      }
  }
}

fn read_issue_ref(
  html: String,
  at: Int,
  org: String,
  repo: String,
) -> option.Option(#(String, Int)) {
  case read_digits(html, at + 1) {
    option.None -> option.None
    option.Some(#(number_str, next)) ->
      case int.parse(number_str) {
        Error(_) -> option.None
        Ok(number) ->
          case issue_ref_prefix_ok(html, at) {
            True -> {
              let href = routes.issue_detail_path(org, repo, number)
              let replacement =
                "<a href=\""
                <> href
                <> "\" class=\"issue-ref font-semibold text-gh-accent hover:underline\">#"
                <> number_str
                <> "</a>"
              option.Some(#(replacement, next))
            }
            False -> option.None
          }
      }
  }
}

fn issue_ref_prefix_ok(html: String, at: Int) -> Bool {
  case at {
    0 -> True
    _ ->
      case string.pop_grapheme(string.drop_start(html, at - 1)) {
        Ok(#(before, _)) -> valid_issue_ref_prefix(before)
        Error(_) -> False
      }
  }
}

fn valid_issue_ref_prefix(char: String) -> Bool {
  list.contains(
    [" ", "\n", "\t", "\r", "(", "[", "{", ">", ":", "*", "-", ".", ","],
    char,
  )
}

fn read_digits(html: String, start: Int) -> option.Option(#(String, Int)) {
  read_digits_loop(html, start, "")
}

fn read_digits_loop(
  html: String,
  index: Int,
  acc: String,
) -> option.Option(#(String, Int)) {
  case string.pop_grapheme(string.drop_start(html, index)) {
    Error(_) ->
      case acc {
        "" -> option.None
        digits -> option.Some(#(digits, index))
      }
    Ok(#(char, _)) ->
      case char {
        "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ->
          read_digits_loop(html, index + 1, acc <> char)
        _ ->
          case acc {
            "" -> option.None
            digits -> option.Some(#(digits, index))
          }
      }
  }
}
