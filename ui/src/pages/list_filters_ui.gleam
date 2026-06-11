import components
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import http/list_query
import lustre/attribute as attr
import lustre/element.{type Element, text}
import lustre/element/html.{
  button, div, input, label, option as html_option, p, select, td, tr,
}
import lustre/event

pub fn toolbar(children: List(Element(msg))) -> Element(msg) {
  div([attr.class(components.comic_list_toolbar)], children)
}

pub fn main_row(
  state_tabs: Element(msg),
  search: Element(msg),
  sort: Element(msg),
) -> Element(msg) {
  div([attr.class("comic-list-toolbar-main")], [
    div([attr.class("comic-list-toolbar-tabs")], [state_tabs]),
    div([attr.class("comic-list-toolbar-search")], [search]),
    div([attr.class("comic-list-toolbar-sort")], [sort]),
  ])
}

pub fn search_hint(hint: String) -> Element(msg) {
  p([attr.class("comic-list-search-hint")], [text(hint)])
}

pub fn state_filter_tabs(
  tabs: List(#(String, String)),
  active: String,
  on_change: fn(String) -> msg,
) -> Element(msg) {
  div(
    [attr.class(components.comic_filter_tabs)],
    list.map(tabs, fn(tab) {
      let #(tab_label, value) = tab
      state_filter_tab(tab_label, value, active, on_change)
    }),
  )
}

fn state_filter_tab(
  tab_label: String,
  value: String,
  active: String,
  on_change: fn(String) -> msg,
) -> Element(msg) {
  let classes = case active == value {
    True -> components.comic_filter_tab_active
    False -> components.comic_filter_tab
  }
  button(
    [
      attr.type_("button"),
      attr.class(classes),
      event.on_click(on_change(value)),
    ],
    [text(tab_label)],
  )
}

pub fn search_input(
  placeholder: String,
  value: String,
  on_input: fn(String) -> msg,
  on_keydown: fn(String) -> msg,
) -> Element(msg) {
  div([attr.class("comic-list-search-wrap")], [
    label([attr.class("sr-only")], [text(placeholder)]),
    input([
      attr.type_("search"),
      attr.placeholder(placeholder),
      attr.value(value),
      attr.class(components.comic_list_search),
      event.on_input(on_input),
      event.on_keydown(on_keydown),
    ]),
  ])
}

pub fn sort_select(
  sort: String,
  order: String,
  on_change: fn(String, String) -> msg,
) -> Element(msg) {
  div([attr.class("comic-list-filter-field")], [
    label([attr.class("comic-list-filter-label")], [text("Sort")]),
    select(
      [
        attr.class(components.comic_list_search <> " comic-list-sort"),
        event.on_change(fn(value) {
          case string.split(value, ":") {
            [field, direction, ..] -> on_change(field, direction)
            _ -> on_change("number", "desc")
          }
        }),
      ],
      [
        sort_option("number", "desc", sort, order, "Newest first"),
        sort_option("number", "asc", sort, order, "Oldest first"),
        sort_option("updated", "desc", sort, order, "Recently updated"),
        sort_option("updated", "asc", sort, order, "Least recently updated"),
        sort_option("created", "desc", sort, order, "Recently created"),
        sort_option("created", "asc", sort, order, "Oldest created"),
      ],
    ),
  ])
}

fn sort_option(
  field: String,
  direction: String,
  active_sort: String,
  active_order: String,
  option_label: String,
) -> Element(msg) {
  html_option(
    [
      attr.value(field <> ":" <> direction),
      attr.selected(active_sort == field && active_order == direction),
    ],
    option_label,
  )
}

pub fn list_count_footer(count_text: String) -> Element(msg) {
  div([attr.class("comic-list-count-footer")], [
    p([attr.class(components.comic_list_count)], [text(count_text)]),
  ])
}

pub fn table_loading_row(colspan: Int) -> Element(msg) {
  tr([attr.class("comic-list-table-loading-row")], [
    td(
      [
        attr.attribute("colspan", int.to_string(colspan)),
        attr.class("comic-list-table-loading-cell"),
      ],
      [components.loading_spinner()],
    ),
  ])
}

pub fn table_empty_row(message: String, colspan: Int) -> Element(msg) {
  tr([attr.class("comic-list-table-empty-row")], [
    td(
      [
        attr.attribute("colspan", int.to_string(colspan)),
        attr.class("comic-list-table-empty-cell"),
      ],
      [text(message)],
    ),
  ])
}

pub fn count_label(
  shown: Int,
  total: Int,
  noun: String,
  filters_active: Bool,
) -> String {
  let suffix = case shown {
    1 -> ""
    _ -> "s"
  }
  case filters_active {
    False -> int.to_string(total) <> " " <> noun <> suffix
    True -> "Showing " <> int.to_string(shown) <> " of " <> int.to_string(total)
  }
}

pub fn filters_active_issue(filters: list_query.IssueListFilters) -> Bool {
  filters.state != "open"
  || filters.label_names != []
  || filters.milestone != option.None
  || filters.assignee != option.None
  || filters.author != option.None
  || string.trim(filters.q) != ""
  || filters.sort != "number"
  || filters.order != "desc"
}

pub fn filters_active_mr(filters: list_query.MergeRequestListFilters) -> Bool {
  filters.state != "open"
  || filters.label_names != []
  || filters.author != option.None
  || string.trim(filters.q) != ""
  || filters.source_branch != option.None
  || filters.target_branch != option.None
  || filters.sort != "number"
  || filters.order != "desc"
}
