import gleam/list
import gleam/option
import gleam/result
import gleam/string

pub type PathError {
  InvalidPath
}

/// Normalize a repo-relative path: empty string is root; rejects `..` and absolute paths.
pub fn normalize(path: String) -> Result(String, PathError) {
  let trimmed = string.trim(path)
  case trimmed {
    "" -> Ok("")
    _ -> {
      let segments = string.split(trimmed, on: "/")
      case list.any(segments, fn(s) { s == ".." || s == "" }) {
        True -> Error(InvalidPath)
        False ->
          segments
          |> list.filter(fn(s) { s != "" })
          |> string.join(with: "/")
          |> Ok
      }
    }
  }
}

pub fn join_path(base: String, name: String) -> Result(String, PathError) {
  case base {
    "" -> normalize(name)
    _ ->
      normalize(base <> "/" <> name)
      |> result.map(fn(p) {
        case p {
          "" -> base
          joined -> joined
        }
      })
  }
}

pub fn tree_ref_path(ref: String, path: String) -> String {
  case path {
    "" -> ref
    _ -> ref <> ":" <> path
  }
}

/// Git object id: 7-40 hexadecimal characters (short or full SHA).
pub fn normalize_sha(sha: String) -> Result(String, PathError) {
  let trimmed = string.lowercase(string.trim(sha))
  let len = string.length(trimmed)
  case len >= 7 && len <= 40 && is_hex(trimmed) {
    True -> Ok(trimmed)
    False -> Error(InvalidPath)
  }
}

fn is_hex(s: String) -> Bool {
  s
  |> string.to_graphemes
  |> list.all(fn(c) { string.contains("0123456789abcdef", c) })
}

/// Git ref for browse operations: branch name or commit SHA.
pub fn normalize_ref(ref: String) -> Result(String, PathError) {
  let trimmed = string.trim(ref)
  case trimmed {
    "" -> Error(InvalidPath)
    _ ->
      case string.starts_with(trimmed, "-") {
        True -> Error(InvalidPath)
        False ->
          case normalize_sha(trimmed) {
            Ok(sha) -> Ok(sha)
            Error(_) -> normalize_branch(trimmed)
          }
      }
  }
}

/// Validates a repository disk path stored in the database.
pub fn validate_disk_path(path: String) -> Result(String, PathError) {
  let trimmed = string.trim(path)
  case trimmed {
    "" -> Error(InvalidPath)
    _ ->
      case string.starts_with(trimmed, "/") || string.contains(trimmed, "..") {
        True -> Error(InvalidPath)
        False -> {
          let segments = string.split(trimmed, on: "/")
          case list.any(segments, fn(s) { s == "" }) {
            True -> Error(InvalidPath)
            False -> Ok(trimmed)
          }
        }
      }
  }
}

/// Branch names must be a single ref segment (no `/..` or absolute paths).
pub fn normalize_branch(name: String) -> Result(String, PathError) {
  let trimmed = string.trim(name)
  case trimmed {
    "" -> Error(InvalidPath)
    _ ->
      case
        string.contains(trimmed, "..")
        || string.starts_with(trimmed, "/")
        || string.contains(trimmed, "//")
      {
        True -> Error(InvalidPath)
        False -> Ok(trimmed)
      }
  }
}

pub fn parent_path(path: String) -> option.Option(String) {
  case string.split(path, on: "/") {
    [] -> option.None
    [_] -> option.Some("")
    segments -> {
      let len = list.length(segments)
      case len {
        0 -> option.None
        _ -> {
          let parts = list.take(segments, len - 1)
          option.Some(string.join(parts, with: "/"))
        }
      }
    }
  }
}
