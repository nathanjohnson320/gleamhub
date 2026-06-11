import gleeunit
import util/time_format

pub fn main() {
  gleeunit.main()
}

pub fn invalid_unix_seconds_falls_back_to_timestamp_test() {
  assert time_format.format_commit_time("not-a-number") == "not-a-number"
  assert time_format.format_commit_time("2026-06-04 09:54:11.616329+00")
    != "2026-06-04 09:54:11.616329+00"
}

pub fn invalid_timestamp_passthrough_test() {
  assert time_format.format_timestamp("not-a-date") == "not-a-date"
}

pub fn postgres_timestamptz_formats_test() {
  assert time_format.format_timestamp("2026-06-04 09:54:11.616329+00")
    != "2026-06-04 09:54:11.616329+00"
  assert time_format.format_timestamp("2026-01-01T00:00:00Z")
    != "2026-01-01T00:00:00Z"
}
