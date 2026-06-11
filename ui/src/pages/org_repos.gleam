import components
import config.{type Config}
import gleam/list
import gleam/option
import gleam/string
import http/api
import http/lustre_http
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, form, input}
import lustre/event
import pages/org_access
import pages/org_nav
import routes

pub type Model {
  Model(
    org_slug: String,
    gate: org_access.Gate,
    repos: List(api.Repo),
    filter: String,
    name: String,
    error: option.Option(String),
  )
}

pub type Msg {
  OrgLoaded(Result(api.Org, lustre_http.HttpError))
  ReposLoaded(Result(List(api.Repo), lustre_http.HttpError))
  FilterChanged(String)
  NameChanged(String)
  Create
  Created(Result(api.Repo, lustre_http.HttpError))
}

pub fn init(org_slug: String) -> Model {
  Model(
    org_slug:,
    gate: org_access.Pending,
    repos: [],
    filter: "",
    name: "",
    error: option.None,
  )
}

pub fn on_load(config: Config, org_slug: String) -> Effect(Msg) {
  lustre_http.get(
    config,
    config.api_url <> "/api/orgs/" <> org_slug,
    lustre_http.expect_json(api.org_decoder(), OrgLoaded),
  )
}

fn reload_repos(config: Config, org_slug: String) -> Effect(Msg) {
  lustre_http.get(
    config,
    config.api_url <> "/api/orgs/" <> org_slug <> "/repos",
    lustre_http.expect_json(api.repos_decoder(), ReposLoaded),
  )
}

fn repo_matches_filter(repo: api.Repo, filter: String) -> Bool {
  let query = string.lowercase(string.trim(filter))
  case query {
    "" -> True
    _ -> {
      let in_name = string.contains(string.lowercase(repo.name), query)
      let in_description = case repo.description {
        option.Some(d) -> string.contains(string.lowercase(d), query)
        option.None -> False
      }
      in_name || in_description
    }
  }
}

fn filtered_repos(repos: List(api.Repo), filter: String) -> List(api.Repo) {
  list.filter(repos, fn(r) { repo_matches_filter(r, filter) })
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    OrgLoaded(Ok(org)) -> #(
      Model(
        ..model,
        gate: org_access.Allowed(org.role, org.name),
        error: option.None,
      ),
      reload_repos(config, model.org_slug),
    )
    OrgLoaded(Error(err)) -> #(
      Model(..model, gate: org_access.gate_from_org(Error(err))),
      effect.none(),
    )
    ReposLoaded(Ok(repos)) -> #(
      Model(..model, repos:, error: option.None),
      effect.none(),
    )
    ReposLoaded(Error(err)) -> #(
      Model(
        ..model,
        error: option.Some(repos_error_message(err)),
        gate: case err {
          lustre_http.OtherError(403, _) -> org_access.Forbidden
          _ -> model.gate
        },
      ),
      effect.none(),
    )
    FilterChanged(f) -> #(Model(..model, filter: f), effect.none())
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
  }
}

fn repos_error_message(err: lustre_http.HttpError) -> String {
  case err {
    lustre_http.OtherError(403, _) ->
      "You don't have access to this organization."
    _ -> "Failed to load repos"
  }
}

pub fn view(model: Model) -> Element(Msg) {
  case model.gate {
    org_access.Pending -> org_access.pending_view()
    org_access.Forbidden -> org_access.forbidden_view()
    org_access.NotFound -> org_access.not_found_view()
    org_access.Failed(message) -> org_access.failed_view(message)
    org_access.Allowed(_, org_name) -> repos_view(model, org_name)
  }
}

fn repos_view(model: Model, org_name: String) -> Element(Msg) {
  let visible = filtered_repos(model.repos, model.filter)
  let repo_list = case visible {
    [] ->
      case model.repos {
        [] -> [components.empty_state("No repositories yet - add one below.")]
        _ -> [components.empty_state("No repositories match your search.")]
      }
    repos ->
      list.map(repos, fn(repo) {
        let org_slug = routes.org_slug_for_repo(model.org_slug, repo.org_slug)
        components.list_link_card(
          routes.repo_home_path(org_slug, repo.name),
          repo.name,
          repo.description,
        )
      })
  }

  div([attr.class(components.page)], [
    components.breadcrumb_back("/orgs", "Organizations"),
    components.page_header(org_name, "Git repositories in this organization."),
    org_nav.tabs(model.org_slug, org_nav.Repositories),
    div([attr.class("mt-6")], [
      case model.error {
        option.Some(e) -> components.error_alert(e)
        option.None -> text("")
      },
      div([attr.class(components.card <> " mb-6")], [
        div([attr.class("mb-4")], [
          components.field_label("repo-filter", "Search repositories"),
          input([
            attr.id("repo-filter"),
            attr.class(components.input),
            attr.value(model.filter),
            attr.placeholder("Filter by name or description…"),
            event.on_input(FilterChanged),
          ]),
        ]),
        div([attr.class("space-y-2")], repo_list),
      ]),
      components.card_section("New repository", [
        form([attr.class("space-y-4"), event.on_submit(fn(_) { Create })], [
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
            button([attr.class(components.btn_primary), attr.type_("submit")], [
              text("Create repository"),
            ]),
          ]),
        ]),
      ]),
    ]),
  ])
}
