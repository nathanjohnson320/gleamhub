import components
import config.{type Config}
import gleam/json
import gleam/list
import gleam/option
import http/api.{type Org, type OrgInvitation}
import http/lustre_http
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, form, input, p}
import lustre/event
import pages/org_slug
import routes

pub type Model {
  Model(
    orgs: List(Org),
    invitations: List(OrgInvitation),
    slug: String,
    name: String,
    slug_manual: Bool,
    error: option.Option(String),
  )
}

pub type Msg {
  OrgsLoaded(Result(List(Org), lustre_http.HttpError))
  InvitationsLoaded(Result(List(OrgInvitation), lustre_http.HttpError))
  SlugChanged(String)
  NameChanged(String)
  Create
  Created(Result(Org, lustre_http.HttpError))
  AcceptInvitation(String)
  Accepted(Result(api.AcceptInvitation, lustre_http.HttpError))
  DeclineInvitation(String)
  Declined(Result(Nil, lustre_http.HttpError))
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(
      orgs: [],
      invitations: [],
      slug: "",
      name: "",
      slug_manual: False,
      error: option.None,
    ),
    effect.none(),
  )
}

pub fn on_load(config: Config) -> Effect(Msg) {
  effect.batch([
    lustre_http.get(
      config,
      config.api_url <> "/api/orgs",
      lustre_http.expect_json(api.orgs_decoder(), OrgsLoaded),
    ),
    lustre_http.get(
      config,
      config.api_url <> "/api/invitations",
      lustre_http.expect_json(api.invitations_decoder(), InvitationsLoaded),
    ),
  ])
}

fn reload_all(config: Config) -> Effect(Msg) {
  on_load(config)
}

fn org_name(invitation: OrgInvitation) -> String {
  invitation.org_name
  |> option.unwrap(invitation.org_slug |> option.unwrap("an organization"))
}

fn invited_by_label(invitation: OrgInvitation) -> String {
  case invitation.invited_by_username {
    option.Some(username) -> "@" <> username
    option.None -> invitation.invited_by_display_name
  }
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    OrgsLoaded(Ok(orgs)) -> #(
      Model(..model, orgs:, error: option.None),
      effect.none(),
    )
    OrgsLoaded(Error(lustre_http.Unauthorized)) -> #(
      Model(
        ..model,
        error: option.Some(
          "Unauthorized - ensure server CLERK_JWKS_URL matches this Clerk app (see server/.env)",
        ),
      ),
      effect.none(),
    )
    OrgsLoaded(Error(lustre_http.BadUrl(url))) -> #(
      Model(..model, error: option.Some("Invalid API URL: " <> url)),
      effect.none(),
    )
    OrgsLoaded(Error(lustre_http.NetworkError)) -> #(
      Model(
        ..model,
        error: option.Some("Network error - is the API server running?"),
      ),
      effect.none(),
    )
    OrgsLoaded(Error(_)) -> #(
      Model(..model, error: option.Some("Failed to load orgs")),
      effect.none(),
    )
    InvitationsLoaded(Ok(invitations)) -> #(
      Model(..model, invitations:, error: option.None),
      effect.none(),
    )
    InvitationsLoaded(Error(_)) -> #(
      Model(..model, error: option.Some("Failed to load invitations")),
      effect.none(),
    )
    SlugChanged(s) -> #(
      Model(..model, slug: org_slug.sanitize_slug_input(s), slug_manual: True),
      effect.none(),
    )
    NameChanged(n) -> {
      let slug = case model.slug_manual {
        True -> model.slug
        False -> org_slug.slugify_display_name(n)
      }
      #(Model(..model, name: n, slug:), effect.none())
    }
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
      Model(
        ..model,
        orgs: [org, ..model.orgs],
        slug: "",
        name: "",
        slug_manual: False,
      ),
      effect.none(),
    )
    Created(Error(_)) -> #(
      Model(..model, error: option.Some("Could not create org")),
      effect.none(),
    )
    AcceptInvitation(id) -> #(
      model,
      lustre_http.post(
        config,
        config.api_url <> "/api/invitations/" <> id <> "/accept",
        json.object([]),
        lustre_http.expect_json(api.accept_invitation_decoder(), Accepted),
      ),
    )
    Accepted(Ok(_)) -> #(model, reload_all(config))
    Accepted(Error(_)) -> #(
      Model(..model, error: option.Some("Could not accept invitation")),
      effect.none(),
    )
    DeclineInvitation(id) -> #(
      model,
      lustre_http.post(
        config,
        config.api_url <> "/api/invitations/" <> id <> "/decline",
        json.object([]),
        lustre_http.expect_anything(Declined),
      ),
    )
    Declined(Ok(_)) -> #(model, reload_all(config))
    Declined(Error(_)) -> #(
      Model(..model, error: option.Some("Could not decline invitation")),
      effect.none(),
    )
  }
}

pub fn view(model: Model) -> Element(Msg) {
  let org_list = case model.orgs {
    [] -> [components.empty_state("No organizations yet - create one below.")]
    orgs ->
      list.map(orgs, fn(org: Org) {
        components.list_link_card(
          routes.org_repos_path(org.slug),
          org.name,
          option.Some(org.slug),
        )
      })
  }

  let invitation_cards = case model.invitations {
    [] -> []
    invitations -> [
      div([attr.class(components.card <> " mb-6")], [
        p([attr.class(components.section_title)], [text("Pending invitations")]),
        div(
          [attr.class("space-y-3")],
          list.map(invitations, fn(invitation) {
            div([attr.class(components.list_item)], [
              div([], [
                p([attr.class("font-semibold text-gh-ink")], [
                  text(org_name(invitation)),
                ]),
                p([attr.class("mt-1 text-sm text-gh-muted")], [
                  text("Invited by " <> invited_by_label(invitation)),
                ]),
              ]),
              div([attr.class("flex flex-wrap gap-2")], [
                button(
                  [
                    attr.class(components.btn_primary),
                    attr.type_("button"),
                    event.on_click(AcceptInvitation(invitation.id)),
                  ],
                  [text("Accept")],
                ),
                button(
                  [
                    attr.class(components.btn_secondary),
                    attr.type_("button"),
                    event.on_click(DeclineInvitation(invitation.id)),
                  ],
                  [text("Decline")],
                ),
              ]),
            ])
          }),
        ),
      ]),
    ]
  }

  let page_body =
    [
      components.page_header(
        "Organizations",
        "Create a team namespace and manage repositories under it.",
      ),
      case model.error {
        option.Some(e) -> components.error_alert(e)
        option.None -> text("")
      },
    ]
    |> list.append(invitation_cards)
    |> list.append([
      div([attr.class(components.card <> " mb-6")], org_list),
      components.card_section("New organization", [
        form([attr.class("space-y-4"), event.on_submit(fn(_) { Create })], [
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
          div([], [
            components.field_label("org-slug", "Slug"),
            input([
              attr.id("org-slug"),
              attr.class(components.input),
              attr.value(model.slug),
              attr.placeholder("my-team"),
              event.on_input(SlugChanged),
            ]),
            components.field_hint(
              "Lowercase letters, numbers, hyphens, and underscores only.",
            ),
          ]),
          components.form_actions([
            button([attr.class(components.btn_primary), attr.type_("submit")], [
              text("Create organization"),
            ]),
          ]),
        ]),
      ]),
    ])

  div([attr.class(components.page)], page_body)
}
