import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import wisp.{type Request}

pub type IssueListQuery {
  IssueListQuery(
    state: String,
    label_ids: List(String),
    milestone_id: Option(String),
    assignee: Option(String),
    author: Option(String),
    q: Option(String),
    sort: String,
    order: String,
  )
}

pub type MergeRequestListQuery {
  MergeRequestListQuery(
    state: String,
    label_ids: List(String),
    author: Option(String),
    q: Option(String),
    source_branch: Option(String),
    target_branch: Option(String),
    sort: String,
    order: String,
  )
}

pub type ParseError {
  InvalidState
  InvalidSort
  InvalidOrder
  UnknownLabel(String)
  UnknownMilestone(String)
}

pub fn parse_issue_list_query(req: Request) -> Result(IssueListQuery, ParseError) {
  use state <- result.try(parse_state(
    query_param(req, "state"),
    ["open", "closed", "all"],
    "open",
  ))
  use sort <- result.try(parse_sort(
    query_param(req, "sort"),
    ["number", "created", "updated"],
    "number",
  ))
  use order <- result.try(parse_order(query_param(req, "order"), "desc"))
  let q = optional_trimmed(query_param(req, "q"))
  let assignee = optional_trimmed(query_param(req, "assignee"))
  let author = optional_trimmed(query_param(req, "author"))
  Ok(IssueListQuery(
    state:,
    label_ids: [],
    milestone_id: option.None,
    assignee:,
    author:,
    q:,
    sort:,
    order:,
  ))
}

pub fn parse_merge_request_list_query(
  req: Request,
) -> Result(MergeRequestListQuery, ParseError) {
  use state <- result.try(parse_state(
    query_param(req, "state"),
    ["open", "closed", "merged", "all"],
    "open",
  ))
  use sort <- result.try(parse_sort(
    query_param(req, "sort"),
    ["number", "created", "updated"],
    "number",
  ))
  use order <- result.try(parse_order(query_param(req, "order"), "desc"))
  let q = optional_trimmed(query_param(req, "q"))
  let author = optional_trimmed(query_param(req, "author"))
  let source_branch = optional_trimmed(query_param(req, "source_branch"))
  let target_branch = optional_trimmed(query_param(req, "target_branch"))
  Ok(MergeRequestListQuery(
    state:,
    label_ids: [],
    author:,
    q:,
    source_branch:,
    target_branch:,
    sort:,
    order:,
  ))
}

pub fn label_params(req: Request) -> List(String) {
  query_params(req, "label")
  |> list.filter_map(fn(value) {
    case string.trim(value) {
      "" -> Error(Nil)
      trimmed -> Ok(trimmed)
    }
  })
  |> list.unique
}

fn query_param(req: Request, key: String) -> String {
  case list.find(wisp.get_query(req), fn(pair) { pair.0 == key }) {
    Ok(#(_, value)) -> value
    Error(_) -> ""
  }
}

fn query_params(req: Request, key: String) -> List(String) {
  wisp.get_query(req)
  |> list.filter_map(fn(pair) {
    case pair {
      #(k, v) if k == key -> Ok(v)
      _ -> Error(Nil)
    }
  })
}

fn optional_trimmed(value: String) -> Option(String) {
  case string.trim(value) {
    "" -> option.None
    trimmed -> option.Some(trimmed)
  }
}

fn parse_state(
  value: String,
  allowed: List(String),
  default: String,
) -> Result(String, ParseError) {
  case string.trim(value) {
    "" -> Ok(default)
    trimmed ->
      case list.contains(allowed, trimmed) {
        True -> Ok(trimmed)
        False -> Error(InvalidState)
      }
  }
}

fn parse_sort(
  value: String,
  allowed: List(String),
  default: String,
) -> Result(String, ParseError) {
  case string.trim(value) {
    "" -> Ok(default)
    trimmed ->
      case list.contains(allowed, trimmed) {
        True -> Ok(trimmed)
        False -> Error(InvalidSort)
      }
  }
}

fn parse_order(value: String, default: String) -> Result(String, ParseError) {
  case string.trim(value) {
    "" -> Ok(default)
    "asc" -> Ok("asc")
    "desc" -> Ok("desc")
    _ -> Error(InvalidOrder)
  }
}

pub fn resolve_label_ids(
  labels: List(#(String, String)),
  params: List(String),
) -> Result(List(String), ParseError) {
  case params {
    [] -> Ok([])
    _ ->
      list.try_map(params, fn(param) {
        resolve_one_label(labels, param)
      })
  }
}

fn resolve_one_label(
  labels: List(#(String, String)),
  param: String,
) -> Result(String, ParseError) {
  case list.find(labels, fn(label) {
    let #(id, name) = label
    id == param || string.lowercase(name) == string.lowercase(param)
  }) {
    Ok(#(id, _)) -> Ok(id)
    Error(_) -> Error(UnknownLabel(param))
  }
}

pub fn milestone_param(req: Request) -> Option(String) {
  optional_trimmed(query_param(req, "milestone"))
}

pub fn parse_error_message(error: ParseError) -> String {
  case error {
    InvalidState -> "Invalid state filter"
    InvalidSort -> "Invalid sort field"
    InvalidOrder -> "Invalid sort order"
    UnknownLabel(name) -> "Unknown label: " <> name
    UnknownMilestone(name) -> "Unknown milestone: " <> name
  }
}
