import api.{type Org}
import components
import config.{type Config}
import gleam/list
import gleam/option
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, form, input}
import lustre/event
import lustre_http

pub type Model {
  Model(orgs: List(Org), slug: String, name: String, error: option.Option(String))
}

pub type Msg {
  Loaded(Result(List(Org), lustre_http.HttpError))
  SlugChanged(String)
  NameChanged(String)
  Create
  Created(Result(Org, lustre_http.HttpError))
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(Model(orgs: [], slug: "", name: "", error: option.None), effect.none())
}

pub fn on_load(config: Config) -> Effect(Msg) {
  lustre_http.get(
    config,
    config.api_url <> "/api/orgs",
    lustre_http.expect_json(api.orgs_decoder(), Loaded),
  )
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    Loaded(Ok(orgs)) -> #(Model(..model, orgs:, error: option.None), effect.none())
    Loaded(Error(lustre_http.Unauthorized)) -> #(
      Model(
        ..model,
        error: option.Some(
          "Unauthorized — ensure server CLERK_JWKS matches this Clerk app (see server/.env)",
        ),
      ),
      effect.none(),
    )
    Loaded(Error(lustre_http.BadUrl(url))) -> #(
      Model(..model, error: option.Some("Invalid API URL: " <> url)),
      effect.none(),
    )
    Loaded(Error(lustre_http.NetworkError)) -> #(
      Model(
        ..model,
        error: option.Some("Network error — is the API server running?"),
      ),
      effect.none(),
    )
    Loaded(Error(_)) -> #(
      Model(..model, error: option.Some("Failed to load orgs")),
      effect.none(),
    )
    SlugChanged(s) -> #(Model(..model, slug: s), effect.none())
    NameChanged(n) -> #(Model(..model, name: n), effect.none())
    Create -> #(
      model,
      lustre_http.post(
        config,
        config.api_url <> "/api/orgs",
        api.create_org_body(model.slug, model.name),
        lustre_http.expect_json(api.org_decoder(), Created),
      ),
    )
    Created(Ok(org)) -> #(
      Model(..model, orgs: [org, ..model.orgs], slug: "", name: ""),
      effect.none(),
    )
    Created(Error(_)) -> #(
      Model(..model, error: option.Some("Could not create org")),
      effect.none(),
    )
  }
}

pub fn view(model: Model) -> Element(Msg) {
  let org_list = case model.orgs {
    [] -> [components.empty_state("No organizations yet — create one below.")]
    orgs ->
      list.map(orgs, fn(org: Org) {
        components.list_link_card(
          "/orgs/" <> org.slug,
          org.name,
          option.Some(org.slug),
        )
      })
  }

  div([attr.class(components.page)], [
    components.page_header(
      "Organizations",
      "Create a team namespace and manage repositories under it.",
    ),
    case model.error {
      option.Some(e) -> components.error_alert(e)
      option.None -> text("")
    },
    div([attr.class(components.card <> " mb-6")], org_list),
    components.card_section("New organization", [
      form(
        [attr.class("space-y-4"), event.on_submit(fn(_) { Create })],
        [
          div([], [
            components.field_label("org-slug", "Slug"),
            input([
              attr.id("org-slug"),
              attr.class(components.input),
              attr.value(model.slug),
              attr.placeholder("my-team"),
              event.on_input(SlugChanged),
            ]),
          ]),
          div([], [
            components.field_label("org-name", "Display name"),
            input([
              attr.id("org-name"),
              attr.class(components.input),
              attr.value(model.name),
              attr.placeholder("My Team"),
              event.on_input(NameChanged),
            ]),
          ]),
          components.form_actions([
            button(
              [attr.class(components.btn_primary), attr.type_("submit")],
              [text("Create organization")],
            ),
          ]),
        ],
      ),
    ]),
  ])
}
