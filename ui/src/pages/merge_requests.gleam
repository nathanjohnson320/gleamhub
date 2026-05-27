import api.{type MergeRequest}
import components
import config.{type Config}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import lustre/attribute as attr
import lustre/effect.{type Effect, batch, none}
import lustre/element.{type Element, text}
import lustre/element/html.{
  a, button, div, form, h2, input, label, option as html_option, select,
  table, tbody, td, textarea, th, thead, tr,
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
    mrs ->
      div([attr.class(components.card)], [
        div([attr.class("overflow-x-auto")], [
          table_mrs(mrs, model.org_slug, model.repo_name),
        ]),
      ])
  }
}

fn table_mrs(
  mrs: List(MergeRequest),
  org: String,
  repo: String,
) -> Element(Msg) {
  let header =
    tr([], [
      th([attr.class("text-left text-sm text-gh-muted")], [text("#")]),
      th([attr.class("text-left text-sm text-gh-muted")], [text("Title")]),
      th([attr.class("text-left text-sm text-gh-muted")], [text("Branches")]),
      th([attr.class("text-left text-sm text-gh-muted")], [text("State")]),
    ])
  let rows =
    list.map(mrs, fn(mr) {
      tr([], [
        td([], [
          a(
            [
              attr.href(routes.mr_detail_path(org, repo, mr.number)),
              attr.class("font-medium text-gh-accent hover:underline"),
            ],
            [text("#" <> int.to_string(mr.number))],
          ),
        ]),
        td([], [text(mr.title)]),
        td([], [text(mr.source_branch <> " → " <> mr.target_branch)]),
        td([], [text(mr.state)]),
      ])
    })
  table([attr.class("w-full text-sm")], [thead([], [header]), tbody([], rows)])
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
        branch_select("Source branch", model.source_branch, model.branches, SourceChanged),
        branch_select("Target branch", model.target_branch, model.branches, TargetChanged),
        button([attr.type_("submit"), attr.class(components.btn_primary)], [
          text("Create merge request"),
        ]),
      ],
    ),
  ])
}

fn branch_select(
  label_text: String,
  current: String,
  branches: List(String),
  on_change: fn(String) -> Msg,
) -> Element(Msg) {
  div([], [
    label([attr.class("block text-sm font-medium text-gh-ink")], [text(label_text)]),
    select(
      [
        attr.class(components.input),
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
