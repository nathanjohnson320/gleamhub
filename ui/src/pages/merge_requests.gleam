import api.{type MergeRequest}
import components
import config.{type Config}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import lustre/attribute as attr
import lustre/effect.{type Effect, none}
import lustre/element.{type Element, text}
import lustre/element/html.{
  a, button, div, form, h2, input, label, option as html_option, p, select,
  span, table, tbody, td, textarea, th, thead, tr,
}
import lustre/event
import lustre_http
import modem
import routes

pub type Model {
  Model(
    org_slug: String,
    repo_name: String,
    mode: Mode,
    merge_requests: List(MergeRequest),
    branches: List(String),
    title: String,
    description: String,
    source_branch: String,
    target_branch: String,
    list_search: String,
    loading: Bool,
    error: option.Option(String),
  )
}

pub type Mode {
  List
  New
}

pub type Msg {
  Loaded(Result(List(MergeRequest), lustre_http.HttpError))
  BranchesLoaded(Result(List(String), lustre_http.HttpError))
  ListSearchChanged(String)
  TitleChanged(String)
  DescriptionChanged(String)
  SourceChanged(String)
  TargetChanged(String)
  Create
  Created(Result(MergeRequest, lustre_http.HttpError))
}

pub fn init(org_slug: String, repo_name: String, mode: Mode) -> Model {
  Model(
    org_slug:,
    repo_name:,
    mode:,
    merge_requests: [],
    branches: [],
    title: "",
    description: "",
    source_branch: "",
    target_branch: "main",
    list_search: "",
    loading: True,
    error: option.None,
  )
}

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  let base = api_base(config, model)
  case model.mode {
    List ->
      lustre_http.get(
        config,
        base <> "/merge-requests",
        lustre_http.expect_json(api.merge_requests_decoder(), Loaded),
      )
    New ->
      lustre_http.get(
        config,
        base <> "/branches",
        lustre_http.expect_json(api.branches_decoder(), BranchesLoaded),
      )
  }
}

fn api_base(config: Config, model: Model) -> String {
  config.api_url
  <> "/api/orgs/"
  <> model.org_slug
  <> "/repos/"
  <> model.repo_name
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    Loaded(Ok(mrs)) -> #(
      Model(..model, merge_requests: mrs, loading: False, error: option.None),
      none(),
    )
    Loaded(Error(_)) -> #(
      Model(..model, loading: False, error: option.Some("Failed to load merge requests")),
      none(),
    )
    BranchesLoaded(Ok(branches)) -> #(
      Model(..model, branches:, loading: False),
      none(),
    )
    BranchesLoaded(Error(_)) -> #(
      Model(..model, loading: False, error: option.Some("Failed to load branches")),
      none(),
    )
    ListSearchChanged(v) -> #(Model(..model, list_search: v), none())
    TitleChanged(v) -> #(Model(..model, title: v), none())
    DescriptionChanged(v) -> #(Model(..model, description: v), effect.none())
    SourceChanged(v) -> #(Model(..model, source_branch: v), effect.none())
    TargetChanged(v) -> #(Model(..model, target_branch: v), effect.none())
    Create -> #(
      model,
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
  let title = model.org_slug <> " / " <> model.repo_name <> " — Merge requests"
  let error = case model.error {
    option.Some(e) -> components.error_alert(e)
    option.None -> text("")
  }
  let body = case model.mode {
    List -> list_view(model)
    New -> new_view(model)
  }
  div([attr.class(components.page <> " max-w-5xl")], [
    components.breadcrumb_back(
      routes.repo_home_path(model.org_slug, model.repo_name),
      "Repository",
    ),
    div([attr.class("mb-4 flex flex-wrap items-center justify-between gap-3")], [
      h2([attr.class("text-2xl font-bold text-gh-ink")], [text(title)]),
      a(
        [
          attr.class(components.btn_primary),
          attr.href(routes.mr_new_path(model.org_slug, model.repo_name)),
        ],
        [text("New merge request")],
      ),
    ]),
    error,
    case model.loading {
      True -> components.empty_state("Loading…")
      False -> body
    },
  ])
}

fn list_view(model: Model) -> Element(Msg) {
  case model.merge_requests {
    [] ->
      components.empty_state(
        "No merge requests yet. Push a branch over SSH, then open one.",
      )
    _ -> {
      let filtered = filter_merge_requests(model.merge_requests, model.list_search)
      div([attr.class(components.card <> " !p-0 overflow-hidden")], [
        list_toolbar(model, filtered),
        case filtered {
          [] ->
            div([attr.class("px-6 pb-8")], [
              components.empty_state("No merge requests match your search."),
            ])
          mrs ->
            div([attr.class("overflow-x-auto")], [
              table_mrs(mrs, model.org_slug, model.repo_name),
            ])
        },
      ])
    }
  }
}

fn filter_merge_requests(mrs: List(MergeRequest), query: String) -> List(MergeRequest) {
  let needle = string.lowercase(string.trim(query))
  case needle {
    "" -> mrs
    _ ->
      list.filter(mrs, fn(mr) {
        string.contains(string.lowercase(mr.title), needle)
      })
  }
}

fn list_toolbar(model: Model, filtered: List(MergeRequest)) -> Element(Msg) {
  let total = list.length(model.merge_requests)
  let shown = list.length(filtered)
  let count_label = case string.trim(model.list_search) {
    "" -> int.to_string(total) <> " merge request" <> plural_suffix(total)
    _ ->
      "Showing "
      <> int.to_string(shown)
      <> " of "
      <> int.to_string(total)
  }
  div(
    [
      attr.class(
        "flex flex-col gap-3 border-b border-slate-200 bg-slate-50/80 px-4 py-4 sm:flex-row sm:items-center sm:justify-between sm:px-6",
      ),
    ],
    [
      p([attr.class("text-sm text-gh-muted")], [text(count_label)]),
      label([attr.class("sr-only")], [text("Search merge requests by title")]),
      input([
        attr.type_("search"),
        attr.name("mr-search"),
        attr.placeholder("Search by title…"),
        attr.value(model.list_search),
        attr.class(components.input <> " !max-w-md sm:!w-72"),
        event.on_input(ListSearchChanged),
      ]),
    ],
  )
}

fn plural_suffix(count: Int) -> String {
  case count {
    1 -> ""
    _ -> "s"
  }
}

fn state_badge(state: String) -> Element(Msg) {
  let classes = case state {
    "open" -> "bg-emerald-50 text-emerald-800 ring-emerald-600/20"
    "merged" -> "bg-violet-50 text-violet-800 ring-violet-600/20"
    "closed" -> "bg-slate-100 text-slate-600 ring-slate-500/20"
    _ -> "bg-slate-100 text-slate-600 ring-slate-500/20"
  }
  span(
    [
      attr.class(
        "inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium capitalize ring-1 ring-inset "
        <> classes,
      ),
    ],
    [text(state)],
  )
}

fn table_mrs(
  mrs: List(MergeRequest),
  org: String,
  repo: String,
) -> Element(Msg) {
  let th_class = "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gh-muted"
  let td_class = "px-4 py-3 align-middle"
  let header =
    tr([attr.class("border-b border-slate-200 bg-white")], [
      th([attr.class(th_class <> " w-16")], [text("#")]),
      th([attr.class(th_class)], [text("Title")]),
      th([attr.class(th_class)], [text("Branches")]),
      th([attr.class(th_class <> " w-28")], [text("State")]),
    ])
  let rows =
    list.map(mrs, fn(mr) {
      tr(
        [
          attr.class(
            "border-b border-slate-100 transition last:border-b-0 hover:bg-gh-accent-soft/30",
          ),
        ],
        [
          td([attr.class(td_class)], [
            a(
              [
                attr.href(routes.mr_detail_path(org, repo, mr.number)),
                attr.class("font-semibold tabular-nums text-gh-accent hover:underline"),
              ],
              [text("#" <> int.to_string(mr.number))],
            ),
          ]),
          td([attr.class(td_class)], [
            a(
              [
                attr.href(routes.mr_detail_path(org, repo, mr.number)),
                attr.class("font-medium text-gh-ink hover:text-gh-accent"),
              ],
              [text(mr.title)],
            ),
          ]),
          td([attr.class(td_class)], [
            span([attr.class("inline-flex items-center gap-1.5 font-mono text-xs text-gh-muted")], [
              span([attr.class("text-gh-ink")], [text(mr.source_branch)]),
              span([attr.class("text-gh-accent")], [text("→")]),
              span([attr.class("font-medium text-gh-ink")], [text(mr.target_branch)]),
            ]),
          ]),
          td([attr.class(td_class)], [state_badge(mr.state)]),
        ],
      )
    })
  table([attr.class("w-full text-sm")], [
    thead([attr.class("bg-slate-50/90")], [header]),
    tbody([], rows),
  ])
}

fn new_view(model: Model) -> Element(Msg) {
  div([attr.class(components.card)], [
    form(
      [attr.class("space-y-4"), event.on_submit(fn(_) { Create })],
      [
        label([attr.class("block text-sm font-medium text-gh-ink")], [
          text("Title"),
        ]),
        input([
          attr.class(components.input),
          attr.value(model.title),
          event.on_input(TitleChanged),
        ]),
        label([attr.class("block text-sm font-medium text-gh-ink")], [
          text("Description"),
        ]),
        textarea(
          [
            attr.class(components.textarea),
            attr.value(model.description),
            event.on_input(DescriptionChanged),
          ],
          "",
        ),
        branch_flow_picker(model),
        button([attr.type_("submit"), attr.class(components.btn_primary)], [
          text("Create merge request"),
        ]),
      ],
    ),
  ])
}

fn branch_flow_picker(model: Model) -> Element(Msg) {
  let show_summary =
    model.source_branch != "" && model.target_branch != ""
  div(
    [
      attr.class(
        "rounded-xl border border-slate-200 bg-gradient-to-br from-slate-50 to-white p-4",
      ),
    ],
    [
      p([attr.class("text-sm font-semibold text-gh-ink")], [text("Branches")]),
      p([attr.class("mb-4 text-sm text-gh-muted")], [
        text("Pick the branch you are merging from, then where it should land."),
      ]),
      div(
        [
          attr.class(
            "flex flex-col items-stretch gap-3 sm:flex-row sm:items-end",
          ),
        ],
        [
          branch_flow_field(
            caption: "From",
            hint: "Source branch",
            current: model.source_branch,
            branches: model.branches,
            on_change: SourceChanged,
          ),
          branch_flow_arrow(),
          branch_flow_field(
            caption: "Into",
            hint: "Target branch",
            current: model.target_branch,
            branches: model.branches,
            on_change: TargetChanged,
          ),
        ],
      ),
      case show_summary {
        False -> text("")
        True ->
          p(
            [
              attr.class(
                "mt-4 rounded-lg border border-gh-accent/20 bg-gh-accent-soft/40 px-3 py-2 text-center text-sm text-gh-ink",
              ),
            ],
            [
              span([attr.class("font-mono font-semibold")], [text(model.source_branch)]),
              text(" merges into "),
              span([attr.class("font-mono font-semibold")], [text(model.target_branch)]),
            ],
          )
      },
    ],
  )
}

fn branch_flow_arrow() -> Element(Msg) {
  div(
    [
      attr.class(
        "flex shrink-0 items-center justify-center self-center py-1 sm:px-1 sm:py-8",
      ),
    ],
    [
      span(
        [
          attr.class(
            "inline-flex h-10 w-10 items-center justify-center rounded-full bg-gh-accent-soft text-lg font-bold text-gh-accent",
          ),
          attr.title("merges into"),
        ],
        [text("→")],
      ),
    ],
  )
}

fn branch_flow_field(
  caption caption: String,
  hint hint: String,
  current current: String,
  branches branches: List(String),
  on_change on_change: fn(String) -> Msg,
) -> Element(Msg) {
  div([attr.class("min-w-0 flex-1")], [
    div([attr.class("mb-1.5 flex items-baseline gap-2")], [
      span([attr.class("text-xs font-semibold uppercase tracking-wide text-gh-accent")], [
        text(caption),
      ]),
      span([attr.class("text-xs text-gh-muted")], [text(hint)]),
    ]),
    select(
      [
        attr.class(components.input <> " font-mono text-sm"),
        event.on_change(on_change),
      ],
      list.map(branches, fn(b) {
        html_option(
          [
            attr.value(b),
            attr.selected(b == current),
          ],
          b,
        )
      }),
    ),
  ])
}
