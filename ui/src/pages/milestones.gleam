import components
import config.{type Config}
import labels_ui
import content/markdown
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import http/api.{type Issue, type Milestone}
import http/list_query
import http/lustre_http
import lustre/attribute as attr
import lustre/effect.{type Effect, batch, none}
import lustre/element.{type Element, text, unsafe_raw_html}
import lustre/element/html.{
  a, button, div, form, h2, input, label, li, p, span, textarea, ul,
}
import lustre/event
import modem
import pages/repo_nav
import routes.{
  issue_detail_path, milestone_detail_path, milestone_list_path,
  milestone_new_path,
}

pub type Mode {
  List
  New
  Detail(Int)
}

pub type Model {
  Model(
    org_slug: String,
    repo_name: String,
    mode: Mode,
    milestones: List(Milestone),
    detail: option.Option(Milestone),
    detail_issues: List(Issue),
    repo_issues: List(Issue),
    add_issues_menu_open: Bool,
    add_issues_filter: String,
    title: String,
    description: String,
    due_on: String,
    editing: Bool,
    edit_title: String,
    edit_description: String,
    edit_due_on: String,
    saving: Bool,
    loading: Bool,
    error: option.Option(String),
  )
}

pub type Msg {
  MilestonesLoaded(Result(List(Milestone), lustre_http.HttpError))
  DetailLoaded(Result(Milestone, lustre_http.HttpError))
  DetailIssuesLoaded(Result(List(Issue), lustre_http.HttpError))
  RepoIssuesLoaded(Result(List(Issue), lustre_http.HttpError))
  ToggleAddIssuesMenu
  AddIssuesFilterChanged(String)
  AssignIssue(Int)
  IssueAssigned(Result(Issue, lustre_http.HttpError))
  TitleChanged(String)
  DescriptionChanged(String)
  DueOnChanged(String)
  Create
  Created(Result(Milestone, lustre_http.HttpError))
  StartEdit
  CancelEdit
  EditTitleChanged(String)
  EditDescriptionChanged(String)
  EditDueOnChanged(String)
  SaveEdit
  Saved(Result(Milestone, lustre_http.HttpError))
  CloseMilestone
  Closed(Result(Milestone, lustre_http.HttpError))
}

pub fn init(org_slug: String, repo_name: String, mode: Mode) -> Model {
  Model(
    org_slug:,
    repo_name:,
    mode:,
    milestones: [],
    detail: option.None,
    detail_issues: [],
    repo_issues: [],
    add_issues_menu_open: False,
    add_issues_filter: "",
    title: "",
    description: "",
    due_on: "",
    editing: False,
    edit_title: "",
    edit_description: "",
    edit_due_on: "",
    saving: False,
    loading: True,
    error: option.None,
  )
}

fn api_base(config: Config, model: Model) -> String {
  config.api_url
  <> "/api/orgs/"
  <> model.org_slug
  <> "/repos/"
  <> model.repo_name
}

fn load_milestones(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model) <> "/milestones",
    lustre_http.expect_json(api.milestones_decoder(), MilestonesLoaded),
  )
}

fn load_detail(config: Config, model: Model, number: Int) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model) <> "/milestones/" <> int.to_string(number),
    lustre_http.expect_json(api.milestone_decoder(), DetailLoaded),
  )
}

fn load_repo_issues(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model)
      <> "/issues"
      <> list_query.issue_list_query(list_query.default_issue_filters()),
    lustre_http.expect_json(api.issues_decoder(), RepoIssuesLoaded),
  )
}

fn load_detail_issues(config: Config, model: Model, number: Int) -> Effect(Msg) {
  let filters =
    list_query.IssueListFilters(
      ..list_query.default_issue_filters(),
      state: "all",
      milestone: option.Some(int.to_string(number)),
    )
  lustre_http.get(
    config,
    api_base(config, model)
      <> "/issues"
      <> list_query.issue_list_query(filters),
    lustre_http.expect_json(api.issues_decoder(), DetailIssuesLoaded),
  )
}

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  case model.mode {
    List -> load_milestones(config, model)
    New -> load_milestones(config, model)
    Detail(number) ->
      batch([
        load_detail(config, model, number),
        load_detail_issues(config, model, number),
        load_repo_issues(config, model),
      ])
  }
}

fn state_badge(state: String) -> Element(Msg) {
  let class = case state {
    "open" -> "comic-state-badge comic-state-open"
    "closed" -> "comic-state-badge comic-state-closed"
    _ -> "comic-state-badge comic-state-closed"
  }
  let label = case state {
    "open" -> "Open"
    "closed" -> "Closed"
    _ -> state
  }
  span([attr.class(class)], [text(label)])
}

fn progress_percent(milestone: Milestone) -> Int {
  let total = milestone.open_issues + milestone.closed_issues
  case total {
    0 -> 0
    _ -> milestone.closed_issues * 100 / total
  }
}

fn progress_label(milestone: Milestone) -> String {
  let total = milestone.open_issues + milestone.closed_issues
  int.to_string(milestone.closed_issues)
  <> " of "
  <> int.to_string(total)
  <> " closed"
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    MilestonesLoaded(Ok(milestones)) -> #(
      Model(..model, milestones:, loading: False, error: option.None),
      none(),
    )
    MilestonesLoaded(Error(_)) -> #(
      Model(
        ..model,
        loading: False,
        error: option.Some("Failed to load milestones"),
      ),
      none(),
    )
    DetailLoaded(Ok(milestone)) -> #(
      Model(
        ..model,
        detail: option.Some(milestone),
        edit_title: milestone.title,
        edit_description: option.unwrap(milestone.description, ""),
        edit_due_on: option.unwrap(milestone.due_on, ""),
        loading: False,
        error: option.None,
      ),
      none(),
    )
    DetailLoaded(Error(_)) -> #(
      Model(
        ..model,
        loading: False,
        error: option.Some("Milestone not found"),
      ),
      none(),
    )
    DetailIssuesLoaded(Ok(issues)) -> #(
      Model(..model, detail_issues: issues, error: option.None),
      none(),
    )
    DetailIssuesLoaded(Error(_)) -> #(
      Model(..model, error: option.Some("Failed to load milestone issues")),
      none(),
    )
    RepoIssuesLoaded(Ok(issues)) -> #(
      Model(..model, repo_issues: issues, error: option.None),
      none(),
    )
    RepoIssuesLoaded(Error(_)) -> #(model, none())
    ToggleAddIssuesMenu -> #(
      Model(
        ..model,
        add_issues_menu_open: !model.add_issues_menu_open,
        add_issues_filter: "",
      ),
      none(),
    )
    AddIssuesFilterChanged(query) -> #(
      Model(..model, add_issues_filter: query),
      none(),
    )
    AssignIssue(number) ->
      case model.detail {
        option.None -> #(model, none())
        option.Some(milestone) -> #(
          Model(..model, saving: True, error: option.None),
          lustre_http.patch(
            config,
            api_base(config, model) <> "/issues/" <> int.to_string(number),
            api.update_issue_milestone_body(option.Some(milestone.id)),
            lustre_http.expect_json(api.issue_decoder(), IssueAssigned),
          ),
        )
      }
    IssueAssigned(Ok(_)) ->
      case model.detail {
        option.None -> #(Model(..model, saving: False), none())
        option.Some(milestone) -> #(
          Model(
            ..model,
            saving: False,
            add_issues_menu_open: False,
            add_issues_filter: "",
            error: option.None,
          ),
          batch([
            load_detail_issues(config, model, milestone.number),
            load_repo_issues(config, model),
          ]),
        )
      }
    IssueAssigned(Error(_)) -> #(
      Model(
        ..model,
        saving: False,
        error: option.Some("Could not assign issue to milestone"),
      ),
      none(),
    )
    TitleChanged(title) -> #(Model(..model, title:), none())
    DescriptionChanged(description) -> #(
      Model(..model, description:),
      none(),
    )
    DueOnChanged(due_on) -> #(Model(..model, due_on:), none())
    Create -> #(
      Model(..model, saving: True, error: option.None),
      lustre_http.post(
        config,
        api_base(config, model) <> "/milestones",
        api.create_milestone_body(
          string.trim(model.title),
          case string.trim(model.description) {
            "" -> option.None
            text -> option.Some(text)
          },
          case string.trim(model.due_on) {
            "" -> option.None
            date -> option.Some(date)
          },
        ),
        lustre_http.expect_json(api.milestone_decoder(), Created),
      ),
    )
    Created(Ok(milestone)) -> #(
      model,
      modem.replace(
        milestone_detail_path(model.org_slug, model.repo_name, milestone.number),
        option.None,
        option.None,
      ),
    )
    Created(Error(_)) -> #(
      Model(
        ..model,
        saving: False,
        error: option.Some("Could not create milestone"),
      ),
      none(),
    )
    StartEdit -> #(
      Model(..model, editing: True, error: option.None),
      none(),
    )
    CancelEdit ->
      case model.detail {
        option.Some(milestone) -> #(
          Model(
            ..model,
            editing: False,
            edit_title: milestone.title,
            edit_description: option.unwrap(milestone.description, ""),
            edit_due_on: option.unwrap(milestone.due_on, ""),
            error: option.None,
          ),
          none(),
        )
        option.None -> #(Model(..model, editing: False), none())
      }
    EditTitleChanged(title) -> #(Model(..model, edit_title: title), none())
    EditDescriptionChanged(description) -> #(
      Model(..model, edit_description: description),
      none(),
    )
    EditDueOnChanged(due_on) -> #(Model(..model, edit_due_on: due_on), none())
    SaveEdit ->
      case model.detail {
        option.Some(milestone) -> #(
          Model(..model, saving: True, error: option.None),
          lustre_http.patch(
            config,
            api_base(config, model)
              <> "/milestones/"
              <> int.to_string(milestone.number),
            api.update_milestone_body(
              string.trim(model.edit_title),
              case string.trim(model.edit_description) {
                "" -> option.None
                text -> option.Some(text)
              },
              case string.trim(model.edit_due_on) {
                "" -> option.None
                date -> option.Some(date)
              },
            ),
            lustre_http.expect_json(api.milestone_decoder(), Saved),
          ),
        )
        option.None -> #(model, none())
      }
    Saved(Ok(milestone)) -> #(
      Model(
        ..model,
        detail: option.Some(milestone),
        editing: False,
        saving: False,
        error: option.None,
      ),
      none(),
    )
    Saved(Error(_)) -> #(
      Model(
        ..model,
        saving: False,
        error: option.Some("Could not save milestone"),
      ),
      none(),
    )
    CloseMilestone ->
      case model.detail {
        option.Some(milestone) -> #(
          Model(..model, saving: True, error: option.None),
          lustre_http.post(
            config,
            api_base(config, model)
              <> "/milestones/"
              <> int.to_string(milestone.number)
              <> "/close",
            json.object([]),
            lustre_http.expect_json(api.milestone_decoder(), Closed),
          ),
        )
        option.None -> #(model, none())
      }
    Closed(Ok(milestone)) -> #(
      Model(
        ..model,
        detail: option.Some(milestone),
        saving: False,
        error: option.None,
      ),
      none(),
    )
    Closed(Error(_)) -> #(
      Model(
        ..model,
        saving: False,
        error: option.Some("Could not close milestone"),
      ),
      none(),
    )
  }
}

fn markdown_body(content: String) -> Element(Msg) {
  unsafe_raw_html(
    "",
    "div",
    [attr.class("markdown-body text-sm")],
    markdown.to_html(content),
  )
}

fn progress_bar(milestone: Milestone) -> Element(Msg) {
  let percent = progress_percent(milestone)
  div([attr.class("space-y-1")], [
    div([attr.class("h-3 w-full border-2 border-gh-ink bg-white")], [
      div([
        attr.class("h-full bg-gh-accent"),
        attr.style("width", int.to_string(percent) <> "%"),
      ], []),
    ]),
    p([attr.class("text-xs font-medium text-gh-muted")], [
      text(progress_label(milestone)),
    ]),
  ])
}

fn milestone_row(model: Model, milestone: Milestone) -> Element(Msg) {
  a(
    [
      attr.href(
        milestone_detail_path(model.org_slug, model.repo_name, milestone.number),
      ),
      attr.class(
        components.list_item <> " block no-underline hover:border-gh-accent",
      ),
    ],
    [
      div([attr.class("flex items-start justify-between gap-4")], [
        div([attr.class("min-w-0 flex-1")], [
          div([attr.class("flex items-center gap-2")], [
            span([attr.class("comic-issue-num shrink-0")], [
              text("#" <> int.to_string(milestone.number)),
            ]),
            span([attr.class("font-bold text-gh-ink")], [text(milestone.title)]),
            state_badge(milestone.state),
          ]),
          case milestone.due_on {
            option.Some(due_on) ->
              p([attr.class("mt-1 text-sm font-medium text-gh-muted")], [
                text("Due " <> due_on),
              ])
            option.None -> text("")
          },
        ]),
        div([attr.class("w-40 shrink-0")], [progress_bar(milestone)]),
      ]),
    ],
  )
}

fn list_view(model: Model) -> Element(Msg) {
  div([], [
    div([attr.class("mb-4 flex items-center justify-between")], [
      h2([attr.class(components.section_title)], [text("Milestones")]),
      a(
        [
          attr.href(milestone_new_path(model.org_slug, model.repo_name)),
          attr.class(components.btn_primary),
        ],
        [text("New milestone")],
      ),
    ]),
    case model.loading {
      True -> components.loading_state()
      False ->
        case model.milestones {
          [] ->
            components.empty_state("No milestones yet.")
          milestones ->
            div([attr.class("space-y-3")], list.map(milestones, fn(m) {
              milestone_row(model, m)
            }))
        }
    },
  ])
}

fn new_view(model: Model) -> Element(Msg) {
  div([attr.class(components.card <> " p-4 max-w-xl")], [
    h2([attr.class("text-lg font-semibold mb-4")], [text("New milestone")]),
    form([event.on_submit(fn(_) { Create })], [
      div([attr.class("space-y-4")], [
        div([], [
          label([attr.for("title"), attr.class("block text-sm font-medium")], [
            text("Title"),
          ]),
          input([
            attr.id("title"),
            attr.type_("text"),
            attr.value(model.title),
            attr.required(True),
            attr.class(components.input),
            event.on_input(TitleChanged),
          ]),
        ]),
        div([], [
          label([
            attr.for("description"),
            attr.class("block text-sm font-medium"),
          ], [
            text("Description"),
          ]),
          textarea(
            [
              attr.id("description"),
              attr.class(components.textarea <> " min-h-28"),
              event.on_input(DescriptionChanged),
            ],
            model.description,
          ),
        ]),
        div([], [
          label([attr.for("due_on"), attr.class("block text-sm font-medium")], [
            text("Due date"),
          ]),
          input([
            attr.id("due_on"),
            attr.type_("date"),
            attr.value(model.due_on),
            attr.class(components.input),
            event.on_input(DueOnChanged),
          ]),
        ]),
        div([attr.class("flex gap-2")], [
          button([
            attr.type_("submit"),
            attr.class(components.btn_primary),
            attr.disabled(model.saving),
          ], [text("Create milestone")]),
          a(
            [
              attr.href(milestone_list_path(model.org_slug, model.repo_name)),
              attr.class(components.btn_secondary),
            ],
            [text("Cancel")],
          ),
        ]),
      ]),
    ]),
  ])
}

fn issues_not_in_milestone(model: Model) -> List(labels_ui.IssueLinkOption) {
  let assigned_numbers =
    list.map(model.detail_issues, fn(issue) { issue.number })
  list.map(
    list.filter(model.repo_issues, fn(issue) {
      !list.contains(assigned_numbers, issue.number)
    }),
    fn(issue) {
      labels_ui.IssueLinkOption(number: issue.number, title: issue.title)
    },
  )
}

fn add_issues_picker(model: Model) -> Element(Msg) {
  let available = issues_not_in_milestone(model)
  let empty_message = case model.repo_issues {
    [] -> "No open issues in this repository."
    _ -> "No open issues available to add."
  }
  div([attr.class("mb-4")], [
    labels_ui.searchable_issue_link_field(
      available,
      model.add_issues_menu_open,
      model.add_issues_filter,
      empty_message,
      ToggleAddIssuesMenu,
      AddIssuesFilterChanged,
      AssignIssue,
    ),
  ])
}

fn issue_row(model: Model, issue: Issue) -> Element(Msg) {
  li([attr.class("py-2")], [
    a(
      [
        attr.href(
          issue_detail_path(model.org_slug, model.repo_name, issue.number),
        ),
        attr.class("flex items-center gap-2 no-underline hover:opacity-80"),
      ],
      [
        span([attr.class("comic-issue-num shrink-0")], [
          text("#" <> int.to_string(issue.number)),
        ]),
        span([attr.class("truncate text-sm font-semibold text-gh-ink")], [
          text(issue.title),
        ]),
        state_badge(issue.state),
      ],
    ),
  ])
}

fn detail_view(model: Model) -> Element(Msg) {
  case model.detail {
    option.None ->
      case model.loading {
        True -> components.loading_state()
        False -> p([attr.class("text-sm font-medium text-gh-muted")], [
          text("Not found"),
        ])
      }
    option.Some(milestone) ->
      div([], [
        div([attr.class("mb-4")], [
          components.breadcrumb_back(
            milestone_list_path(model.org_slug, model.repo_name),
            "Milestones",
          ),
        ]),
        div([attr.class(components.card <> " p-4 mb-4")], [
          case model.editing {
            True ->
              form([event.on_submit(fn(_) { SaveEdit })], [
                div([attr.class("space-y-4")], [
                  input([
                    attr.type_("text"),
                    attr.value(model.edit_title),
                    attr.class(components.input),
                    event.on_input(EditTitleChanged),
                  ]),
                  textarea(
                    [
                      attr.class(components.textarea <> " min-h-28"),
                      event.on_input(EditDescriptionChanged),
                    ],
                    model.edit_description,
                  ),
                  input([
                    attr.type_("date"),
                    attr.value(model.edit_due_on),
                    attr.class(components.input),
                    event.on_input(EditDueOnChanged),
                  ]),
                  div([attr.class("flex gap-2")], [
                    button([
                      attr.type_("submit"),
                      attr.class(components.btn_primary),
                      attr.disabled(model.saving),
                    ], [text("Save")]),
                    button([
                      attr.type_("button"),
                      attr.class(components.btn_secondary),
                      event.on_click(CancelEdit),
                    ], [text("Cancel")]),
                  ]),
                ]),
              ])
            False ->
              div([], [
                div([attr.class("flex items-start justify-between gap-4")], [
                  div([], [
                    h2([attr.class("text-xl font-semibold")], [
                      text(milestone.title),
                    ]),
                    p([attr.class("mt-1 text-sm font-medium text-gh-muted")], [
                      text(
                        "#"
                        <> int.to_string(milestone.number)
                        <> " · "
                        <> case milestone.state {
                          "closed" -> "Closed"
                          _ -> "Open"
                        }
                        <> case milestone.due_on {
                          option.Some(due_on) -> " · Due " <> due_on
                          option.None -> ""
                        },
                      ),
                    ]),
                  ]),
                  div([attr.class("flex gap-2")], [
                    case milestone.state {
                      "open" ->
                        button([
                          attr.type_("button"),
                          attr.class(components.btn_secondary),
                          event.on_click(StartEdit),
                        ], [text("Edit")])
                      _ -> text("")
                    },
                    case milestone.state {
                      "open" ->
                        button([
                          attr.type_("button"),
                          attr.class(components.btn_secondary),
                          attr.disabled(model.saving),
                          event.on_click(CloseMilestone),
                        ], [text("Close milestone")])
                      _ -> text("")
                    },
                  ]),
                ]),
                div([attr.class("mt-4 max-w-md")], [progress_bar(milestone)]),
                case milestone.description {
                  option.Some(body) ->
                    div([attr.class("mt-4")], [markdown_body(body)])
                  option.None -> text("")
                },
              ])
          },
        ]),
        labels_ui.sidebar_section(
          "Issues",
          div([attr.class("space-y-3")], [
            add_issues_picker(model),
            case model.detail_issues {
              [] ->
                p([attr.class("text-sm font-medium text-gh-muted")], [
                  text("No issues in this milestone."),
                ])
              issues ->
                ul([attr.class("list-none space-y-2")], list.map(
                  issues,
                  fn(issue) { issue_row(model, issue) },
                ))
            },
          ]),
        ),
      ])
  }
}

pub fn view(model: Model) -> Element(Msg) {
  let error = case model.error {
    option.Some(e) -> components.error_alert(e)
    option.None -> text("")
  }
  let body = case model.mode {
    List -> list_view(model)
    New -> new_view(model)
    Detail(_) -> detail_view(model)
  }
  repo_nav.shell(model.org_slug, model.repo_name, repo_nav.Milestones, [
    error,
    body,
  ])
}
