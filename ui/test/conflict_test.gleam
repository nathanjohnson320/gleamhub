import diff/conflict
import gleam/int
import gleam/list
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn diff_parts_highlights_middle_test() {
  let #(prefix, middle, _suffix) =
    conflict.diff_parts(
      "**SQL changes:** edit `server/src/app/sql/*.sql` on main",
      "**SQL changes:** edit `server/src/sql/*.sql` on branch",
    )
  prefix |> should.equal("**SQL changes:** edit `server/src/")
  middle |> should.equal("app/sql/*.sql` on main")
}

pub fn build_segments_collapses_distant_context_test() {
  let rows =
    int.range(from: 1, to: 11, with: [], run: fn(acc, number) {
      let row = case number {
        8 ->
          conflict.AlignedRow(
            number:,
            target: "old",
            source: "new",
            changed: True,
          )
        _ ->
          conflict.AlignedRow(
            number:,
            target: "same",
            source: "same",
            changed: False,
          )
      }
      list.append(acc, [row])
    })
  let segments = conflict.build_segments(rows)
  list.any(segments, fn(segment) {
    case segment {
      conflict.Collapsed(count:, ..) if count >= 4 -> True
      _ -> False
    }
  })
  |> should.be_true
}

pub fn conflict_line_ranges_groups_consecutive_test() {
  conflict.conflict_line_ranges([1, 2, 3, 10, 11, 20])
  |> should.equal([#(1, 3), #(10, 11), #(20, 20)])
}

pub fn conflict_line_ranges_single_test() {
  conflict.conflict_line_ranges([42]) |> should.equal([#(42, 42)])
}
