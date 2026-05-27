import diff_view
import gleam/list
import gleam/option
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

const sample_patch =
  "@@ -1,3 +1,6 @@
 line1
+added
 context
-old
+new"

pub fn parse_hunk_add_line_number_test() {
  let lines = diff_view.parse_patch(sample_patch)
  let assert Ok(add) =
    list.find(lines, fn(l) {
      case l {
        diff_view.DiffLine(kind: diff_view.Add, text: "+added", ..) -> True
        _ -> False
      }
    })
  add.new_line |> should.equal(option.Some(2))
}

pub fn parse_hunk_context_line_number_test() {
  let lines = diff_view.parse_patch(sample_patch)
  let assert Ok(ctx) =
    list.find(lines, fn(l) {
      case l {
        diff_view.DiffLine(kind: diff_view.Context, ..) -> True
        _ -> False
      }
    })
  ctx.new_line |> should.equal(option.Some(1))
}

pub fn parse_hunk_delete_has_no_new_line_test() {
  let lines = diff_view.parse_patch(sample_patch)
  let assert Ok(del) =
    list.find(lines, fn(l) {
      case l {
        diff_view.DiffLine(kind: diff_view.Delete, ..) -> True
        _ -> False
      }
    })
  del.new_line |> should.equal(option.None)
  del.old_line |> should.equal(option.Some(3))
}

pub fn commentable_new_line_test() {
  let lines = diff_view.parse_patch(sample_patch)
  let assert Ok(add) =
    list.find(lines, fn(l) {
      case l {
        diff_view.DiffLine(kind: diff_view.Add, ..) -> True
        _ -> False
      }
    })
  diff_view.commentable_new_line(add) |> should.equal(option.Some(2))
}
