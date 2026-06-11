import gleam/list
import gleam/option
import gleam/string

/// Wrap resolved @handles in HTML after markdown rendering.
pub fn highlight(html: String, handles: List(String)) -> String {
  handles
  |> list.map(fn(handle) { string.lowercase(string.trim(handle)) })
  |> list.filter(fn(handle) { handle != "" })
  |> list.unique
  |> list.fold(html, highlight_handle)
}

fn highlight_handle(body: String, handle: String) -> String {
  case string.trim(handle) {
    "" -> body
    trimmed -> {
      let needle = "@" <> trimmed
      let replacement =
        "<span class=\"mention font-semibold text-gh-accent\">"
        <> needle
        <> "</span>"
      replace_all_case_insensitive(body, needle, replacement)
    }
  }
}

fn replace_all_case_insensitive(
  haystack: String,
  needle: String,
  replacement: String,
) -> String {
  replace_all_case_insensitive_loop(
    haystack,
    string.lowercase(needle),
    needle,
    replacement,
  )
}

fn replace_all_case_insensitive_loop(
  haystack: String,
  needle_lower: String,
  needle_original: String,
  replacement: String,
) -> String {
  case find_from(string.lowercase(haystack), needle_lower, 0) {
    option.None -> haystack
    option.Some(index) -> {
      let before = string.slice(haystack, 0, index)
      let after_start = index + string.length(needle_original)
      let after = string.drop_start(haystack, after_start)
      let after_replaced =
        replace_all_case_insensitive_loop(
          after,
          needle_lower,
          needle_original,
          replacement,
        )
      before <> replacement <> after_replaced
    }
  }
}

fn find_from(haystack: String, needle: String, from: Int) -> option.Option(Int) {
  let haystack_len = string.length(haystack)
  let needle_len = string.length(needle)
  case needle_len {
    0 -> option.None
    _ -> find_from_loop(haystack, needle, from, haystack_len, needle_len)
  }
}

fn find_from_loop(
  haystack: String,
  needle: String,
  index: Int,
  haystack_len: Int,
  needle_len: Int,
) -> option.Option(Int) {
  case index + needle_len > haystack_len {
    True -> option.None
    False ->
      case string.starts_with(string.drop_start(haystack, index), needle) {
        True -> option.Some(index)
        False -> find_from_loop(haystack, needle, index + 1, haystack_len, needle_len)
      }
  }
}
