import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/string
import lustre/attribute as attr
import lustre/element.{type Element, text}
import lustre/element/html.{a, div, pre, span}

const context_padding = 3

const max_summary_ranges = 8

/// Groups consecutive line numbers into inclusive ranges.
pub fn conflict_line_ranges(lines: List(Int)) -> List(#(Int, Int)) {
  case list.sort(lines, int.compare) {
    [] -> []
    [first, ..rest] ->
      list.fold(rest, [#(first, first)], fn(acc, n) {
        let assert [#(start, end), ..before] = acc
        case n == end + 1 {
          True -> [#(start, n), ..before]
          False -> [#(n, n), #(start, end), ..before]
        }
      })
      |> list.reverse
  }
}

fn range_label(start: Int, end: Int) -> String {
  case start == end {
    True -> "Line " <> int.to_string(start)
    False -> "Lines " <> int.to_string(start) <> "-" <> int.to_string(end)
  }
}

fn inclusive_range(from start: Int, to stop: Int) -> List(Int) {
  let append = fn(acc, n) { list.append(acc, [n]) }
  case int.compare(start, stop) {
    order.Gt -> int.range(from: start, to: stop - 1, with: [], run: append)
    order.Lt -> int.range(from: start, to: stop + 1, with: [], run: append)
    order.Eq -> [start]
  }
}

pub type Side {
  Side(content: String, binary: Bool, missing: Bool)
}

pub type FileLinks {
  FileLinks(
    target_href: option.Option(String),
    source_href: option.Option(String),
  )
}

pub type AlignedRow {
  AlignedRow(number: Int, target: String, source: String, changed: Bool)
}

pub type Segment {
  VisibleRows(List(AlignedRow))
  Collapsed(count: Int, before_line: Int)
}

pub fn side_by_side(
  target_label: String,
  target: Side,
  source_label: String,
  source: Side,
  links: FileLinks,
) -> Element(msg) {
  div([attr.class("conflict-panels flex min-h-full flex-col lg:flex-row")], [
    side_panel(
      "border-slate-200 lg:border-r",
      target_label,
      target,
      links.target_href,
    ),
    side_panel("", source_label, source, links.source_href),
  ])
}

pub fn side_by_side_highlighted(
  target_label: String,
  target: Side,
  source_label: String,
  source: Side,
  links: FileLinks,
) -> Element(msg) {
  case target.missing || source.missing || target.binary || source.binary {
    True -> side_by_side(target_label, target, source_label, source, links)
    False -> {
      let rows = aligned_rows(target.content, source.content)
      let conflict_lines =
        list.filter_map(rows, fn(row) {
          case row.changed {
            True -> Ok(row.number)
            False -> Error(Nil)
          }
        })
      div([attr.class("conflict-view")], [
        conflict_summary(conflict_lines),
        div(
          [attr.class("conflict-panels flex min-h-full flex-col lg:flex-row")],
          [
            segmented_panel(
              "border-slate-200 lg:border-r",
              target_label,
              rows,
              True,
              links.target_href,
            ),
            segmented_panel("", source_label, rows, False, links.source_href),
          ],
        ),
      ])
    }
  }
}

fn aligned_rows(
  target_content: String,
  source_content: String,
) -> List(AlignedRow) {
  let target_lines = string.split(target_content, on: "\n")
  let source_lines = string.split(source_content, on: "\n")
  let max_lines = int.max(list.length(target_lines), list.length(source_lines))
  list.map(inclusive_range(1, max_lines), fn(number) {
    let target = line_at(target_lines, number)
    let source = line_at(source_lines, number)
    AlignedRow(number:, target:, source:, changed: target != source)
  })
}

pub fn build_segments(rows: List(AlignedRow)) -> List(Segment) {
  let conflict_numbers =
    list.filter_map(rows, fn(row) {
      case row.changed {
        True -> Ok(row.number)
        False -> Error(Nil)
      }
    })
  let visible = visible_line_numbers(rows, conflict_numbers, context_padding)
  list.reverse(fold_segments(rows, visible, []))
}

fn visible_line_numbers(
  rows: List(AlignedRow),
  conflict_numbers: List(Int),
  padding: Int,
) -> List(Int) {
  list.fold(conflict_numbers, [], fn(acc, conflict_line) {
    list.append(acc, context_window(conflict_line, padding))
  })
  |> list.unique
  |> list.sort(int.compare)
  |> list.filter(fn(n) { list.any(rows, fn(row) { row.number == n }) })
}

fn context_window(center: Int, padding: Int) -> List(Int) {
  list.map(inclusive_range(center - padding, center + padding), fn(n) { n })
}

fn fold_segments(
  rows: List(AlignedRow),
  visible: List(Int),
  acc: List(Segment),
) -> List(Segment) {
  case rows {
    [] -> acc
    [row, ..rest] ->
      case list.contains(visible, row.number) {
        True -> {
          let #(visible_run, rest) = take_visible_run([row, ..rest], visible)
          fold_segments(rest, visible, [VisibleRows(visible_run), ..acc])
        }
        False -> {
          let #(hidden, rest) = take_hidden_run([row, ..rest], visible)
          case hidden {
            [] -> fold_segments(rest, visible, acc)
            _ -> {
              let count = list.length(hidden)
              let before = case list.last(hidden) {
                Ok(row) -> row.number + 1
                Error(_) -> 1
              }
              fold_segments(rest, visible, [
                Collapsed(count:, before_line: before),
                ..acc
              ])
            }
          }
        }
      }
  }
}

fn take_visible_run(
  rows: List(AlignedRow),
  visible: List(Int),
) -> #(List(AlignedRow), List(AlignedRow)) {
  case rows {
    [] -> #([], [])
    [row, ..rest] ->
      case list.contains(visible, row.number) {
        True -> {
          let #(more, tail) = take_visible_run(rest, visible)
          #([row, ..more], tail)
        }
        False -> #([], rows)
      }
  }
}

fn take_hidden_run(
  rows: List(AlignedRow),
  visible: List(Int),
) -> #(List(AlignedRow), List(AlignedRow)) {
  case rows {
    [] -> #([], [])
    [row, ..rest] ->
      case list.contains(visible, row.number) {
        False -> {
          let #(more, tail) = take_hidden_run(rest, visible)
          #([row, ..more], tail)
        }
        True -> #([], rows)
      }
  }
}

pub fn diff_parts(line: String, other: String) -> #(String, String, String) {
  case line == other {
    True -> #(line, "", "")
    False -> {
      let prefix_len = common_prefix_len(line, other)
      let line_suffix = string.drop_start(line, prefix_len)
      let other_suffix = string.drop_start(other, prefix_len)
      let suffix_len = common_suffix_len(line_suffix, other_suffix)
      let line_mid_len = string.length(line_suffix) - suffix_len
      #(
        string.slice(line, 0, prefix_len),
        string.slice(line, prefix_len, line_mid_len),
        string.drop_start(line, prefix_len + line_mid_len),
      )
    }
  }
}

fn common_prefix_len(a: String, b: String) -> Int {
  let a_graphemes = string.to_graphemes(a)
  let b_graphemes = string.to_graphemes(b)
  list.zip(a_graphemes, b_graphemes)
  |> list.take_while(fn(pair) {
    let #(left, right) = pair
    left == right
  })
  |> list.length
}

fn common_suffix_len(a: String, b: String) -> Int {
  common_prefix_len(string.reverse(a), string.reverse(b))
}

fn conflict_summary(conflict_lines: List(Int)) -> Element(msg) {
  case conflict_lines {
    [] -> div([], [])
    lines -> {
      let ranges = conflict_line_ranges(lines)
      let region_count = list.length(ranges)
      let line_count = list.length(lines)
      let summary = case line_count, region_count {
        1, 1 -> "1 conflicting line"
        1, _ ->
          "1 conflicting line in " <> int.to_string(region_count) <> " regions"
        n, 1 -> int.to_string(n) <> " conflicting lines"
        n, r ->
          int.to_string(n)
          <> " conflicting lines in "
          <> int.to_string(r)
          <> " regions"
      }
      let hidden_count = int.max(0, region_count - max_summary_ranges)
      let shown = list.take(ranges, max_summary_ranges)
      let link_items =
        list.map(shown, fn(range) {
          let #(start, end) = range
          a(
            [
              attr.href("#conflict-line-" <> int.to_string(start)),
              attr.class("conflict-summary-link"),
              attr.title("Jump to " <> range_label(start, end)),
            ],
            [text(range_label(start, end))],
          )
        })
      let more_item = case hidden_count {
        0 -> []
        n -> [
          span([attr.class("conflict-summary-more")], [
            text("+" <> int.to_string(n) <> " more"),
          ]),
        ]
      }
      div([attr.class("conflict-summary")], [
        span([attr.class("conflict-summary-label")], [text(summary)]),
        div(
          [attr.class("conflict-summary-links")],
          list.append(link_items, more_item),
        ),
      ])
    }
  }
}

fn segmented_panel(
  border_class: String,
  label: String,
  rows: List(AlignedRow),
  is_target: Bool,
  file_href: option.Option(String),
) -> Element(msg) {
  let segments = build_segments(rows)
  div(
    [
      attr.class(
        "conflict-panel flex min-w-0 flex-1 flex-col bg-white " <> border_class,
      ),
    ],
    [
      panel_header(label, file_href),
      div(
        [
          attr.class(
            "conflict-panel-body overflow-x-auto font-mono text-xs leading-5",
          ),
        ],
        [
          pre([attr.class("m-0 min-w-full")], [
            div(
              [],
              list.flat_map(segments, fn(segment) {
                render_segment(segment, is_target)
              }),
            ),
          ]),
        ],
      ),
    ],
  )
}

fn render_segment(segment: Segment, is_target: Bool) -> List(Element(msg)) {
  case segment {
    Collapsed(count, before_line) -> [
      div([attr.class("conflict-collapsed")], [
        span([], [
          text(
            "··· "
            <> int.to_string(count)
            <> " unchanged lines ("
            <> int.to_string(before_line - count)
            <> "-"
            <> int.to_string(before_line - 1)
            <> ") ···",
          ),
        ]),
      ]),
    ]
    VisibleRows(rows) ->
      list.map(rows, fn(row) {
        let line = case is_target {
          True -> row.target
          False -> row.source
        }
        let other = case is_target {
          True -> row.source
          False -> row.target
        }
        conflict_line_row(row.number, line, other, row.changed, is_target)
      })
  }
}

fn conflict_line_row(
  number: Int,
  line: String,
  other: String,
  changed: Bool,
  is_target: Bool,
) -> Element(msg) {
  let row_class = case changed, is_target {
    True, True -> " conflict-row conflict-row-target"
    True, False -> " conflict-row conflict-row-source"
    False, _ -> " conflict-row"
  }
  let gutter_class = case changed {
    True -> " conflict-gutter-changed"
    False -> " conflict-gutter"
  }
  let line_id = case changed {
    True -> [attr.id("conflict-line-" <> int.to_string(number))]
    False -> []
  }
  div(list.append(line_id, [attr.class("flex whitespace-pre" <> row_class)]), [
    span([attr.class(gutter_class)], [
      case changed {
        True ->
          span([attr.class("conflict-gutter-mark")], [
            text(int.to_string(number)),
          ])
        False -> text(int.to_string(number))
      },
    ]),
    span([attr.class("conflict-code")], [
      case changed {
        True -> inline_highlight(line, other, is_target)
        False -> text(line)
      },
    ]),
  ])
}

fn inline_highlight(
  line: String,
  other: String,
  is_target: Bool,
) -> Element(msg) {
  let #(prefix, middle, suffix) = diff_parts(line, other)
  let highlight_class = case is_target {
    True -> "conflict-inline-target"
    False -> "conflict-inline-source"
  }
  case middle {
    "" -> text(line)
    _ ->
      span([], [
        text(prefix),
        span([attr.class(highlight_class)], [text(middle)]),
        text(suffix),
      ])
  }
}

fn panel_header(
  label: String,
  file_href: option.Option(String),
) -> Element(msg) {
  div([attr.class("conflict-panel-header")], [
    span([attr.class("font-mono text-xs font-semibold text-gh-ink")], [
      text(label),
    ]),
    full_file_link(file_href),
  ])
}

fn full_file_link(href: option.Option(String)) -> Element(msg) {
  case href {
    option.None -> text("")
    option.Some(url) ->
      a(
        [
          attr.href(url),
          attr.class("conflict-full-file-link"),
          attr.title("Open the full file at this branch"),
        ],
        [text("View full file →")],
      )
  }
}

fn side_panel(
  border_class: String,
  label: String,
  side: Side,
  file_href: option.Option(String),
) -> Element(msg) {
  div(
    [
      attr.class(
        "conflict-panel flex min-w-0 flex-1 flex-col bg-white " <> border_class,
      ),
    ],
    [
      panel_header(label, file_href),
      case side.missing {
        True ->
          div([attr.class("px-4 py-8 text-sm italic text-gh-muted")], [
            text("File does not exist on this branch"),
          ])
        False ->
          case side.binary {
            True ->
              div([attr.class("px-4 py-8 text-sm italic text-gh-muted")], [
                text("Binary file - cannot display"),
              ])
            False -> side_lines(side.content)
          }
      },
    ],
  )
}

fn side_lines(content: String) -> Element(msg) {
  let lines = string.split(content, on: "\n")
  div(
    [
      attr.class(
        "conflict-panel-body overflow-x-auto font-mono text-xs leading-5",
      ),
    ],
    [
      pre([attr.class("m-0 min-w-full")], [
        div(
          [],
          list.index_map(lines, fn(line, index) { line_row(index + 1, line) }),
        ),
      ]),
    ],
  )
}

fn line_row(number: Int, line: String) -> Element(msg) {
  div([attr.class("conflict-row flex whitespace-pre")], [
    span([attr.class("conflict-gutter")], [text(int.to_string(number))]),
    span([attr.class("conflict-code")], [text(line)]),
  ])
}

fn line_at(lines: List(String), number: Int) -> String {
  case list.drop(lines, number - 1) {
    [line, ..] -> line
    _ -> ""
  }
}
