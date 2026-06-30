import components
import config.{type Config}
import content/markdown
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import http/api
import http/lustre_http
import lustre/attribute as attr
import lustre/effect.{type Effect, batch, none}
import lustre/element.{type Element, map, text, unsafe_raw_html}
import lustre/element/html.{a, button, div, form, h2, input, label, p, span, textarea}
import lustre/event
import modem
import pages/org_access
import pages/org_nav
import pages/project_board_ui
import routes.{project_detail_path, project_list_path, project_new_path}

pub type Mode {
  List
  New
  Detail(Int)
}

pub type Model {
  Model(
    org_slug: String,
    mode: Mode,
    gate: org_access.Gate,
    org_name: String,
    projects: List(api.Project),
    detail: option.Option(api.Project),
    board: option.Option(project_board_ui.Model),
    title: String,
    description: String,
    editing: Bool,
    edit_title: String,
    edit_description: String,
    saving: Bool,
    loading: Bool,
    error: option.Option(String),
  )
}

pub type Msg {
  OrgLoaded(Result(api.Org, lustre_http.HttpError))
  ProjectsLoaded(Result(List(api.Project), lustre_http.HttpError))
  DetailLoaded(Result(api.Project, lustre_http.HttpError))
  BoardMsg(project_board_ui.Msg)
  TitleChanged(String)
  DescriptionChanged(String)
  Create
  Created(Result(api.Project, lustre_http.HttpError))
  StartEdit
  CancelEdit
  EditTitleChanged(String)
  EditDescriptionChanged(String)
  SaveEdit
  Saved(Result(api.Project, lustre_http.HttpError))
  CloseProject
  Closed(Result(api.Project, lustre_http.HttpError))
}

fn api_base(config: Config, org_slug: String) -> String {
  config.api_url <> "/api/orgs/" <> org_slug
}

fn load_projects(config: Config, org_slug: String) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, org_slug) <> "/projects",
    lustre_http.expect_json(api.projects_decoder(), ProjectsLoaded),
  )
}

fn load_detail(config: Config, org_slug: String, number: Int) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, org_slug) <> "/projects/" <> int.to_string(number),
    lustre_http.expect_json(api.project_decoder(), DetailLoaded),
  )
}

pub fn init(org_slug: String, mode: Mode) -> Model {
  let board = case mode {
    Detail(number) -> option.Some(project_board_ui.init(org_slug, number))
    _ -> option.None
  }
  Model(
    org_slug:,
    mode:,
    gate: org_access.Pending,
    org_name: "",
    projects: [],
    detail: option.None,
    board:,
    title: "",
    description: "",
    editing: False,
    edit_title: "",
    edit_description: "",
    saving: False,
    loading: True,
    error: option.None,
  )
}

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  let org_effect =
    lustre_http.get(
      config,
      api_base(config, model.org_slug),
      lustre_http.expect_json(api.org_decoder(), OrgLoaded),
    )
  case model.mode {
    List -> batch([org_effect, load_projects(config, model.org_slug)])
    New -> batch([org_effect, load_projects(config, model.org_slug)])
    Detail(number) ->
      batch([
        org_effect,
        load_detail(config, model.org_slug, number),
        case model.board {
          option.Some(board) ->
            effect.map(project_board_ui.on_load(config, board), BoardMsg)
          option.None ->
            effect.map(
              project_board_ui.on_load(
                config,
                project_board_ui.init(model.org_slug, number),
              ),
              BoardMsg,
            )
        },
      ])
  }
}

fn state_badge(state: String) -> Element(Msg) {
  let state_class = case state {
    "open" -> "comic-state-badge comic-state-open"
    "closed" -> "comic-state-badge comic-state-closed"
    _ -> "comic-state-badge comic-state-closed"
  }
  span([attr.class(state_class <> " shrink-0")], [text(state)])
}

fn project_status_badges(state: String) -> Element(Msg) {
  div([attr.class("flex flex-wrap items-center gap-1.5")], [state_badge(state)])
}

fn project_row(model: Model, project: api.Project) -> Element(Msg) {
  a(
    [
      attr.href(project_detail_path(model.org_slug, project.number)),
      attr.class(components.list_item <> " no-underline"),
    ],
    [
      div([attr.class("flex min-w-0 items-center gap-2")], [
        span([attr.class("comic-issue-num shrink-0")], [
          text("#" <> int.to_string(project.number)),
        ]),
        span([attr.class("truncate font-bold text-gh-ink")], [text(project.title)]),
      ]),
      state_badge(project.state),
    ],
  )
}

fn list_view(model: Model) -> Element(Msg) {
  div([], [
    div([attr.class("mb-4 flex items-center justify-between")], [
      h2([attr.class(components.section_title)], [text("Projects")]),
      a(
        [
          attr.href(project_new_path(model.org_slug)),
          attr.class(components.btn_primary),
        ],
        [text("New project")],
      ),
    ]),
    case model.loading {
      True -> components.loading_state()
      False ->
        case model.projects {
          [] -> components.empty_state("No projects yet.")
          projects ->
            div([attr.class("space-y-3")], list.map(projects, fn(project) {
              project_row(model, project)
            }))
        }
    },
  ])
}

fn new_view(model: Model) -> Element(Msg) {
  div([attr.class(components.card <> " p-4 max-w-xl")], [
    h2([attr.class("text-lg font-semibold mb-4")], [text("New project")]),
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
        div([attr.class("flex gap-2")], [
          button([
            attr.type_("submit"),
            attr.class(components.btn_primary),
            attr.disabled(model.saving),
          ], [text("Create project")]),
          a(
            [
              attr.href(project_list_path(model.org_slug)),
              attr.class(components.btn_secondary),
            ],
            [text("Cancel")],
          ),
        ]),
      ]),
    ]),
  ])
}

fn markdown_body(content: String) -> Element(Msg) {
  unsafe_raw_html(
    "",
    "div",
    [attr.class("markdown-body text-sm")],
    markdown.to_html(content),
  )
}

fn detail_header(model: Model, project: api.Project) -> Element(Msg) {
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
          div([attr.class("min-w-0 flex-1 space-y-2")], [
            h2([attr.class("text-xl font-semibold text-gh-ink")], [
              text(project.title),
            ]),
            div([attr.class("detail-header-meta")], [
              project_status_badges(project.state),
              span([attr.class("text-sm font-medium text-gh-muted")], [
                text("#" <> int.to_string(project.number)),
              ]),
            ]),
          ]),
          div([attr.class("flex shrink-0 gap-2")], [
            case project.state {
              "open" ->
                button([
                  attr.type_("button"),
                  attr.class(components.btn_secondary),
                  event.on_click(StartEdit),
                ], [text("Edit")])
              _ -> text("")
            },
            case project.state {
              "open" ->
                button([
                  attr.type_("button"),
                  attr.class(components.btn_secondary),
                  attr.disabled(model.saving),
                  event.on_click(CloseProject),
                ], [text("Close project")])
              _ -> text("")
            },
          ]),
        ]),
        case project.description {
          option.Some(body) -> div([attr.class("mt-4")], [markdown_body(body)])
          option.None -> text("")
        },
      ])
  }
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
    option.Some(project) ->
      div([], [
        div([attr.class("mb-4")], [
          components.breadcrumb_back(
            project_list_path(model.org_slug),
            "Projects",
          ),
        ]),
        div([attr.class(components.card <> " mb-4 p-4")], [
          detail_header(model, project),
        ]),
        case model.board {
          option.Some(board) -> map(project_board_ui.view(board), BoardMsg)
          option.None -> components.loading_state()
        },
      ])
  }
}

fn page_body(model: Model) -> Element(Msg) {
  let error = case model.error {
    option.Some(e) -> components.error_alert(e)
    option.None -> text("")
  }
  let body = case model.mode {
    List -> list_view(model)
    New -> new_view(model)
    Detail(_) -> detail_view(model)
  }
  div([attr.class("mt-6")], [error, body])
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    OrgLoaded(Ok(org)) -> #(
      Model(
        ..model,
        gate: org_access.Allowed(org.role, org.name),
        org_name: org.name,
        error: option.None,
      ),
      none(),
    )
    OrgLoaded(Error(err)) -> #(
      Model(..model, gate: org_access.gate_from_org(Error(err))),
      none(),
    )
    ProjectsLoaded(Ok(projects)) -> #(
      Model(..model, projects:, loading: False, error: option.None),
      none(),
    )
    ProjectsLoaded(Error(_)) -> #(
      Model(
        ..model,
        loading: False,
        error: option.Some("Failed to load projects"),
      ),
      none(),
    )
    DetailLoaded(Ok(project)) -> #(
      Model(
        ..model,
        detail: option.Some(project),
        board: case model.board {
          option.Some(board) -> option.Some(board)
          option.None ->
            option.Some(project_board_ui.init(model.org_slug, project.number))
        },
        edit_title: project.title,
        edit_description: option.unwrap(project.description, ""),
        loading: False,
        error: option.None,
      ),
      none(),
    )
    DetailLoaded(Error(_)) -> #(
      Model(
        ..model,
        loading: False,
        error: option.Some("Project not found"),
      ),
      none(),
    )
    BoardMsg(board_msg) ->
      case model.board {
        option.Some(board) -> {
          let #(board, eff) = project_board_ui.update(board_msg, board, config)
          let board_error = board.error
          #(
            Model(
              ..model,
              board: option.Some(board),
              error: board_error,
            ),
            effect.map(eff, BoardMsg),
          )
        }
        option.None -> #(model, none())
      }
    TitleChanged(title) -> #(Model(..model, title:), none())
    DescriptionChanged(description) -> #(
      Model(..model, description:),
      none(),
    )
    Create -> #(
      Model(..model, saving: True, error: option.None),
      lustre_http.post(
        config,
        api_base(config, model.org_slug) <> "/projects",
        api.create_project_body(
          string.trim(model.title),
          case string.trim(model.description) {
            "" -> option.None
            text -> option.Some(text)
          },
        ),
        lustre_http.expect_json(api.project_decoder(), Created),
      ),
    )
    Created(Ok(project)) -> #(
      model,
      modem.replace(
        project_detail_path(model.org_slug, project.number),
        option.None,
        option.None,
      ),
    )
    Created(Error(_)) -> #(
      Model(
        ..model,
        saving: False,
        error: option.Some("Could not create project"),
      ),
      none(),
    )
    StartEdit -> #(
      Model(..model, editing: True, error: option.None),
      none(),
    )
    CancelEdit ->
      case model.detail {
        option.Some(project) -> #(
          Model(
            ..model,
            editing: False,
            edit_title: project.title,
            edit_description: option.unwrap(project.description, ""),
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
    SaveEdit ->
      case model.detail {
        option.Some(project) -> #(
          Model(..model, saving: True, error: option.None),
          lustre_http.patch(
            config,
            api_base(config, model.org_slug)
              <> "/projects/"
              <> int.to_string(project.number),
            api.update_project_body(
              option.Some(string.trim(model.edit_title)),
              case string.trim(model.edit_description) {
                "" -> option.Some("")
                text -> option.Some(text)
              },
              option.None,
            ),
            lustre_http.expect_json(api.project_decoder(), Saved),
          ),
        )
        option.None -> #(model, none())
      }
    Saved(Ok(project)) -> #(
      Model(
        ..model,
        detail: option.Some(project),
        edit_title: project.title,
        edit_description: option.unwrap(project.description, ""),
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
        error: option.Some("Could not save project"),
      ),
      none(),
    )
    CloseProject ->
      case model.detail {
        option.Some(project) -> #(
          Model(..model, saving: True, error: option.None),
          lustre_http.patch(
            config,
            api_base(config, model.org_slug)
              <> "/projects/"
              <> int.to_string(project.number),
            api.update_project_body(
              option.None,
              option.None,
              option.Some("closed"),
            ),
            lustre_http.expect_json(api.project_decoder(), Closed),
          ),
        )
        option.None -> #(model, none())
      }
    Closed(Ok(project)) -> #(
      Model(
        ..model,
        detail: option.Some(project),
        editing: False,
        saving: False,
        error: option.None,
      ),
      none(),
    )
    Closed(Error(_)) -> #(
      Model(
        ..model,
        saving: False,
        error: option.Some("Could not close project"),
      ),
      none(),
    )
  }
}

pub fn view(model: Model) -> Element(Msg) {
  let page_class = case model.mode {
    Detail(_) -> components.page_wide
    _ -> components.page
  }
  case model.gate {
    org_access.Pending -> org_access.pending_view()
    org_access.Forbidden -> org_access.forbidden_view()
    org_access.NotFound -> org_access.not_found_view()
    org_access.Failed(message) -> org_access.failed_view(message)
    org_access.Allowed(_, org_name) ->
      div([attr.class(page_class)], [
        components.breadcrumb_back("/orgs", "Organizations"),
        components.page_header(org_name, "Projects and kanban boards."),
        org_nav.tabs(model.org_slug, org_nav.Projects),
        page_body(model),
      ])
  }
}
