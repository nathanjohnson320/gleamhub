import gleam/list
import gleam/string

/// MIME type for raw file responses from a repo-relative path.
pub fn content_type_for_path(path: String) -> String {
  case file_extension(path) {
    ".md" | ".markdown" -> "text/markdown; charset=utf-8"
    ".gleam"
    | ".txt"
    | ".sql"
    | ".toml"
    | ".yaml"
    | ".yml"
    | ".dockerignore"
    | ".gitignore"
    | ".gitattributes"
    | ".editorconfig"
    | ".env"
    | ".sh"
    | ".bash"
    | ".zsh"
    | ".dockerfile" -> "text/plain; charset=utf-8"
    ".json" -> "application/json; charset=utf-8"
    ".html" | ".htm" -> "text/html; charset=utf-8"
    ".css" -> "text/css; charset=utf-8"
    ".js" | ".mjs" -> "text/javascript; charset=utf-8"
    ".xml" -> "application/xml; charset=utf-8"
    ".png" -> "image/png"
    ".jpg" | ".jpeg" -> "image/jpeg"
    ".gif" -> "image/gif"
    ".svg" -> "image/svg+xml"
    ".webp" -> "image/webp"
    ".ico" -> "image/x-icon"
    ".pdf" -> "application/pdf"
    ".zip" -> "application/zip"
    ".wasm" -> "application/wasm"
    _ -> content_type_for_basename(basename(path))
  }
}

fn content_type_for_basename(name: String) -> String {
  case name {
    "LICENSE" | "LICENSE.md" | "LICENSE.txt" | "Makefile" | "Dockerfile" ->
      "text/plain; charset=utf-8"
    _ ->
      case string.starts_with(name, ".") {
        True -> "text/plain; charset=utf-8"
        False -> "application/octet-stream"
      }
  }
}

pub fn basename(path: String) -> String {
  case string.split(path, on: "/") |> list.last {
    Ok(name) -> name
    Error(_) -> path
  }
}

fn file_extension(path: String) -> String {
  let name = string.lowercase(basename(path))
  case string.split(name, on: ".") {
    [] | [_] -> ""
    parts ->
      case list.last(parts) {
        Ok(ext) -> "." <> ext
        Error(_) -> ""
      }
  }
}
