import gleam/int
import gleam/option
import gleam/uri

pub fn diff_line_dom_id(file_path: String, line: Int) -> String {
  "diff-line-" <> uri.percent_encode(file_path) <> "-L" <> int.to_string(line)
}

pub fn diff_line_highlighted(
  pending: option.Option(#(String, Int)),
  file_path: String,
  line: Int,
) -> Bool {
  case pending {
    option.Some(#(file, target_line)) ->
      file == file_path && target_line == line
    option.None -> False
  }
}
