import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string

pub type DiffLineKind {
  Meta
  Add
  Delete
  Context
}

pub type DiffLine {
  DiffLine(
    kind: DiffLineKind,
    text: String,
    new_line: option.Option(Int),
    old_line: option.Option(Int),
  )
}

pub fn parse_patch(patch: String) -> List(DiffLine) {
  let #(_, rows) =
    list.fold(string.split(patch, on: "\n"), #(option.None, []), fn(acc, line) {
      let #(state, lines) = acc
      let #(next_state, row) = process_line(line, state)
      #(next_state, [row, ..lines])
    })
  list.reverse(rows)
}

fn process_line(
  line: String,
  state: option.Option(#(Int, Int)),
) -> #(option.Option(#(Int, Int)), DiffLine) {
  case line {
    "@@" <> _ ->
      case parse_hunk_header(line) {
        Ok(#(new_start, old_start)) -> #(
          option.Some(#(new_start, old_start)),
          DiffLine(kind: Meta, text: line, new_line: option.None, old_line: option.None),
        )
        Error(_) -> #(
          state,
          DiffLine(kind: Meta, text: line, new_line: option.None, old_line: option.None),
        )
      }
    _ ->
      case state {
        option.None -> #(
          option.None,
          DiffLine(kind: classify_meta(line), text: line, new_line: option.None, old_line: option.None),
        )
        option.Some(#(new_line, old_line)) -> process_hunk_line(line, new_line, old_line)
      }
  }
}

fn process_hunk_line(
  line: String,
  new_line: Int,
  old_line: Int,
) -> #(option.Option(#(Int, Int)), DiffLine) {
  case line {
    "+" <> _ ->
      case string.starts_with(line, "+++") {
        True -> #(
          option.Some(#(new_line, old_line)),
          DiffLine(kind: Meta, text: line, new_line: option.None, old_line: option.None),
        )
        False -> #(
          option.Some(#(new_line + 1, old_line)),
          DiffLine(
            kind: Add,
            text: line,
            new_line: option.Some(new_line),
            old_line: option.None,
          ),
        )
      }
    "-" <> _ ->
      case string.starts_with(line, "---") {
        True -> #(
          option.Some(#(new_line, old_line)),
          DiffLine(kind: Meta, text: line, new_line: option.None, old_line: option.None),
        )
        False -> #(
          option.Some(#(new_line, old_line + 1)),
          DiffLine(
            kind: Delete,
            text: line,
            new_line: option.None,
            old_line: option.Some(old_line),
          ),
        )
      }
    " " <> _ -> #(
      option.Some(#(new_line + 1, old_line + 1)),
      DiffLine(
        kind: Context,
        text: line,
        new_line: option.Some(new_line),
        old_line: option.Some(old_line),
      ),
    )
    _ -> #(
      option.Some(#(new_line, old_line)),
      DiffLine(kind: Meta, text: line, new_line: option.None, old_line: option.None),
    )
  }
}

fn classify_meta(_line: String) -> DiffLineKind {
  Meta
}

fn parse_hunk_header(line: String) -> Result(#(Int, Int), Nil) {
  case string.split(line, on: " ") {
    ["@@", old_part, new_part, ..] -> {
      use old_start <- result.try(parse_hunk_range(old_part))
      use new_start <- result.try(parse_hunk_range(new_part))
      Ok(#(new_start, old_start))
    }
    _ -> Error(Nil)
  }
}

fn parse_hunk_range(part: String) -> Result(Int, Nil) {
  let without_sign =
    case string.starts_with(part, "-") || string.starts_with(part, "+") {
      True -> string.drop_start(part, 1)
      False -> part
    }
  case string.split(without_sign, on: ",") {
    [num, ..] -> int.parse(num)
    _ -> Error(Nil)
  }
}

pub fn commentable_new_line(line: DiffLine) -> option.Option(Int) {
  case line {
    DiffLine(kind: Add, new_line: option.Some(n), ..) -> option.Some(n)
    DiffLine(kind: Context, new_line: option.Some(n), ..) -> option.Some(n)
    _ -> option.None
  }
}

pub fn row_class(line: DiffLine) -> String {
  case line.kind {
    Meta -> "diff-line diff-meta"
    Add -> "diff-line diff-add"
    Delete -> "diff-line diff-del"
    Context -> "diff-line diff-context"
  }
}
