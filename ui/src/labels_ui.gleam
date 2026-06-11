import gleam/int
import gleam/list
import gleam/option
import gleam/string
import http/api.{type IssueAssignee, type Label, IssueAssignee}

pub type AssigneeOption {
  AssigneeOption(user_id: String, name: String)
}

import lustre/attribute as attr
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, input, li, p, span, ul}
import lustre/event

const popover_class =
  "comic-dropdown absolute right-0 z-40 mt-1 w-56 overflow-hidden py-1"

const popover_wide_class =
  "comic-dropdown absolute right-0 z-40 mt-1 w-full min-w-[14rem] overflow-hidden py-1"

const search_input_class =
  "block w-full border-0 border-b-[3px] border-gh-ink bg-white px-3 py-2 text-sm font-medium text-gh-ink outline-none placeholder:text-gh-muted"

const empty_item_class = "px-3 py-2 text-sm font-medium text-gh-muted"

const menu_item_class = "mr-event-menu-item flex w-full items-center gap-2"

const edit_link_class =
  "shrink-0 text-xs font-black uppercase tracking-wide text-gh-accent hover:text-gh-accent-hover hover:underline"

pub const default_label_color = "#d73a4a"

const color_picker_class = "h-10 w-14 cursor-pointer rounded-md border border-slate-300 bg-white p-1"

pub fn color_picker_value(color: String) -> String {
  let trimmed = string.lowercase(string.trim(color))
  case string.length(trimmed) {
    7 ->
      case string.starts_with(trimmed, "#") {
        True -> trimmed
        False -> default_label_color
      }
    _ -> default_label_color
  }
}

pub fn label_color_picker(
  color: String,
  on_change: fn(String) -> msg,
) -> Element(msg) {
  input([
    attr.type_("color"),
    attr.class(color_picker_class),
    attr.value(color_picker_value(color)),
    attr.title("Label color"),
    event.on_input(on_change),
  ])
}

fn matches_filter(query: String, haystack: String) -> Bool {
  let needle = string.lowercase(string.trim(query))
  case needle {
    "" -> True
    _ -> string.contains(string.lowercase(haystack), needle)
  }
}

pub fn label_badge(label: Label) -> Element(msg) {
  span(
    [
      attr.class(
        "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium text-white",
      ),
      attr.style("background-color", label.color),
    ],
    [text(label.name)],
  )
}

pub fn label_badges(labels: List(Label)) -> Element(msg) {
  case labels {
    [] -> text("")
    _ ->
      div([attr.class("flex flex-wrap gap-1.5")], list.map(labels, label_badge))
  }
}

fn selection_checkbox(selected: Bool) -> Element(msg) {
  let classes =
    "flex h-4 w-4 shrink-0 items-center justify-center rounded border text-[10px] font-bold leading-none "
    <> case selected {
      True -> "border-gh-accent bg-gh-accent text-white"
      False -> "border-gh-ink bg-white text-transparent"
    }
  span([attr.class(classes)], [text("✓")])
}

fn edit_menu_button(open: Bool, label: String, on_click: msg) -> Element(msg) {
  button(
    [
      attr.type_("button"),
      attr.class(edit_link_class),
      event.on_click(on_click),
    ],
    [
      text(case open {
        True -> "Done"
        False -> label
      }),
    ],
  )
}

fn filter_labels(labels: List(Label), query: String) -> List(Label) {
  list.filter(labels, fn(label) { matches_filter(query, label.name) })
}

fn label_menu_item(
  label: Label,
  selected: Bool,
  on_toggle: msg,
) -> Element(msg) {
  button(
    [
      attr.type_("button"),
      attr.class(menu_item_class),
      event.on_click(on_toggle),
    ],
    [
      selection_checkbox(selected),
      label_badge(label),
    ],
  )
}

fn search_popover(
  query: String,
  placeholder: String,
  on_query: fn(String) -> msg,
  items: List(Element(msg)),
  empty_message: String,
  wide: Bool,
) -> Element(msg) {
  let pop_class = case wide {
    True -> popover_wide_class
    False -> popover_class
  }
  let rows = case items {
    [] -> [li([attr.class(empty_item_class)], [text(empty_message)])]
    _ -> items
  }
  div([attr.class(pop_class)], [
    input([
      attr.type_("text"),
      attr.class(search_input_class),
      attr.placeholder(placeholder),
      attr.value(query),
      event.on_input(on_query),
    ]),
    ul([attr.class("max-h-48 list-none overflow-y-auto py-1")], rows),
  ])
}

/// Sidebar labels: show applied badges, open menu to search and toggle.
pub fn searchable_label_field(
  repo_labels: List(Label),
  selected: List(Label),
  open: Bool,
  query: String,
  on_toggle_menu: msg,
  on_query: fn(String) -> msg,
  on_toggle_label: fn(String) -> msg,
) -> Element(msg) {
  let selected_ids = list.map(selected, fn(label) { label.id })
  let filtered = filter_labels(repo_labels, query)
  let menu_items =
    list.map(filtered, fn(label) {
      let is_selected = list.contains(selected_ids, label.id)
      li([], [
        label_menu_item(label, is_selected, on_toggle_label(label.id)),
      ])
    })
  let empty_message = case repo_labels {
    [] -> "No labels in this repository yet."
    _ -> "No labels match your search."
  }
  div([attr.class("relative")], [
    div([attr.class("flex items-start justify-between gap-2")], [
      div([attr.class("min-w-0 flex-1")], [
        case selected {
          [] -> p([attr.class("text-sm text-gh-muted")], [text("None yet")])
          _ -> label_badges(selected)
        },
      ]),
      edit_menu_button(open, "Edit", on_toggle_menu),
    ]),
    case open {
      True ->
        search_popover(
          query,
          "Search labels…",
          on_query,
          menu_items,
          empty_message,
          False,
        )
      False -> text("")
    },
  ])
}

fn filter_assignee_options(
  members: List(AssigneeOption),
  query: String,
) -> List(AssigneeOption) {
  list.filter(members, fn(member) { matches_filter(query, member.name) })
}

fn assignee_menu_item(
  member: AssigneeOption,
  selected: Bool,
  on_toggle: msg,
) -> Element(msg) {
  button(
    [
      attr.type_("button"),
      attr.class(menu_item_class),
      event.on_click(on_toggle),
    ],
    [
      selection_checkbox(selected),
      span([attr.class("truncate")], [text(member.name)]),
    ],
  )
}

fn assignee_options_to_badges(
  members: List(AssigneeOption),
) -> List(IssueAssignee) {
  list.map(members, fn(member) {
    IssueAssignee(user_id: member.user_id, display_name: member.name)
  })
}

fn assign_yourself_prompt(
  current_user_id: option.Option(String),
  selected_ids: List(String),
  on_assign_self: fn(String) -> msg,
) -> Element(msg) {
  case current_user_id {
    option.None ->
      p([attr.class("text-sm text-gh-muted")], [text("No one assigned")])
    option.Some(user_id) ->
      case list.contains(selected_ids, user_id) {
        True ->
          p([attr.class("text-sm text-gh-muted")], [text("No one assigned")])
        False ->
          p([attr.class("text-sm text-gh-muted")], [
            text("No one-"),
            button(
              [
                attr.type_("button"),
                attr.class(edit_link_class <> " !inline"),
                event.on_click(on_assign_self(user_id)),
              ],
              [text("assign yourself")],
            ),
          ])
      }
  }
}

/// Sidebar assignees: show applied names, open menu to search and toggle.
pub fn searchable_assignee_field(
  org_members: List(AssigneeOption),
  selected_ids: List(String),
  open: Bool,
  query: String,
  current_user_id: option.Option(String),
  on_toggle_menu: msg,
  on_query: fn(String) -> msg,
  on_toggle_assignee: fn(String) -> msg,
) -> Element(msg) {
  let selected =
    list.filter(org_members, fn(member) {
      list.contains(selected_ids, member.user_id)
    })
  let filtered = filter_assignee_options(org_members, query)
  let menu_items =
    list.map(filtered, fn(member) {
      let is_selected = list.contains(selected_ids, member.user_id)
      li([], [
        assignee_menu_item(
          member,
          is_selected,
          on_toggle_assignee(member.user_id),
        ),
      ])
    })
  let empty_message = case org_members {
    [] -> "No members to assign."
    _ -> "No users match your search."
  }
  div([attr.class("relative")], [
    div([attr.class("flex items-start justify-between gap-2")], [
      div([attr.class("min-w-0 flex-1")], [
        case selected {
          [] ->
            assign_yourself_prompt(
              current_user_id,
              selected_ids,
              on_toggle_assignee,
            )
          _ -> assignee_badges(assignee_options_to_badges(selected))
        },
      ]),
      case org_members {
        [] -> text("")
        _ -> edit_menu_button(open, "Edit", on_toggle_menu)
      },
    ]),
    case open, org_members {
      True, [_, ..] ->
        search_popover(
          query,
          "Search users…",
          on_query,
          menu_items,
          empty_message,
          False,
        )
      False, _ -> text("")
      _, [] -> text("")
    },
  ])
}

/// Compact right-column block (GitHub-style issue/MR sidebar).
pub fn sidebar_section(title: String, body: Element(msg)) -> Element(msg) {
  div([attr.class("comic-panel-inset space-y-2 p-3")], [
    p([attr.class("text-xs font-black uppercase tracking-widest text-gh-ink")], [
      text(title),
    ]),
    body,
  ])
}

pub type MilestoneOption {
  MilestoneOption(id: String, number: Int, title: String)
}

fn milestone_label(milestone: MilestoneOption) -> String {
  "#" <> int.to_string(milestone.number) <> " " <> milestone.title
}

fn filter_milestones(
  milestones: List(MilestoneOption),
  query: String,
) -> List(MilestoneOption) {
  list.filter(milestones, fn(milestone) {
    matches_filter(query, milestone.title)
    || matches_filter(query, int.to_string(milestone.number))
  })
}

fn milestone_menu_item(
  label: String,
  selected: Bool,
  on_select: msg,
) -> Element(msg) {
  button(
    [
      attr.type_("button"),
      attr.class(menu_item_class),
      event.on_click(on_select),
    ],
    [
      selection_checkbox(selected),
      span([attr.class("truncate")], [text(label)]),
    ],
  )
}

/// Sidebar milestone: show current milestone, open menu to search and pick one.
pub fn searchable_milestone_field(
  milestones: List(MilestoneOption),
  selected: option.Option(MilestoneOption),
  open: Bool,
  query: String,
  on_toggle_menu: msg,
  on_query: fn(String) -> msg,
  on_select: fn(String) -> msg,
) -> Element(msg) {
  let selected_id = case selected {
    option.Some(milestone) -> milestone.id
    option.None -> ""
  }
  let filtered = filter_milestones(milestones, query)
  let clear_item =
    li([], [
      milestone_menu_item(
        "No milestone",
        selected_id == "",
        on_select(""),
      ),
    ])
  let menu_items =
    list.map(filtered, fn(milestone) {
      li([], [
        milestone_menu_item(
          milestone_label(milestone),
          selected_id == milestone.id,
          on_select(milestone.id),
        ),
      ])
    })
  let empty_message = case milestones {
    [] -> "No milestones in this repository yet."
    _ -> "No milestones match your search."
  }
  div([attr.class("relative")], [
    div([attr.class("flex items-start justify-between gap-2")], [
      div([attr.class("min-w-0 flex-1")], [
        case selected {
          option.None ->
            p([attr.class("text-sm text-gh-muted")], [text("No milestone")])
          option.Some(milestone) ->
            span([attr.class("comic-badge inline-flex px-2 py-0.5 text-xs font-bold")], [
              text(milestone_label(milestone)),
            ])
        },
      ]),
      case milestones {
        [] -> text("")
        _ -> edit_menu_button(open, "Edit", on_toggle_menu)
      },
    ]),
    case open, milestones {
      True, [_, ..] ->
        search_popover(
          query,
          "Search milestones…",
          on_query,
          list.append([clear_item], menu_items),
          empty_message,
          False,
        )
      False, _ -> text("")
      _, [] -> text("")
    },
  ])
}

pub type IssueLinkOption {
  IssueLinkOption(number: Int, title: String)
}

fn filter_issue_links(
  issues: List(IssueLinkOption),
  query: String,
) -> List(IssueLinkOption) {
  list.filter(issues, fn(issue) {
    matches_filter(query, issue.title)
    || matches_filter(query, int.to_string(issue.number))
  })
}

fn issue_link_menu_item(issue: IssueLinkOption, on_select: msg) -> Element(msg) {
  button(
    [
      attr.type_("button"),
      attr.class(menu_item_class),
      event.on_click(on_select),
    ],
    [
      span([attr.class("comic-issue-num shrink-0")], [
        text("#" <> int.to_string(issue.number)),
      ]),
      span([attr.class("truncate")], [text(issue.title)]),
    ],
  )
}

/// Searchable menu to pick an issue (e.g. add to a milestone).
pub fn searchable_issue_link_field(
  issues: List(IssueLinkOption),
  open: Bool,
  query: String,
  empty_message: String,
  on_toggle_menu: msg,
  on_query: fn(String) -> msg,
  on_select: fn(Int) -> msg,
) -> Element(msg) {
  let filtered = filter_issue_links(issues, query)
  let menu_items =
    list.map(filtered, fn(issue) {
      li([], [issue_link_menu_item(issue, on_select(issue.number))])
    })
  div([attr.class("relative")], [
    div([attr.class("flex justify-end")], [
      edit_menu_button(open, "Add issues", on_toggle_menu),
    ]),
    case open {
      True ->
        search_popover(
          query,
          "Search issues…",
          on_query,
          menu_items,
          empty_message,
          True,
        )
      False -> text("")
    },
  ])
}

pub fn assignee_badges(assignees: List(IssueAssignee)) -> Element(msg) {
  case assignees {
    [] -> text("")
    _ ->
      div(
        [attr.class("flex flex-wrap gap-1.5")],
        list.map(assignees, fn(assignee) {
          span(
            [
              attr.class(
                "inline-flex items-center rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-slate-700 ring-1 ring-inset ring-slate-200",
              ),
            ],
            [text(assignee.display_name)],
          )
        }),
      )
  }
}
