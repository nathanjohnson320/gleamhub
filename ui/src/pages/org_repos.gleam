import api.{type Repo}
import components
import config.{type Config}
import gleam/list
import gleam/option
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{a, button, div, form, input, p}
import lustre/event
import lustre_http
import routes

pub type Model {
  Model(
    org_slug: String,
    repos: List(Repo),
    name: String,
    error: option.Option(String),
    confirm_delete: option.Option(Repo),
  )
}

pub type Msg {
  Loaded(Result(List(Repo), lustre_http.HttpError))
  NameChanged(String)
  Create
  Created(Result(Repo, lustre_http.HttpError))
  RequestDelete(Repo)
  CancelDelete
  ConfirmDelete
  Deleted(Result(Nil, lustre_http.HttpError))
}

pub fn init(org_slug: String) -> Model {
  Model(
    org_slug:,
    repos: [],
    name: "",
    error: option.None,
    confirm_delete: option.None,
  )
}

pub fn on_load(config: Config, org_slug: String) -> Effect(Msg) {
  lustre_http.get(
    config,
    config.api_url <> "/api/orgs/" <> org_slug <> "/repos",
    lustre_http.expect_json(api.repos_decoder(), Loaded),
  )
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    Loaded(Ok(repos)) ->
      #(
        Model(..model, repos:, error: option.None, confirm_delete: option.None),
        effect.none(),
      )
    Loaded(Error(_)) -> #(
      Model(..model, error: option.Some("Failed to load repos")),
      effect.none(),
    )
    NameChanged(n) -> #(Model(..model, name: n), effect.none())
    Create -> #(
      model,
      lustre_http.post(
        config,
        config.api_url <> "/api/orgs/" <> model.org_slug <> "/repos",
        api.create_repo_body(model.name, option.None),
        lustre_http.expect_json(api.repo_decoder(), Created),
      ),
    )
    Created(Ok(repo)) -> #(
      Model(..model, repos: [repo, ..model.repos], name: "", error: option.None),
      effect.none(),
    )
    Created(Error(_)) -> #(
      Model(..model, error: option.Some("Could not create repo")),
      effect.none(),
    )
    RequestDelete(repo) -> #(
      Model(..model, confirm_delete: option.Some(repo), error: option.None),
      effect.none(),
    )
    CancelDelete -> #(
      Model(..model, confirm_delete: option.None),
      effect.none(),
    )
    ConfirmDelete -> {
      case model.confirm_delete {
        option.None -> #(model, effect.none())
        option.Some(repo) -> #(
          Model(..model, confirm_delete: option.None),
          lustre_http.delete(
            config,
            config.api_url
              <> "/api/orgs/"
              <> model.org_slug
              <> "/repos/"
              <> repo.name,
            lustre_http.expect_anything(Deleted),
          ),
        )
      }
    }
    Deleted(Ok(_)) -> #(
      model,
      on_load(config, model.org_slug),
    )
    Deleted(Error(lustre_http.OtherError(403, _))) -> #(
      Model(
        ..model,
        error: option.Some("Only organization owners can delete repositories"),
      ),
      effect.none(),
    )
    Deleted(Error(lustre_http.NotFound)) -> #(
      Model(
        ..model,
        error: option.Some("Repository not found — refreshing list"),
      ),
      on_load(config, model.org_slug),
    )
    Deleted(Error(_)) -> #(
      Model(..model, error: option.Some("Could not delete repository")),
      effect.none(),
    )
  }
}

fn repo_row(page_org_slug: String, repo: Repo) -> Element(Msg) {
  let org_slug = routes.org_slug_for_repo(page_org_slug, repo.org_slug)
  div(
    [
      attr.class(
        "rounded-lg border border-slate-100 bg-slate-50/50 px-4 py-4 transition hover:border-gh-accent/30 hover:bg-gh-accent-soft/40",
      ),
    ],
    [
      a(
        [
          attr.href(routes.repo_home_path(org_slug, repo.name)),
          attr.class("font-semibold text-gh-ink hover:text-gh-accent"),
        ],
        [text(repo.name)],
      ),
      div([attr.class("mt-3 flex items-center gap-3")], [
        p([attr.class("min-w-0 flex-1 " <> components.code_block)], [
          text(repo.clone_url),
        ]),
        button(
          [
            attr.class(components.btn_danger <> " shrink-0"),
            attr.type_("button"),
            event.on_click(RequestDelete(repo)),
          ],
          [text("Delete")],
        ),
      ]),
    ],
  )
}

pub fn view(model: Model) -> Element(Msg) {
  let repo_list = case model.repos {
    [] -> [components.empty_state("No repositories yet — add one below.")]
    repos -> list.map(repos, fn(r) { repo_row(model.org_slug, r) })
  }

  let confirm = case model.confirm_delete {
    option.Some(repo) ->
      components.confirm_banner(
        "Delete repository?",
        "Permanently delete "
          <> repo.name
          <> " and its git data on disk? This cannot be undone.",
        ConfirmDelete,
        CancelDelete,
      )
    option.None -> text("")
  }

  div([attr.class(components.page)], [
    components.breadcrumb_back("/orgs", "Organizations"),
    components.page_header(
      model.org_slug,
      "Git repositories in this organization. Clone with the SSH URL below.",
    ),
    case model.error {
      option.Some(e) -> components.error_alert(e)
      option.None -> text("")
    },
    confirm,
    div([attr.class(components.card <> " mb-6")], repo_list),
    components.card_section("New repository", [
      form(
        [attr.class("space-y-4"), event.on_submit(fn(_) { Create })],
        [
          div([], [
            components.field_label("repo-name", "Repository name"),
            input([
              attr.id("repo-name"),
              attr.class(components.input),
              attr.value(model.name),
              attr.placeholder("my_app"),
              event.on_input(NameChanged),
            ]),
          ]),
          components.form_actions([
            button(
              [attr.class(components.btn_primary), attr.type_("submit")],
              [text("Create repository")],
            ),
          ]),
        ],
      ),
    ]),
  ])
}
