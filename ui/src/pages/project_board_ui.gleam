import components
import config.{type Config}
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import http/api
import http/list_query
import http/lustre_http
import lustre/attribute as attr
import lustre/effect.{type Effect, batch, none}
import lustre/element.{type Element, text}
import lustre/element/html.{
  a, button, div, input, li, option, p, select, span, ul,
}
import lustre/event
import routes.{issue_detail_path, mr_detail_path}

pub type AddCandidate {
  AddCandidate(
    item_type: String,
    repo_name: String,
    number: Int,
    title: String,
  )
}

pub type Model {
  Model(
    org_slug: String,
    project_number: Int,
    project: option.Option(api.Project),
    columns: List(api.ProjectColumn),
    repos: List(api.Repo),
    add_menu_open: Bool,
    add_filter: String,
    add_repo: option.Option(String),
    repo_issues: List(api.Issue),
    repo_mrs: List(api.MergeRequest),
    repo_items_loading: Bool,
    loading: Bool,
    saving: Bool,
    error: option.Option(String),
  )
}

pub type Msg {
  BoardLoaded(Result(api.ProjectBoard, lustre_http.HttpError))
  ReposLoaded(Result(List(api.Repo), lustre_http.HttpError))
  RepoIssuesLoaded(Result(List(api.Issue), lustre_http.HttpError))
  RepoMrsLoaded(Result(List(api.MergeRequest), lustre_http.HttpError))
  ToggleAddMenu
  AddFilterChanged(String)
  SelectAddRepo(String)
  AddItem(String, String, Int)
  ItemAdded(Result(api.ProjectItem, lustre_http.HttpError))
  MoveItem(String, String)
  ItemMoved(Result(api.ProjectItem, lustre_http.HttpError))
  RemoveItem(String)
  ItemRemoved(Result(Nil, lustre_http.HttpError))
}

fn api_base(config: Config, model: Model) -> String {
  config.api_url <> "/api/orgs/" <> model.org_slug <> "/projects/" <> int.to_string(
    model.project_number,
  )
}

fn org_api_base(config: Config, org_slug: String) -> String {
  config.api_url <> "/api/orgs/" <> org_slug
}

fn load_board(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model) <> "/board",
    lustre_http.expect_json(api.project_board_decoder(), BoardLoaded),
  )
}

fn load_repos(config: Config, org_slug: String) -> Effect(Msg) {
  lustre_http.get(
    config,
    org_api_base(config, org_slug) <> "/repos",
    lustre_http.expect_json(api.repos_decoder(), ReposLoaded),
  )
}

fn load_repo_issues(
  config: Config,
  org_slug: String,
  repo_name: String,
) -> Effect(Msg) {
  lustre_http.get(
    config,
    org_api_base(config, org_slug)
      <> "/repos/"
      <> repo_name
      <> "/issues"
      <> list_query.issue_list_query(list_query.IssueListFilters(
        ..list_query.default_issue_filters(),
        state: "all",
      )),
    lustre_http.expect_json(api.issues_decoder(), RepoIssuesLoaded),
  )
}

fn load_repo_mrs(
  config: Config,
  org_slug: String,
  repo_name: String,
) -> Effect(Msg) {
  lustre_http.get(
    config,
    org_api_base(config, org_slug)
      <> "/repos/"
      <> repo_name
      <> "/merge-requests"
      <> list_query.merge_request_list_query(list_query.MergeRequestListFilters(
        ..list_query.default_merge_request_filters(),
        state: "all",
      )),
    lustre_http.expect_json(api.merge_requests_decoder(), RepoMrsLoaded),
  )
}

pub fn init(org_slug: String, project_number: Int) -> Model {
  Model(
    org_slug:,
    project_number:,
    project: option.None,
    columns: [],
    repos: [],
    add_menu_open: False,
    add_filter: "",
    add_repo: option.None,
    repo_issues: [],
    repo_mrs: [],
    repo_items_loading: False,
    loading: True,
    saving: False,
    error: option.None,
  )
}

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  batch([
    load_board(config, model),
    load_repos(config, model.org_slug),
  ])
}

fn item_on_board(
  columns: List(api.ProjectColumn),
  item_type: String,
  repo_name: String,
  number: Int,
) -> Bool {
  list.any(columns, fn(column) {
    list.any(column.items, fn(item) {
      item.item_type == item_type
        && item.repo_name == repo_name
        && item.number == number
    })
  })
}

fn matches_filter(query: String, haystack: String) -> Bool {
  let needle = string.lowercase(string.trim(query))
  case needle {
    "" -> True
    _ -> string.contains(string.lowercase(haystack), needle)
  }
}

fn add_candidates(model: Model) -> List(AddCandidate) {
  let repo_name = option.unwrap(model.add_repo, "")
  let issue_candidates =
    list.filter(model.repo_issues, fn(issue) {
      !item_on_board(model.columns, "issue", repo_name, issue.number)
    })
    |> list.map(fn(issue) {
      AddCandidate(
        item_type: "issue",
        repo_name:,
        number: issue.number,
        title: issue.title,
      )
    })
  let mr_candidates =
    list.filter(model.repo_mrs, fn(mr) {
      !item_on_board(model.columns, "merge_request", repo_name, mr.number)
    })
    |> list.map(fn(mr) {
      AddCandidate(
        item_type: "merge_request",
        repo_name:,
        number: mr.number,
        title: mr.title,
      )
    })
  let all = list.append(issue_candidates, mr_candidates)
  list.filter(all, fn(candidate) {
    matches_filter(model.add_filter, candidate.title)
      || matches_filter(model.add_filter, int.to_string(candidate.number))
  })
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

fn item_link(item: api.ProjectItem) -> String {
  case item.item_type {
    "merge_request" ->
      mr_detail_path(item.org_slug, item.repo_name, item.number)
    _ -> issue_detail_path(item.org_slug, item.repo_name, item.number)
  }
}

fn item_type_label(item_type: String) -> String {
  case item_type {
    "merge_request" -> "MR"
    _ -> "Issue"
  }
}

fn card(
  model: Model,
  item: api.ProjectItem,
  columns: List(api.ProjectColumn),
) -> Element(Msg) {
  let other_columns =
    list.filter(columns, fn(column) { column.id != item_column_id(columns, item.id) })
  div([attr.class(components.list_item <> " project-board-card gap-2")], [
    a(
      [
        attr.href(item_link(item)),
        attr.class(
          "flex min-w-0 items-start gap-2 no-underline hover:opacity-80",
        ),
      ],
      [
        span([attr.class("comic-issue-num shrink-0")], [
          text("#" <> int.to_string(item.number)),
        ]),
        span([attr.class("min-w-0 flex-1 truncate text-sm font-semibold text-gh-ink")], [
          text(item.title),
        ]),
      ],
    ),
    div([attr.class("project-board-card-meta")], [
      span([attr.class("project-board-card-repo")], [text(item.repo_name)]),
      span([attr.class("project-board-card-type")], [
        text(item_type_label(item.item_type)),
      ]),
      state_badge(item.state),
    ]),
    div([attr.class("project-board-card-actions")], [
      select(
        [
          attr.class(components.input <> " project-board-card-move"),
          attr.title("Move to column"),
          event.on_change(fn(value) { MoveItem(item.id, value) }),
        ],
        list.append(
          [option([attr.value("")], "Move…")],
          list.map(other_columns, fn(column) {
            option([attr.value(column.id)], column.name)
          }),
        ),
      ),
      button([
        attr.type_("button"),
        attr.class("project-board-card-remove"),
        attr.disabled(model.saving),
        event.on_click(RemoveItem(item.id)),
      ], [text("Remove")]),
    ]),
  ])
}

fn item_column_id(columns: List(api.ProjectColumn), item_id: String) -> String {
  case list.find(columns, fn(column) {
    list.any(column.items, fn(item) { item.id == item_id })
  }) {
    Ok(column) -> column.id
    Error(_) -> ""
  }
}

fn column_view(model: Model, column: api.ProjectColumn) -> Element(Msg) {
  let count = int.to_string(list.length(column.items))
  div([attr.class("project-board-column comic-panel-inset")], [
    div([attr.class("project-board-column-header")], [
      span([attr.class("project-board-column-title")], [text(column.name)]),
      span([attr.class("project-board-column-count")], [
        text(count <> case count {
          "1" -> " item"
          _ -> " items"
        }),
      ]),
    ]),
    div([attr.class("project-board-cards")], list.map(
      column.items,
      fn(item) { card(model, item, model.columns) },
    )),
  ])
}

const popover_class =
  "comic-dropdown absolute right-0 z-40 mt-1 w-full min-w-[14rem] overflow-hidden py-1"

const search_input_class =
  "block w-full border-0 border-b-[3px] border-gh-ink bg-white px-3 py-2 text-sm font-medium text-gh-ink outline-none placeholder:text-gh-muted"

const empty_item_class = "px-3 py-2 text-sm font-medium text-gh-muted"

const menu_item_class = "mr-event-menu-item flex w-full items-center gap-2"

fn search_popover(model: Model) -> Element(Msg) {
  let candidates = add_candidates(model)
  div([attr.class(popover_class)], [
    input([
      attr.type_("text"),
      attr.placeholder("Search items…"),
      attr.value(model.add_filter),
      attr.class(search_input_class),
      event.on_input(AddFilterChanged),
    ]),
    case model.add_repo {
      option.None ->
        ul([attr.class("max-h-56 overflow-y-auto")], list.map(
          model.repos,
          fn(repo) {
            li([], [
              button(
                [
                  attr.type_("button"),
                  attr.class(menu_item_class),
                  event.on_click(SelectAddRepo(repo.name)),
                ],
                [span([attr.class("truncate font-bold")], [text(repo.name)])],
              ),
            ])
          },
        ))
      option.Some(_) ->
        case model.repo_items_loading {
          True -> p([attr.class(empty_item_class)], [text("Loading…")])
          False ->
            case candidates {
              [] -> p([attr.class(empty_item_class)], [
                text("No items match your search."),
              ])
              items ->
                ul([attr.class("max-h-56 overflow-y-auto")], list.map(
                  items,
                  fn(candidate) {
                    li([], [
                      button(
                        [
                          attr.type_("button"),
                          attr.class(menu_item_class),
                          event.on_click(AddItem(
                            candidate.item_type,
                            candidate.repo_name,
                            candidate.number,
                          )),
                        ],
                        [
                          span([attr.class("comic-issue-num shrink-0")], [
                            text("#" <> int.to_string(candidate.number)),
                          ]),
                          span([attr.class("truncate text-xs font-bold")], [
                            text(item_type_label(candidate.item_type)),
                          ]),
                          span([attr.class("truncate")], [text(candidate.title)]),
                        ],
                      ),
                    ])
                  },
                ))
            }
        }
    },
  ])
}

fn add_item_controls(model: Model) -> Element(Msg) {
  div([attr.class("relative")], [
    button([
      attr.type_("button"),
      attr.class(components.btn_secondary <> " !py-2 !text-xs"),
      event.on_click(ToggleAddMenu),
    ], [
      text(case model.add_menu_open {
        True -> "Done"
        False -> "Add item"
      }),
    ]),
    case model.add_menu_open {
      True -> search_popover(model)
      False -> text("")
    },
  ])
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    BoardLoaded(Ok(board)) -> #(
      Model(
        ..model,
        project: option.Some(board.project),
        columns: board.columns,
        loading: False,
        error: option.None,
      ),
      none(),
    )
    BoardLoaded(Error(_)) -> #(
      Model(
        ..model,
        loading: False,
        error: option.Some("Failed to load project board"),
      ),
      none(),
    )
    ReposLoaded(Ok(repos)) -> #(
      Model(..model, repos:, error: option.None),
      none(),
    )
    ReposLoaded(Error(_)) -> #(model, none())
    RepoIssuesLoaded(Ok(issues)) -> #(
      Model(..model, repo_issues: issues, repo_items_loading: False),
      none(),
    )
    RepoIssuesLoaded(Error(_)) -> #(
      Model(..model, repo_items_loading: False),
      none(),
    )
    RepoMrsLoaded(Ok(mrs)) -> #(
      Model(..model, repo_mrs: mrs, repo_items_loading: False),
      none(),
    )
    RepoMrsLoaded(Error(_)) -> #(
      Model(..model, repo_items_loading: False),
      none(),
    )
    ToggleAddMenu -> #(
      Model(
        ..model,
        add_menu_open: !model.add_menu_open,
        add_filter: "",
        add_repo: option.None,
        repo_issues: [],
        repo_mrs: [],
      ),
      none(),
    )
    AddFilterChanged(query) -> #(
      Model(..model, add_filter: query),
      none(),
    )
    SelectAddRepo(repo_name) -> #(
      Model(
        ..model,
        add_repo: option.Some(repo_name),
        add_filter: "",
        repo_issues: [],
        repo_mrs: [],
        repo_items_loading: True,
      ),
      batch([
        load_repo_issues(config, model.org_slug, repo_name),
        load_repo_mrs(config, model.org_slug, repo_name),
      ]),
    )
    AddItem(item_type, repo_name, number) -> #(
      Model(..model, saving: True, error: option.None),
      lustre_http.post(
        config,
        api_base(config, model) <> "/items",
        api.add_project_item_body(item_type, repo_name, number),
        lustre_http.expect_json(api.project_item_decoder(), ItemAdded),
      ),
    )
    ItemAdded(Ok(_)) -> #(
      Model(
        ..model,
        saving: False,
        add_menu_open: False,
        add_filter: "",
        add_repo: option.None,
        error: option.None,
      ),
      load_board(config, model),
    )
    ItemAdded(Error(_)) -> #(
      Model(
        ..model,
        saving: False,
        error: option.Some("Could not add item to project"),
      ),
      none(),
    )
    MoveItem(item_id, column_id) ->
      case string.trim(column_id) {
        "" -> #(model, none())
        target_column_id -> {
          let position = case list.find(model.columns, fn(column) {
            column.id == target_column_id
          }) {
            Ok(column) -> list.length(column.items)
            Error(_) -> 0
          }
          #(
            Model(..model, saving: True, error: option.None),
            lustre_http.patch(
              config,
              api_base(config, model) <> "/items/" <> item_id,
              api.move_project_item_body(target_column_id, position),
              lustre_http.expect_json(api.project_item_decoder(), ItemMoved),
            ),
          )
        }
      }
    ItemMoved(Ok(_)) -> #(
      Model(..model, saving: False, error: option.None),
      load_board(config, model),
    )
    ItemMoved(Error(_)) -> #(
      Model(
        ..model,
        saving: False,
        error: option.Some("Could not move item"),
      ),
      none(),
    )
    RemoveItem(item_id) -> #(
      Model(..model, saving: True, error: option.None),
      lustre_http.delete(
        config,
        api_base(config, model) <> "/items/" <> item_id,
        lustre_http.expect_anything(ItemRemoved),
      ),
    )
    ItemRemoved(Ok(_)) -> #(
      Model(..model, saving: False, error: option.None),
      load_board(config, model),
    )
    ItemRemoved(Error(_)) -> #(
      Model(
        ..model,
        saving: False,
        error: option.Some("Could not remove item"),
      ),
      none(),
    )
  }
}

pub fn view(model: Model) -> Element(Msg) {
  case model.loading {
    True -> components.loading_state()
    False ->
      div([attr.class(components.card <> " project-board-shell !p-0")], [
        div([attr.class("project-board-toolbar")], [add_item_controls(model)]),
        case model.columns {
          [] ->
            div([attr.class("p-5")], [
              components.empty_state("This project has no columns yet."),
            ])
          columns ->
            div(
              [attr.class("project-board-columns")],
              list.map(columns, fn(column) { column_view(model, column) }),
            )
        },
      ])
  }
}
