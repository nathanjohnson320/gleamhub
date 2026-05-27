import gleam/list
import gleam/string

@external(javascript, "./highlight_ffi.js", "highlight_code")
fn highlight_code_ffi(code: String, language: String) -> String

/// Map a repository file path to a highlight.js language id (empty = auto-detect).
pub fn language_for_path(path: String) -> String {
  case file_extension(path) {
    "bash" | "sh" | "zsh" -> "bash"
    "c" | "h" -> "c"
    "cpp" | "cc" | "cxx" | "hpp" -> "cpp"
    "css" -> "css"
    "dockerfile" -> "dockerfile"
    "ex" | "exs" -> "elixir"
    "erl" | "hrl" -> "erlang"
    "gleam" -> ""
    "go" -> "go"
    "graphql" | "gql" -> "graphql"
    "html" | "htm" -> "xml"
    "java" -> "java"
    "js" | "mjs" | "cjs" -> "javascript"
    "json" -> "json"
    "jsx" -> "javascript"
    "kt" | "kts" -> "kotlin"
    "lua" -> "lua"
    "md" | "markdown" -> "markdown"
    "php" -> "php"
    "py" -> "python"
    "rb" -> "ruby"
    "rs" -> "rust"
    "sql" -> "sql"
    "swift" -> "swift"
    "toml" -> "ini"
    "ts" | "mts" | "cts" -> "typescript"
    "tsx" -> "typescript"
    "xml" -> "xml"
    "yaml" | "yml" -> "yaml"
    "zig" -> "zig"
    _ -> ""
  }
}

fn file_extension(path: String) -> String {
  case string.split(path, ".") {
    [] -> ""
    parts ->
      case list.last(parts) {
        Ok(ext) -> string.lowercase(ext)
        Error(_) -> ""
      }
  }
}

pub fn to_html(code: String, path: String) -> String {
  let language = language_for_path(path)
  let inner = highlight_code_ffi(code, language)
  let lang_class = case language {
    "" -> "hljs"
    lang -> "hljs language-" <> lang
  }
  "<pre class=\"repo-blob-pre\"><code class=\""
  <> lang_class
  <> "\">"
  <> inner
  <> "</code></pre>"
}
