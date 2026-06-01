import lustre/effect.{type Effect, from}

/// Schedule `dispatch(msg)` after `ms` milliseconds (browser only).
pub fn after_ms(msg: msg, ms: Int) -> Effect(msg) {
  from(fn(dispatch) {
    schedule(ms, fn() { dispatch(msg) })
  })
}

@external(javascript, "./poll_ffi.js", "schedule")
fn schedule(ms: Int, f: fn() -> Nil) -> Nil
