import components
import config.{type Config}
import gleam/int
import gleam/list
import gleam/option
import http/api.{
  type Issue, type Label, type MergeRequestTemplate, type MergeRequestTemplates,
  type OrgMember,
}
import http/list_query
import http/lustre_http
import http/search_query
import labels_ui
import lustre/attribute as attr
import lustre/effect.{type Effect, batch, none}
import lustre/element.{type Element, memo, ref, text}
import lustre/element/html.{
  a, button, div, form, input, label, option as html_option, select, span, table,
  tbody, td, textarea, th, thead, tr,
}
import lustre/event
import modem
import pages/list_filters_ui
import pages/repo_nav
import routes

pub type Model {
  Model(
    org_slug: String,
    repo_name: String,
    mode: Mode,
    issues: List(Issue),
    total_count: Int,
    repo_labels: List(Label),
    org_members: List(OrgMember),
    filters: list_query.IssueListFilters,
    pending_search: String,
    title: String,
    description: String,
    description_initial: String,
    description_dirty: Bool,
    description_seed: Int,
    templates: List(MergeRequestTemplate),
    selected_template_index: Int,
    loading: Bool,
    error: option.Option(String),
  )
}

pub type Mode {
  List
  New
}

pub type Msg {
  Loaded(Result(List(Issue), lustre_http.HttpError))
  LabelsLoaded(Result(List(Label), lustre_http.HttpError))
  MembersLoaded(Result(List(OrgMember), lustre_http.HttpError))
  SearchChanged(String)
  SearchKeyPressed(String)
  StateFilterChanged(String)
  SortChanged(String, String)
  TitleChanged(String)
  DescriptionChanged(String)
  TemplateLoaded(Result(MergeRequestTemplates, lustre_http.HttpError))
  TemplateSelected(Int)
  Create
  Created(Result(Issue, lustre_http.HttpError))
}

pub fn init(org_slug: String, repo_name: String, mode: Mode) -> Model {
  Model(
    org_slug:,
    repo_name:,
    mode:,
    issues: [],
    total_count: 0,
    repo_labels: [],
    org_members: [],
    filters: list_query.default_issue_filters(),
    pending_search: "",
    title: "",
    description: "",
    description_initial: "",
    description_dirty: False,
    description_seed: 0,
    templates: [],
    selected_template_index: 0,
    loading: case mode {
      List -> True
      New -> False
    },
    error: option.None,
  )
}

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  case model.mode {
    List ->
      batch([
        fetch_issues(config, model),
        fetch_labels(config, model),
        fetch_members(config, model),
      ])
    New ->
      lustre_http.get(
        config,
        api_base(config, model) <> "/issues/template",
        lustre_http.expect_json(
          api.merge_request_templates_decoder(),
          TemplateLoaded,
        ),
      )
  }
}

fn fetch_issues(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model)
      <> "/issues"
      <> list_query.issue_list_query(model.filters),
    lustre_http.expect_json(api.issues_decoder(), Loaded),
  )
}

fn fetch_labels(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model) <> "/labels",
    lustre_http.expect_json(api.labels_decoder(), LabelsLoaded),
  )
}

fn fetch_members(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    config.api_url <> "/api/orgs/" <> model.org_slug <> "/members",
    lustre_http.expect_json(api.members_decoder(), MembersLoaded),
  )
}

fn description_from_templates(
  templates: List(MergeRequestTemplate),
  index: Int,
) -> String {
  case list.drop(templates, index) |> list.first {
    Ok(template) -> template.content
    Error(_) -> ""
  }
}

fn api_base(config: Config, model: Model) -> String {
  config.api_url
  <> "/api/orgs/"
  <> model.org_slug
  <> "/repos/"
  <> model.repo_name
}

fn apply_search(model: Model, config: Config) -> #(Model, Effect(Msg)) {
  let parts = search_query.parse_issue_search(model.pending_search)
  let filters =
    list_query.IssueListFilters(
      ..model.filters,
      label_names: search_query.resolve_label_names(
        parts.label_names,
        model.repo_labels,
      ),
      assignee: search_query.resolve_member(parts.assignee, model.org_members),
      author: search_query.resolve_member(parts.author, model.org_members),
      q: parts.text,
    )
  apply_filters(model, config, filters)
}

fn apply_filters(
  model: Model,
  config: Config,
  filters: list_query.IssueListFilters,
) -> #(Model, Effect(Msg)) {
  #(
    Model(..model, filters:, loading: True, error: option.None),
    fetch_issues(config, Model(..model, filters:)),
  )
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    Loaded(Ok(issues)) -> #(
      Model(
        ..model,
        issues:,
        total_count: list.length(issues),
        loading: False,
        error: option.None,
      ),
      none(),
    )
    Loaded(Error(_)) -> #(
      Model(
        ..model,
        loading: False,
        error: option.Some("Failed to load issues"),
      ),
      none(),
    )
    LabelsLoaded(Ok(labels)) -> #(Model(..model, repo_labels: labels), none())
    LabelsLoaded(Error(_)) -> #(model, none())
    MembersLoaded(Ok(members)) -> #(
      Model(..model, org_members: members),
      none(),
    )
    MembersLoaded(Error(_)) -> #(model, none())
    SearchChanged(query) -> #(
      Model(..model, pending_search: query),
      none(),
    )
    SearchKeyPressed(key) ->
      case key {
        "Enter" -> apply_search(model, config)
        _ -> #(model, none())
      }
    StateFilterChanged(state) ->
      apply_filters(
        model,
        config,
        list_query.IssueListFilters(..model.filters, state:),
      )
    SortChanged(sort, order) ->
      apply_filters(
        model,
        config,
        list_query.IssueListFilters(..model.filters, sort:, order:),
      )
    TitleChanged(v) -> #(Model(..model, title: v), none())
    DescriptionChanged(v) -> #(
      Model(..model, description: v, description_dirty: True),
      none(),
    )
    TemplateLoaded(Ok(data)) -> {
      case model.description_dirty {
        True -> #(Model(..model, templates: data.templates), none())
        False -> {
          let description = description_from_templates(data.templates, 0)
          case description {
            "" -> #(Model(..model, templates: data.templates), none())
            _ -> #(
              Model(
                ..model,
                templates: data.templates,
                selected_template_index: 0,
                description:,
                description_initial: description,
                description_seed: model.description_seed + 1,
              ),
              none(),
            )
          }
        }
      }
    }
    TemplateLoaded(Error(_)) -> #(model, none())
    TemplateSelected(index) -> {
      let description = description_from_templates(model.templates, index)
      #(
        Model(
          ..model,
          selected_template_index: index,
          description:,
          description_initial: description,
          description_dirty: False,
          description_seed: model.description_seed + 1,
        ),
        none(),
      )
    }
    Create -> #(
      model,
      lustre_http.post(
        config,
        api_base(config, model) <> "/issues",
        api.create_issue_body(model.title, case model.description {
          "" -> option.None
          d -> option.Some(d)
        }),
        lustre_http.expect_json(api.issue_decoder(), Created),
      ),
    )
    Created(Ok(issue)) -> #(
      model,
      modem.replace(
        routes.issue_detail_path(model.org_slug, model.repo_name, issue.number),
        option.None,
        option.None,
      ),
    )
    Created(Error(_)) -> #(
      Model(..model, error: option.Some("Could not create issue")),
      none(),
    )
  }
}

pub fn view(model: Model) -> Element(Msg) {
  let error = case model.error {
    option.Some(e) -> components.error_alert(e)
    option.None -> text("")
  }
  let actions = case model.mode {
    List ->
      div([attr.class("mb-4 flex justify-end")], [
        a(
          [
            attr.class(components.btn_primary),
            attr.href(routes.issue_new_path(model.org_slug, model.repo_name)),
          ],
          [text("New issue")],
        ),
      ])
    New -> text("")
  }
  let body = case model.mode {
    List -> list_view(model)
    New -> new_view(model)
  }
  repo_nav.shell(model.org_slug, model.repo_name, repo_nav.Issues, [
    error,
    actions,
    body,
  ])
}

fn list_view(model: Model) -> Element(Msg) {
  div([attr.class(components.card <> " !p-0 overflow-hidden")], [
    list_toolbar(model),
    div([attr.class("overflow-x-auto")], [issues_table(model)]),
    list_count_footer(model),
  ])
}

fn list_count_footer(model: Model) -> Element(Msg) {
  list_filters_ui.list_count_footer(list_filters_ui.count_label(
    list.length(model.issues),
    model.total_count,
    "issue",
    list_filters_ui.filters_active_issue(model.filters),
  ))
}

fn list_toolbar(model: Model) -> Element(Msg) {
  list_filters_ui.toolbar([
    list_filters_ui.main_row(
      list_filters_ui.state_filter_tabs(
        [#("Open", "open"), #("Closed", "closed"), #("All", "all")],
        model.filters.state,
        StateFilterChanged,
      ),
      list_filters_ui.search_input(
        "Search issues",
        model.pending_search,
        SearchChanged,
        SearchKeyPressed,
      ),
      list_filters_ui.sort_select(
        model.filters.sort,
        model.filters.order,
        SortChanged,
      ),
    ),
    list_filters_ui.search_hint(
      "Try label:bug assignee:alice author:bob, or plain title text — press Enter to search",
    ),
  ])
}

fn state_badge(state: String) -> Element(Msg) {
  let state_class = case state {
    "open" -> "comic-state-badge comic-state-open"
    "closed" -> "comic-state-badge comic-state-closed"
    _ -> "comic-state-badge comic-state-closed"
  }
  span([attr.class(state_class)], [text(state)])
}

fn issues_empty_message(model: Model) -> String {
  case list_filters_ui.filters_active_issue(model.filters) {
    True -> "No issues match your filters."
    False -> "No issues yet. Open one to track bugs or tasks."
  }
}

fn issues_table(model: Model) -> Element(Msg) {
  let org = model.org_slug
  let repo = model.repo_name
  let td_class = "align-middle"
  let header =
    tr([], [
      th([attr.class("w-16")], [text("#")]),
      th([], [text("Title")]),
      th([attr.class("w-40")], [text("Labels")]),
      th([attr.class("w-28")], [text("State")]),
    ])
  let body_rows = case model.loading {
    True -> [list_filters_ui.table_loading_row(4)]
    False ->
      case model.issues {
        [] -> [
          list_filters_ui.table_empty_row(issues_empty_message(model), 4),
        ]
        issues ->
          list.map(issues, fn(issue) {
            tr([], [
              td([attr.class(td_class)], [
                a(
                  [
                    attr.href(routes.issue_detail_path(org, repo, issue.number)),
                    attr.class("comic-issue-num"),
                  ],
                  [text("#" <> int.to_string(issue.number))],
                ),
              ]),
              td([attr.class(td_class)], [
                a(
                  [
                    attr.href(routes.issue_detail_path(org, repo, issue.number)),
                    attr.class(
                      "font-bold text-gh-ink no-underline hover:text-gh-accent hover:underline",
                    ),
                  ],
                  [text(issue.title)],
                ),
              ]),
              td([attr.class(td_class)], [
                labels_ui.label_badges(issue.labels),
              ]),
              td([attr.class(td_class)], [state_badge(issue.state)]),
            ])
          })
      }
  }
  table([attr.class(components.comic_list_table)], [
    thead([], [header]),
    tbody([], body_rows),
  ])
}

fn template_picker(model: Model) -> Element(Msg) {
  case list.length(model.templates) {
    n if n <= 1 -> text("")
    _ ->
      div([attr.class("mb-2 flex items-center gap-2")], [
        label(
          [attr.class("text-xs font-black uppercase tracking-wide text-gh-ink")],
          [
            text("Template"),
          ],
        ),
        select(
          [
            attr.class(components.input <> " !max-w-xs"),
            event.on_change(fn(value) {
              case int.parse(value) {
                Ok(index) -> TemplateSelected(index)
                Error(_) -> TemplateSelected(0)
              }
            }),
          ],
          list.index_map(model.templates, fn(template, index) {
            html_option(
              [
                attr.value(int.to_string(index)),
                attr.selected(index == model.selected_template_index),
              ],
              template.name,
            )
          }),
        ),
      ])
  }
}

fn description_textarea(model: Model) -> Element(Msg) {
  memo([ref(model.description_seed), ref(model.description_initial)], fn() {
    textarea(
      [
        attr.class(components.textarea),
        attr.placeholder("Describe the issue…"),
        event.on_input(DescriptionChanged),
      ],
      model.description_initial,
    )
  })
}

fn new_view(model: Model) -> Element(Msg) {
  div([attr.class(components.card)], [
    form([attr.class("space-y-4"), event.on_submit(fn(_) { Create })], [
      label(
        [
          attr.class(
            "mb-1.5 block text-sm font-black uppercase tracking-wide text-gh-ink",
          ),
        ],
        [
          text("Title"),
        ],
      ),
      input([
        attr.class(components.input),
        attr.value(model.title),
        event.on_input(TitleChanged),
      ]),
      template_picker(model),
      label(
        [
          attr.class(
            "mb-1.5 block text-sm font-black uppercase tracking-wide text-gh-ink",
          ),
        ],
        [
          text("Description"),
        ],
      ),
      description_textarea(model),
      button([attr.type_("submit"), attr.class(components.btn_primary)], [
        text("Create issue"),
      ]),
    ]),
  ])
}
