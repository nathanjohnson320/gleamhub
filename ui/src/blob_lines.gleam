import lustre/effect.{type Effect}

@external(javascript, "./blob_lines_ffi.js", "init_blob_lines")
fn init_blob_lines_ffi() -> Nil

pub fn init_effect() -> Effect(a) {
  effect.from(fn(_) {
    init_blob_lines_ffi()
    Nil
  })
}
