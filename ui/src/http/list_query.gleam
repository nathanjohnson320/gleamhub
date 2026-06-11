import gleam/list
import gleam/option.{type Option}
import gleam/string
import gleam/uri

pub type IssueListFilters {
  IssueListFilters(
    state: String,
    label_names: List(String),
    milestone: Option(String),
    assignee: Option(String),
    author: Option(String),
    q: String,
    sort: String,
    order: String,
  )
}

pub type MergeRequestListFilters {
  MergeRequestListFilters(
    state: String,
    label_names: List(String),
    author: Option(String),
    q: String,
    source_branch: Option(String),
    target_branch: Option(String),
    sort: String,
    order: String,
  )
}

pub fn default_issue_filters() -> IssueListFilters {
  IssueListFilters(
    state: "open",
    label_names: [],
    milestone: option.None,
    assignee: option.None,
    author: option.None,
    q: "",
    sort: "number",
    order: "desc",
  )
}

pub fn default_merge_request_filters() -> MergeRequestListFilters {
  MergeRequestListFilters(
    state: "open",
    label_names: [],
    author: option.None,
    q: "",
    source_branch: option.None,
    target_branch: option.None,
    sort: "number",
    order: "desc",
  )
}

fn label_params(names: List(String)) -> List(#(String, String)) {
  list.map(names, fn(name) { #("label", name) })
}

pub fn issue_list_query(filters: IssueListFilters) -> String {
  build_query(
    list.append(
      [
        #("state", filters.state),
        optional_param("milestone", filters.milestone),
        optional_param("assignee", filters.assignee),
        optional_param("author", filters.author),
        trimmed_param("q", filters.q),
        #("sort", filters.sort),
        #("order", filters.order),
      ],
      label_params(filters.label_names),
    ),
  )
}

pub fn merge_request_list_query(filters: MergeRequestListFilters) -> String {
  build_query(
    list.append(
      [
        #("state", filters.state),
        optional_param("author", filters.author),
        trimmed_param("q", filters.q),
        optional_param("source_branch", filters.source_branch),
        optional_param("target_branch", filters.target_branch),
        #("sort", filters.sort),
        #("order", filters.order),
      ],
      label_params(filters.label_names),
    ),
  )
}

fn build_query(pairs: List(#(String, String))) -> String {
  let active =
    list.filter(pairs, fn(pair) {
      let #(_, value) = pair
      value != ""
    })
  case active {
    [] -> ""
    _ -> "?" <> string.join(list.map(active, encode_pair), "&")
  }
}

fn encode_pair(pair: #(String, String)) -> String {
  let #(key, value) = pair
  uri.percent_encode(key) <> "=" <> uri.percent_encode(value)
}

fn optional_param(key: String, value: Option(String)) -> #(String, String) {
  case value {
    option.None -> #(key, "")
    option.Some(v) -> #(key, v)
  }
}

fn trimmed_param(key: String, value: String) -> #(String, String) {
  #(key, string.trim(value))
}

pub fn toggle_label_names(names: List(String), name: String) -> List(String) {
  case list.contains(names, name) {
    True -> list.filter(names, fn(existing) { existing != name })
    False -> list.append(names, [name])
  }
}

pub fn sort_label(sort: String, order: String) -> String {
  let field = case sort {
    "created" -> "Created"
    "updated" -> "Updated"
    _ -> "Number"
  }
  let direction = case order {
    "asc" -> "ascending"
    _ -> "descending"
  }
  field <> " (" <> direction <> ")"
}

pub fn next_sort_order(current_sort: String, current_order: String, sort: String) -> String {
  case current_sort == sort, current_order {
    True, "desc" -> "asc"
    _, _ -> "desc"
  }
}

pub fn issue_filters_equal(a: IssueListFilters, b: IssueListFilters) -> Bool {
  a.state == b.state
  && a.label_names == b.label_names
  && a.milestone == b.milestone
  && a.assignee == b.assignee
  && a.author == b.author
  && a.q == b.q
  && a.sort == b.sort
  && a.order == b.order
}

pub fn merge_request_filters_equal(
  a: MergeRequestListFilters,
  b: MergeRequestListFilters,
) -> Bool {
  a.state == b.state
  && a.label_names == b.label_names
  && a.author == b.author
  && a.q == b.q
  && a.source_branch == b.source_branch
  && a.target_branch == b.target_branch
  && a.sort == b.sort
  && a.order == b.order
}
