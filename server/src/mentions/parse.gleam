import gleam/list
import gleam/option
import gleam/string

/// Extract unique @handles from comment markdown (without the leading @).
pub fn handles(body: String) -> List(String) {
  collect_handles(body, 0, [])
  |> list.reverse
  |> list.unique
}

fn collect_handles(
  body: String,
  index: Int,
  found: List(String),
) -> List(String) {
  case find_from(body, "@", index) {
    option.None -> found
    option.Some(at) ->
      case mention_start_ok(body, at) {
        False -> collect_handles(body, at + 1, found)
        True ->
          case read_handle(body, at + 1) {
            option.None -> collect_handles(body, at + 1, found)
            option.Some(#(handle, next)) ->
              collect_handles(body, next, [handle, ..found])
          }
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

fn mention_start_ok(body: String, at: Int) -> Bool {
  case at {
    0 -> True
    _ ->
      case string.pop_grapheme(string.drop_start(body, at - 1)) {
        Ok(#(before, _)) -> valid_mention_prefix(before)
        Error(_) -> False
      }
  }
}

fn valid_mention_prefix(char: String) -> Bool {
  case char {
    " " | "\n" | "\t" | "\r" | "(" | "[" | "{" | ">" | ":" -> True
    _ -> False
  }
}

fn read_handle(body: String, start: Int) -> option.Option(#(String, Int)) {
  read_handle_loop(body, start, "")
}

fn read_handle_loop(
  body: String,
  index: Int,
  acc: String,
) -> option.Option(#(String, Int)) {
  case string.pop_grapheme(string.drop_start(body, index)) {
    Error(_) ->
      case acc {
        "" -> option.None
        handle -> option.Some(#(handle, index))
      }
    Ok(#(char, _)) ->
      case handle_char(char) {
        True -> read_handle_loop(body, index + 1, acc <> char)
        False ->
          case acc {
            "" -> option.None
            handle -> option.Some(#(handle, index))
          }
      }
  }
}

fn handle_char(char: String) -> Bool {
  string.contains("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-", char)
}
