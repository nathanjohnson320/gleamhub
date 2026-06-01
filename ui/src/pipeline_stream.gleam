@external(javascript, "./pipeline_stream_ffi.js", "subscribe")
pub fn subscribe(
  url: String,
  token: String,
  on_data on_data: fn(String) -> Nil,
  on_error on_error: fn() -> Nil,
) -> fn() -> Nil
