import gleam/float
import gleam/int
import gleam/option
import gleam/string
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}

/// Format a Unix-seconds string as a relative or calendar time.
pub fn format_commit_time(unix_seconds: String) -> String {
  case int.parse(unix_seconds) {
    Ok(seconds) -> format_relative(timestamp.from_unix_seconds(seconds))
    Error(_) -> format_timestamp(unix_seconds)
  }
}

/// Format an RFC3339-ish timestamp string from the API.
pub fn format_timestamp(value: String) -> String {
  case parse_timestamp(value) {
    option.Some(ts) -> format_relative(ts)
    option.None -> value
  }
}

fn parse_timestamp(value: String) -> option.Option(Timestamp) {
  case try_parse_rfc3339(value) {
    option.Some(ts) -> option.Some(ts)
    option.None ->
      case try_parse_rfc3339(normalize_postgres_timestamp(value)) {
        option.Some(ts) -> option.Some(ts)
        option.None -> try_parse_rfc3339(string.replace(value, " ", "T"))
      }
  }
}

fn try_parse_rfc3339(value: String) -> option.Option(Timestamp) {
  case timestamp.parse_rfc3339(value) {
    Ok(ts) -> option.Some(ts)
    Error(_) -> option.None
  }
}

/// PostgreSQL `timestamptz::text` uses a space separator and short offsets
/// like `+00` instead of RFC 3339's `+00:00` or `Z`.
fn normalize_postgres_timestamp(value: String) -> String {
  let value = string.trim(value)

  case string.ends_with(value, "+00") {
    True -> {
      let without_offset = string.slice(value, 0, string.length(value) - 3)
      string.replace(without_offset, " ", "T") <> "Z"
    }
    False -> {
      let value = string.replace(value, " ", "T")
      case string.split_once(value, on: "+") {
        Ok(#(prefix, offset)) ->
          case string.length(offset) {
            2 -> prefix <> "+" <> offset <> ":00"
            _ -> value
          }
        Error(_) -> expand_negative_offset(value)
      }
    }
  }
}

fn expand_negative_offset(value: String) -> String {
  case string.split_once(value, on: "T") {
    Ok(#(date, time)) -> {
      case string.split_once(time, on: "-") {
        Ok(#(time_part, offset)) ->
          case string.length(offset) {
            2 -> date <> "T" <> time_part <> "-" <> offset <> ":00"
            _ -> value
          }
        Error(_) -> value
      }
    }
    Error(_) -> value
  }
}

fn format_relative(at: Timestamp) -> String {
  let now = timestamp.system_time()
  let diff = timestamp.difference(at, now)
  let diff_sec = float.round(duration.to_seconds(diff))

  case diff_sec < 0 {
    True -> format_calendar_date(at)
    False ->
      case diff_sec {
        s if s < 60 -> "just now"
        s if s < 3600 -> format_count(s / 60, "minute", "minutes")
        s if s < 86_400 -> format_count(s / 3600, "hour", "hours")
        s if s < 86_400 * 30 -> format_count(s / 86_400, "day", "days")
        _ -> format_calendar_date(at)
      }
  }
}

fn format_count(amount: Int, singular: String, plural: String) -> String {
  case amount {
    1 -> "1 " <> singular <> " ago"
    n -> int.to_string(n) <> " " <> plural <> " ago"
  }
}

fn format_calendar_date(at: Timestamp) -> String {
  let #(date, _) = timestamp.to_calendar(at, calendar.utc_offset)
  int.to_string(date.day)
  <> " "
  <> short_month(date.month)
  <> " "
  <> int.to_string(date.year)
}

fn short_month(month: calendar.Month) -> String {
  case month {
    calendar.January -> "Jan"
    calendar.February -> "Feb"
    calendar.March -> "Mar"
    calendar.April -> "Apr"
    calendar.May -> "May"
    calendar.June -> "Jun"
    calendar.July -> "Jul"
    calendar.August -> "Aug"
    calendar.September -> "Sep"
    calendar.October -> "Oct"
    calendar.November -> "Nov"
    calendar.December -> "Dec"
  }
}
