import api.{type Issue}
import components
import config.{type Config}
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import lustre/attribute as attr
import lustre/effect.{type Effect, none}
import lustre/element.{type Element, text}
import lustre/element/html.{a, button, div, form, h2, input, label, p, span, table, tbody, td, textarea, th, thead, tr}
import lustre/event
import lustre_http
import modem
import routes

pub type Model {
  Model(
    org_slug: String,
    repo_name: String,
    mode: Mode,
    issues: List(Issue),
    title: String,
    description: String,
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
  Loaded(Result(List(Issue), lustre_http.HttpError))
  ListSearchChanged(String)
  TitleChanged(String)
  DescriptionChanged(String)
  Create
  Created(Result(Issue, lustre_http.HttpError))
}

pub fn init(org_slug: String, repo_name: String, mode: Mode) -> Model {
  Model(
    org_slug:,
    repo_name:,
    mode:,
    issues: [],
    title: "",
    description: "",
    list_search: "",
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
      lustre_http.get(
        config,
        api_base(config, model) <> "/issues",
        lustre_http.expect_json(api.issues_decoder(), Loaded),
      )
    New -> none()
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
    Loaded(Ok(issues)) -> #(
      Model(..model, issues:, loading: False, error: option.None),
      none(),
    )
    Loaded(Error(_)) -> #(
      Model(..model, loading: False, error: option.Some("Failed to load issues")),
      none(),
    )
    ListSearchChanged(v) -> #(Model(..model, list_search: v), none())
    TitleChanged(v) -> #(Model(..model, title: v), none())
    DescriptionChanged(v) -> #(Model(..model, description: v), none())
    Create -> #(
      model,
      lustre_http.post(
        config,
        api_base(config, model) <> "/issues",
        api.create_issue_body(
          model.title,
          case model.description {
            "" -> option.None
            d -> option.Some(d)
          },
        ),
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
  let title = model.org_slug <> " / " <> model.repo_name <> " — Issues"
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
          attr.href(routes.issue_new_path(model.org_slug, model.repo_name)),
        ],
        [text("New issue")],
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
  case model.issues {
    [] -> components.empty_state("No issues yet. Open one to track bugs or tasks.")
    _ -> {
      let filtered = filter_issues(model.issues, model.list_search)
      div([attr.class(components.card <> " !p-0 overflow-hidden")], [
        list_toolbar(model, filtered),
        case filtered {
          [] ->
            div([attr.class("px-6 pb-8")], [
              components.empty_state("No issues match your search."),
            ])
          issues ->
            div([attr.class("overflow-x-auto")], [
              table_issues(issues, model.org_slug, model.repo_name),
            ])
        },
      ])
    }
  }
}

fn filter_issues(issues: List(Issue), query: String) -> List(Issue) {
  let needle = string.lowercase(string.trim(query))
  case needle {
    "" -> issues
    _ ->
      list.filter(issues, fn(issue) {
        string.contains(string.lowercase(issue.title), needle)
      })
  }
}

fn list_toolbar(model: Model, filtered: List(Issue)) -> Element(Msg) {
  let total = list.length(model.issues)
  let shown = list.length(filtered)
  let count_label = case string.trim(model.list_search) {
    "" -> int.to_string(total) <> " issue" <> plural_suffix(total)
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
      label([attr.class("sr-only")], [text("Search issues by title")]),
      input([
        attr.type_("search"),
        attr.name("issue-search"),
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

fn table_issues(
  issues: List(Issue),
  org: String,
  repo: String,
) -> Element(Msg) {
  let th_class = "px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gh-muted"
  let td_class = "px-4 py-3 align-middle"
  let header =
    tr([attr.class("border-b border-slate-200 bg-white")], [
      th([attr.class(th_class <> " w-16")], [text("#")]),
      th([attr.class(th_class)], [text("Title")]),
      th([attr.class(th_class <> " w-28")], [text("State")]),
    ])
  let rows =
    list.map(issues, fn(issue) {
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
                attr.href(routes.issue_detail_path(org, repo, issue.number)),
                attr.class("font-semibold tabular-nums text-gh-accent hover:underline"),
              ],
              [text("#" <> int.to_string(issue.number))],
            ),
          ]),
          td([attr.class(td_class)], [
            a(
              [
                attr.href(routes.issue_detail_path(org, repo, issue.number)),
                attr.class("font-medium text-gh-ink hover:text-gh-accent"),
              ],
              [text(issue.title)],
            ),
          ]),
          td([attr.class(td_class)], [state_badge(issue.state)]),
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
        button([attr.type_("submit"), attr.class(components.btn_primary)], [
          text("Create issue"),
        ]),
      ],
    ),
  ])
}
