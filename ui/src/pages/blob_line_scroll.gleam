import gleam/option
import lustre/effect.{type Effect, from, none}

@external(javascript, "./blob_line_scroll_ffi.js", "scroll_to_line_after_paint")
fn scroll_to_line_after_paint_ffi(line: Int) -> Nil

pub fn scroll_effect(line_range: option.Option(#(Int, Int))) -> Effect(a) {
  case line_range {
    option.Some(#(start, _)) ->
      from(fn(_) {
        scroll_to_line_after_paint_ffi(start)
        Nil
      })
    option.None -> none()
  }
}
