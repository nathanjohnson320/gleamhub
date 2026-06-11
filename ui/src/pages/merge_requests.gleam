import ci/status as ci_status
import components
import config.{type Config}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import gleam/uri
import http/api.{
  type Label, type MergeRequest, type MergeRequestTemplate, type OrgMember,
  type Pipeline,
}
import http/list_query
import http/lustre_http
import http/search_query
import labels_ui
import lustre/attribute as attr
import lustre/effect.{type Effect, batch, none}
import lustre/element.{type Element, memo, ref, text}
import lustre/element/html.{
  a, button, div, form, h2, input, label, option as html_option, p, select, span,
  table, tbody, td, textarea, th, thead, tr,
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
    merge_requests: List(MergeRequest),
    total_count: Int,
    branches: List(String),
    repo_labels: List(Label),
    org_members: List(OrgMember),
    filters: list_query.MergeRequestListFilters,
    pending_search: String,
    title: String,
    description: String,
    description_initial: String,
    description_dirty: Bool,
    description_seed: Int,
    templates: List(MergeRequestTemplate),
    selected_template_index: Int,
    source_branch: String,
    target_branch: String,
    create_submit: CreateSubmit,
    create_menu_open: Bool,
    loading: Bool,
    error: option.Option(String),
  )
}

pub type Mode {
  List
  New
}

pub type CreateSubmit {
  Open
  Draft
}

pub type Msg {
  Loaded(Result(List(MergeRequest), lustre_http.HttpError))
  BranchesLoaded(Result(List(String), lustre_http.HttpError))
  LabelsLoaded(Result(List(Label), lustre_http.HttpError))
  MembersLoaded(Result(List(OrgMember), lustre_http.HttpError))
  TemplateLoaded(Result(api.MergeRequestTemplates, lustre_http.HttpError))
  SearchChanged(String)
  SearchKeyPressed(String)
  StateFilterChanged(String)
  SortChanged(String, String)
  TitleChanged(String)
  DescriptionChanged(String)
  TemplateSelected(Int)
  SourceChanged(String)
  TargetChanged(String)
  ToggleCreateMenu
  SelectCreateSubmit(CreateSubmit)
  Create
  Created(Result(MergeRequest, lustre_http.HttpError))
}

pub fn init(org_slug: String, repo_name: String, mode: Mode) -> Model {
  Model(
    org_slug:,
    repo_name:,
    mode:,
    merge_requests: [],
    total_count: 0,
    branches: [],
    repo_labels: [],
    org_members: [],
    filters: list_query.default_merge_request_filters(),
    pending_search: "",
    title: "",
    description: "",
    description_initial: "",
    description_dirty: False,
    description_seed: 0,
    templates: [],
    selected_template_index: 0,
    source_branch: "",
    target_branch: "main",
    create_submit: Open,
    create_menu_open: False,
    loading: True,
    error: option.None,
  )
}

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  let base = api_base(config, model)
  case model.mode {
    List ->
      batch([
        fetch_merge_requests(config, model),
        lustre_http.get(
          config,
          base <> "/branches",
          lustre_http.expect_json(api.branches_decoder(), BranchesLoaded),
        ),
        lustre_http.get(
          config,
          base <> "/labels",
          lustre_http.expect_json(api.labels_decoder(), LabelsLoaded),
        ),
        lustre_http.get(
          config,
          config.api_url <> "/api/orgs/" <> model.org_slug <> "/members",
          lustre_http.expect_json(api.members_decoder(), MembersLoaded),
        ),
      ])
    New ->
      lustre_http.get(
        config,
        base <> "/branches",
        lustre_http.expect_json(api.branches_decoder(), BranchesLoaded),
      )
  }
}

fn fetch_merge_requests(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model)
      <> "/merge-requests"
      <> list_query.merge_request_list_query(model.filters),
    lustre_http.expect_json(api.merge_requests_decoder(), Loaded),
  )
}

fn apply_search(model: Model, config: Config) -> #(Model, Effect(Msg)) {
  let parts = search_query.parse_merge_request_search(model.pending_search)
  let filters =
    list_query.MergeRequestListFilters(
      ..model.filters,
      label_names: search_query.resolve_label_names(
        parts.label_names,
        model.repo_labels,
      ),
      author: search_query.resolve_member(parts.author, model.org_members),
      source_branch: optional_trimmed(parts.source_branch),
      target_branch: optional_trimmed(parts.target_branch),
      q: parts.text,
    )
  apply_filters(model, config, filters)
}

fn apply_filters(model: Model, config: Config, filters: list_query.MergeRequestListFilters) -> #(
  Model,
  Effect(Msg),
) {
  #(
    Model(
      ..model,
      filters:,
      loading: True,
      error: option.None,
    ),
    fetch_merge_requests(config, Model(..model, filters:)),
  )
}

fn default_target_branch(current: String, branches: List(String)) -> String {
  case list.contains(branches, current) {
    True -> current
    False ->
      case list.contains(branches, "main") {
        True -> "main"
        False ->
          case list.contains(branches, "master") {
            True -> "master"
            False ->
              case list.first(branches) {
                Ok(branch) -> branch
                Error(_) -> current
              }
          }
      }
  }
}

fn default_source_branch(
  current: String,
  target: String,
  branches: List(String),
) -> String {
  case current != "" && list.contains(branches, current) {
    True -> current
    False ->
      case list.find(branches, fn(b) { b != target }) {
        Ok(branch) -> branch
        Error(Nil) -> target
      }
  }
}

fn optional_trimmed(value: option.Option(String)) -> option.Option(String) {
  case value {
    option.None -> option.None
    option.Some(v) ->
      case string.trim(v) {
        "" -> option.None
        trimmed -> option.Some(trimmed)
      }
  }
}

fn api_base(config: Config, model: Model) -> String {
  config.api_url
  <> "/api/orgs/"
  <> model.org_slug
  <> "/repos/"
  <> model.repo_name
}

fn fetch_template(
  config: Config,
  model: Model,
  source_branch: String,
) -> Effect(Msg) {
  case source_branch {
    "" -> none()
    branch ->
      lustre_http.get(
        config,
        api_base(config, model)
          <> "/merge-requests/template?ref="
          <> uri.percent_encode(branch),
        lustre_http.expect_json(
          api.merge_request_templates_decoder(),
          TemplateLoaded,
        ),
      )
  }
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

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    Loaded(Ok(mrs)) -> #(
      Model(
        ..model,
        merge_requests: mrs,
        total_count: list.length(mrs),
        loading: False,
        error: option.None,
      ),
      none(),
    )
    Loaded(Error(_)) -> #(
      Model(
        ..model,
        loading: False,
        error: option.Some("Failed to load merge requests"),
      ),
      none(),
    )
    BranchesLoaded(Ok(branches)) -> {
      case model.mode {
        List -> #(
          Model(..model, branches:, loading: model.loading),
          none(),
        )
        New -> {
          let target = default_target_branch(model.target_branch, branches)
          let source = default_source_branch(model.source_branch, target, branches)
          #(
            Model(
              ..model,
              branches:,
              target_branch: target,
              source_branch: source,
              loading: False,
            ),
            fetch_template(config, model, target),
          )
        }
      }
    }
    BranchesLoaded(Error(_)) -> #(
      Model(
        ..model,
        loading: False,
        error: option.Some("Failed to load branches"),
      ),
      none(),
    )
    LabelsLoaded(Ok(labels)) -> #(
      Model(..model, repo_labels: labels),
      none(),
    )
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
        list_query.MergeRequestListFilters(..model.filters, state:),
      )
    SortChanged(sort, order) ->
      apply_filters(
        model,
        config,
        list_query.MergeRequestListFilters(..model.filters, sort:, order:),
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
    TitleChanged(v) -> #(Model(..model, title: v), none())
    DescriptionChanged(v) -> #(
      Model(..model, description: v, description_dirty: True),
      none(),
    )
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
    SourceChanged(v) -> #(Model(..model, source_branch: v), none())
    TargetChanged(v) -> #(
      Model(..model, target_branch: v),
      case model.description_dirty {
        True -> none()
        False -> fetch_template(config, model, v)
      },
    )
    ToggleCreateMenu -> #(
      Model(..model, create_menu_open: !model.create_menu_open),
      none(),
    )
    SelectCreateSubmit(kind) -> #(
      Model(..model, create_submit: kind, create_menu_open: False),
      none(),
    )
    Create -> #(
      Model(..model, create_menu_open: False),
      lustre_http.post(
        config,
        api_base(config, model) <> "/merge-requests",
        api.create_mr_body(
          model.title,
          case model.description {
            "" -> option.None
            d -> option.Some(d)
          },
          model.source_branch,
          model.target_branch,
          create_submit_is_draft(model.create_submit),
        ),
        lustre_http.expect_json(api.merge_request_decoder(), Created),
      ),
    )
    Created(Ok(mr)) -> #(
      model,
      modem.replace(
        routes.mr_detail_path(model.org_slug, model.repo_name, mr.number),
        option.None,
        option.None,
      ),
    )
    Created(Error(err)) -> #(
      Model(..model, error: option.Some(create_error_message(model, err))),
      none(),
    )
  }
}

fn create_error_message(_model: Model, err: lustre_http.HttpError) -> String {
  let body = case err {
    lustre_http.OtherError(_, b) | lustre_http.InternalServerError(b) -> b
    _ -> ""
  }
  case body {
    "" -> "Could not create merge request"
    json_str -> {
      case json.parse(json_str, decode.dynamic) {
        Ok(raw) ->
          case decode.run(raw, api.mr_create_error_decoder()) {
            Ok(#(message, option.Some(num))) ->
              message
              <> " Open #"
              <> int.to_string(num)
              <> " from the merge requests list."
            Ok(#(message, option.None)) -> message
            Error(_) -> "Could not create merge request"
          }
        Error(_) -> "Could not create merge request"
      }
    }
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
            attr.href(routes.mr_new_path(model.org_slug, model.repo_name)),
          ],
          [text("New merge request")],
        ),
      ])
    New -> text("")
  }
  let body = case model.mode {
    List -> list_view(model)
    New ->
      case model.loading {
        True -> components.loading_state()
        False -> new_view(model)
      }
  }
  repo_nav.shell(model.org_slug, model.repo_name, repo_nav.MergeRequests, [
    error,
    actions,
    body,
  ])
}

fn list_view(model: Model) -> Element(Msg) {
  div([attr.class("mr-list-shell")], [
    list_toolbar(model),
    div([attr.class("overflow-x-auto")], [merge_requests_table(model)]),
    list_count_footer(model),
  ])
}

fn list_count_footer(model: Model) -> Element(Msg) {
  list_filters_ui.list_count_footer(list_filters_ui.count_label(
    list.length(model.merge_requests),
    model.total_count,
    "merge request",
    list_filters_ui.filters_active_mr(model.filters),
  ))
}

fn list_toolbar(model: Model) -> Element(Msg) {
  list_filters_ui.toolbar([
    list_filters_ui.main_row(
      list_filters_ui.state_filter_tabs(
        [
          #("Open", "open"),
          #("Merged", "merged"),
          #("Closed", "closed"),
          #("All", "all"),
        ],
        model.filters.state,
        StateFilterChanged,
      ),
      list_filters_ui.search_input(
        "Search merge requests",
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
      "Try label:bug author:alice source:feature target:main, or plain title text — press Enter to search",
    ),
  ])
}

fn mr_href(org: String, repo: String, mr: MergeRequest) -> String {
  routes.mr_detail_path(org, repo, mr.number)
}

fn checks_cell(pipeline: option.Option(Pipeline)) -> Element(Msg) {
  let summary = case pipeline {
    option.None -> option.None
    option.Some(run) -> option.Some(#(run.state, run.commit_sha))
  }
  ci_status.pipeline_cell(summary)
}

fn draft_badge() -> Element(Msg) {
  span([attr.class("comic-state-badge comic-state-draft")], [text("Draft")])
}

fn state_badge(state: String) -> Element(Msg) {
  let state_class = case state {
    "open" -> "comic-state-badge comic-state-open"
    "merged" -> "comic-state-badge comic-state-merged"
    "closed" -> "comic-state-badge comic-state-closed"
    _ -> "comic-state-badge comic-state-closed"
  }
  span([attr.class(state_class)], [text(state)])
}

fn mr_status_badges(mr: MergeRequest) -> Element(Msg) {
  let badges = case mr.is_draft {
    True -> [draft_badge(), state_badge(mr.state)]
    False -> [state_badge(mr.state)]
  }
  div([attr.class("flex flex-wrap items-center gap-1.5")], badges)
}

fn mr_empty_message(model: Model) -> String {
  case list_filters_ui.filters_active_mr(model.filters) {
    True -> "No merge requests match your filters."
    False ->
      "No merge requests yet. Push a branch over SSH, then open one."
  }
}

fn merge_requests_table(model: Model) -> Element(Msg) {
  let org = model.org_slug
  let repo = model.repo_name
  let header =
    tr([], [
      th([attr.class("w-16")], [text("#")]),
      th([], [text("Title")]),
      th([attr.class("w-40")], [text("Labels")]),
      th([], [text("Branches")]),
      th([attr.class("w-32")], [text("Checks")]),
      th([attr.class("w-28")], [text("State")]),
    ])
  let body_rows = case model.loading {
    True -> [list_filters_ui.table_loading_row(6)]
    False ->
      case model.merge_requests {
        [] ->
          [
            list_filters_ui.table_empty_row(
              mr_empty_message(model),
              6,
            ),
          ]
        merge_requests ->
          list.map(merge_requests, fn(mr) {
            tr([], [
              td([attr.class("align-middle")], [
                a(
                  [
                    attr.href(mr_href(org, repo, mr)),
                    attr.class("comic-issue-num"),
                  ],
                  [text("#" <> int.to_string(mr.number))],
                ),
              ]),
              td([attr.class("align-middle")], [
                a(
                  [
                    attr.href(mr_href(org, repo, mr)),
                    attr.class(
                      "font-bold text-gh-ink no-underline hover:text-gh-accent hover:underline",
                    ),
                  ],
                  [text(mr.title)],
                ),
              ]),
              td([attr.class("align-middle")], [
                labels_ui.label_badges(mr.labels),
              ]),
              td([attr.class("align-middle")], [
                span([attr.class("comic-branch-flow")], [
                  span([], [text(mr.source_branch)]),
                  span([attr.class("comic-branch-arrow")], [text("→")]),
                  span([], [text(mr.target_branch)]),
                ]),
              ]),
              td([attr.class("align-middle")], [checks_cell(mr.pipeline)]),
              td([attr.class("align-middle")], [mr_status_badges(mr)]),
            ])
          })
      }
  }
  table([attr.class(components.comic_list_table)], [
    thead([], [header]),
    tbody([], body_rows),
  ])
}

fn new_view(model: Model) -> Element(Msg) {
  div([attr.class("mr-page")], [
    div([attr.class("mr-page-header")], [
      h2([attr.class(components.page_title_sm)], [text("New merge request")]),
      p([attr.class("mr-page-lead")], [
        text(
          "Pick branches, add a title and description, then open the request.",
        ),
      ]),
    ]),
    form([event.on_submit(fn(_) { Create })], [
      div([attr.class("mr-composer")], [
        branch_flow_picker(model),
        div([attr.class("mr-composer-body")], [
          div([], [
            label([attr.for("mr-title"), attr.class("mr-field-label")], [
              text("Title"),
            ]),
            input([
              attr.id("mr-title"),
              attr.name("title"),
              attr.type_("text"),
              attr.class("mr-composer-title"),
              attr.placeholder("Short summary of your changes"),
              attr.required(True),
              attr.autofocus(True),
              attr.value(model.title),
              event.on_input(TitleChanged),
            ]),
          ]),
          description_composer(model),
        ]),
        div([attr.class("mr-composer-footer")], [
          a(
            [
              attr.href(routes.mr_list_path(model.org_slug, model.repo_name)),
              attr.class("mr-footer-cancel"),
            ],
            [text("Cancel")],
          ),
          create_submit_control(model),
        ]),
      ]),
    ]),
  ])
}

fn create_submit_is_draft(kind: CreateSubmit) -> Bool {
  case kind {
    Open -> False
    Draft -> True
  }
}

fn create_submit_label(kind: CreateSubmit) -> String {
  case kind {
    Open -> "Create merge request"
    Draft -> "Create draft merge request"
  }
}

fn create_submit_control(model: Model) -> Element(Msg) {
  div([attr.class("mr-create-split")], [
    case model.create_menu_open {
      True -> create_submit_menu(model)
      False -> text("")
    },
    div([attr.class("mr-create-split-group")], [
      button(
        [
          attr.type_("submit"),
          attr.class("mr-create-primary"),
        ],
        [text(create_submit_label(model.create_submit))],
      ),
      button(
        [
          attr.type_("button"),
          attr.class("mr-create-caret"),
          attr.aria_expanded(model.create_menu_open),
          attr.aria_haspopup("menu"),
          event.on_click(ToggleCreateMenu),
        ],
        [text("▾")],
      ),
    ]),
  ])
}

fn create_submit_menu(model: Model) -> Element(Msg) {
  div([attr.class("mr-create-menu"), attr.role("menu")], [
    create_submit_option(
      model,
      Open,
      "Create merge request",
      "Ready for review; can be merged when checks pass.",
    ),
    create_submit_option(
      model,
      Draft,
      "Create draft merge request",
      "Work in progress; cannot be merged until marked ready.",
    ),
  ])
}

fn create_submit_option(
  model: Model,
  kind: CreateSubmit,
  title: String,
  description: String,
) -> Element(Msg) {
  let active = model.create_submit == kind
  let option_class = case active {
    True -> "mr-create-option mr-create-option-active"
    False -> "mr-create-option"
  }
  button(
    [
      attr.type_("button"),
      attr.class(option_class),
      attr.role("menuitem"),
      event.on_click(SelectCreateSubmit(kind)),
    ],
    [
      p([attr.class("mr-create-option-title")], [
        case active {
          True -> span([attr.class("mr-create-check")], [text("✓")])
          False -> span([attr.class("mr-create-check")], [text("")])
        },
        text(title),
      ]),
      p([attr.class("mr-create-option-desc")], [text(description)]),
    ],
  )
}

fn description_composer(model: Model) -> Element(Msg) {
  div([], [
    div([attr.class("mr-description-head")], [
      label([attr.for("mr-description"), attr.class("mr-field-label !mb-0")], [
        text("Description"),
      ]),
      div([attr.class("flex flex-wrap items-center gap-3")], [
        template_picker(model),
        span([attr.class("mr-composer-hint")], [text("Markdown supported")]),
      ]),
    ]),
    description_textarea(model),
  ])
}

fn description_textarea(model: Model) -> Element(Msg) {
  memo([ref(model.description_seed), ref(model.description_initial)], fn() {
    textarea(
      [
        attr.id("mr-description"),
        attr.name("description"),
        attr.class("mr-composer-textarea"),
        attr.placeholder(
          "What changed and why? Leave checklist items for reviewers.",
        ),
        event.on_input(DescriptionChanged),
      ],
      model.description_initial,
    )
  })
}

fn template_picker(model: Model) -> Element(Msg) {
  case list.length(model.templates) {
    n if n <= 1 -> text("")
    _ ->
      div([attr.class("flex items-center gap-2")], [
        label([attr.class("sr-only")], [text("Template")]),
        select(
          [
            attr.class("mr-template-select"),
            attr.title("Description template"),
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

fn branch_flow_picker(model: Model) -> Element(Msg) {
  let show_summary =
    model.source_branch != ""
    && model.target_branch != ""
    && model.source_branch != model.target_branch
  div([attr.class("mr-branch-section")], [
    div([attr.class("mr-branch-flow")], [
      branch_flow_field(
        field_label: "Source branch",
        current: model.source_branch,
        branches: model.branches,
        on_change: SourceChanged,
      ),
      branch_flow_arrow(),
      branch_flow_field(
        field_label: "Target branch",
        current: model.target_branch,
        branches: model.branches,
        on_change: TargetChanged,
      ),
    ]),
    case show_summary {
      False -> text("")
      True ->
        p([attr.class("mr-branch-summary")], [
          text(model.source_branch <> " → " <> model.target_branch),
        ])
    },
  ])
}

fn branch_flow_arrow() -> Element(Msg) {
  div([attr.class("mr-branch-arrow")], [
    span([attr.title("merges into")], [text("→")]),
  ])
}

fn branch_flow_field(
  field_label field_label: String,
  current current: String,
  branches branches: List(String),
  on_change on_change: fn(String) -> Msg,
) -> Element(Msg) {
  div([attr.class("min-w-0")], [
    label([attr.class("mr-branch-label")], [text(field_label)]),
    select(
      [
        attr.class("mr-branch-select"),
        event.on_change(on_change),
        attr.required(True),
      ],
      [
        html_option(
          [
            attr.value(""),
            attr.disabled(True),
            attr.selected(current == ""),
          ],
          "Select branch…",
        ),
        ..list.map(branches, fn(b) {
          html_option(
            [
              attr.value(b),
              attr.selected(b == current),
            ],
            b,
          )
        })
      ],
    ),
  ])
}
