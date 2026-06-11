import gleam/list
import gleam/string

const max_slug_length = 64

/// Derive a URL-safe org slug from a display name (matches server `valid_slug` rules).
pub fn slugify_display_name(name: String) -> String {
  name
  |> string.trim
  |> string.lowercase
  |> string.to_graphemes
  |> list.flat_map(grapheme_to_slug_parts)
  |> collapse_hyphens
  |> trim_hyphen_edges
  |> truncate_slug
}

/// Keep only characters allowed by the API when the user edits the slug field.
pub fn sanitize_slug_input(raw: String) -> String {
  raw
  |> string.lowercase
  |> string.to_graphemes
  |> list.filter(is_slug_grapheme)
  |> string.join("")
  |> truncate_slug_string
}

fn grapheme_to_slug_parts(c: String) -> List(String) {
  case c {
    "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z"
    | "0"
    | "1"
    | "2"
    | "3"
    | "4"
    | "5"
    | "6"
    | "7"
    | "8"
    | "9"
    | "-"
    | "_" -> [c]
    " " -> ["-"]
    _ -> []
  }
}

fn is_slug_grapheme(c: String) -> Bool {
  case c {
    "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z"
    | "0"
    | "1"
    | "2"
    | "3"
    | "4"
    | "5"
    | "6"
    | "7"
    | "8"
    | "9"
    | "-"
    | "_" -> True
    _ -> False
  }
}

fn collapse_hyphens(chars: List(String)) -> List(String) {
  list.fold(chars, [], fn(acc, c) {
    case c, list.last(acc) {
      "-", Ok("-") -> acc
      _, _ -> list.append(acc, [c])
    }
  })
}

fn trim_hyphen_edges(chars: List(String)) -> List(String) {
  chars
  |> trim_prefix_hyphens
  |> list.reverse
  |> trim_prefix_hyphens
  |> list.reverse
}

fn trim_prefix_hyphens(chars: List(String)) -> List(String) {
  case chars {
    ["-", ..rest] -> trim_prefix_hyphens(rest)
    _ -> chars
  }
}

fn truncate_slug(chars: List(String)) -> String {
  chars
  |> list.take(max_slug_length)
  |> string.join("")
}

fn truncate_slug_string(s: String) -> String {
  s
  |> string.to_graphemes
  |> list.take(max_slug_length)
  |> string.join("")
}
