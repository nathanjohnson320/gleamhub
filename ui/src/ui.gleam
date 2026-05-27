import auth
import clerk_auth
import components
import config
import gleam/list
import gleam/option
import gleam/string
import gleam/uri.{type Uri}
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element, map, text}
import lustre/element/html.{a, button, div, header, nav, span}
import lustre/event
import modem
import pages/keys
import pages/org_repos
import pages/orgs

pub fn main(
  pathname: String,
  _selector: String,
  user_json: String,
  api_url: String,
) {
  let assert Ok(uri) = uri.parse(pathname)
  let auth_user = auth.user_from_json(user_json)
  let app = lustre.application(init, update, view)
  let assert Ok(_) =
    lustre.start(app, "#gleam-root", Flags(api_url, uri, auth_user))
}

type Model {
  Model(
    config: config.Config,
    auth_user: option.Option(auth.User),
    route: Route,
    orgs: orgs.Model,
    repos: option.Option(org_repos.Model),
    keys: keys.Model,
  )
}

pub type Route {
  Orgs
  OrgRepos(String)
  Keys
  NotFound
}

type Flags {
  Flags(api_url: String, path: Uri, auth_user: option.Option(auth.User))
}

pub type Msg {
  OnRouteChange(Route)
  OrgsMsg(orgs.Msg)
  ReposMsg(org_repos.Msg)
  KeysMsg(keys.Msg)
  ClerkSessionUpdated(String)
  OpenAccount
  SignOut
}

fn init(flags: Flags) -> #(Model, Effect(Msg)) {
  let config = config_from_auth(flags.api_url, flags.auth_user)
  let route = parse_route(flags.path)

  #(
    Model(
      config: config,
      auth_user: flags.auth_user,
      route: route,
      orgs: {
        let #(m, _) = orgs.init()
        m
      },
      repos: repos_model(route),
      keys: keys.init(),
    ),
    effect.batch([
      modem.init(fn(u) { OnRouteChange(parse_route(u)) }),
      listen_clerk_session_change(),
      route_effect(config, route),
    ]),
  )
}

fn config_from_auth(
  api_url: String,
  auth_user: option.Option(auth.User),
) -> config.Config {
  let token = case auth_user {
    option.Some(user) -> option.Some(user.token)
    option.None -> option.None
  }
  config.Config(api_url: api_url, token:)
}

fn listen_clerk_session_change() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    clerk_auth.set_clerk_auth_update_handler(fn(user_json) {
      dispatch(ClerkSessionUpdated(user_json))
    })
    Nil
  })
}

fn with_refreshed_session(
  model: Model,
  auth_user: option.Option(auth.User),
) -> Model {
  let config = config_from_auth(model.config.api_url, auth_user)
  Model(..model, config:, auth_user:)
}

fn repos_model(route: Route) -> option.Option(org_repos.Model) {
  case route {
    OrgRepos(slug) -> option.Some(org_repos.init(slug))
    _ -> option.None
  }
}

fn parse_route(uri: Uri) -> Route {
  case uri.path |> string.split(on: "/") |> list_filter_empty() {
    [] -> Orgs
    ["orgs"] -> Orgs
    ["orgs", slug] -> OrgRepos(slug)
    ["keys"] -> Keys
    _ -> NotFound
  }
}

fn list_filter_empty(items: List(String)) -> List(String) {
  list.filter(items, fn(s) { s != "" })
}

fn route_effect(config: config.Config, route: Route) -> Effect(Msg) {
  case route {
    Orgs -> effect.map(orgs.on_load(config), OrgsMsg)
    OrgRepos(slug) -> effect.map(org_repos.on_load(config, slug), ReposMsg)
    Keys -> effect.map(keys.on_load(config), KeysMsg)
    NotFound -> effect.none()
  }
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    OnRouteChange(route) -> #(
      Model(..model, route:, repos: repos_model(route)),
      route_effect(model.config, route),
    )
    OrgsMsg(m) -> {
      let #(orgs, eff) = orgs.update(m, model.orgs, model.config)
      #(Model(..model, orgs:), effect.map(eff, OrgsMsg))
    }
    ReposMsg(m) -> {
      case model.repos {
        option.Some(repos) -> {
          let #(repos, eff) = org_repos.update(m, repos, model.config)
          #(Model(..model, repos: option.Some(repos)), effect.map(eff, ReposMsg))
        }
        option.None -> #(model, effect.none())
      }
    }
    KeysMsg(m) -> {
      let #(keys, eff) = keys.update(m, model.keys, model.config)
      #(Model(..model, keys:), effect.map(eff, KeysMsg))
    }
    ClerkSessionUpdated(user_json) -> {
      let model = with_refreshed_session(model, auth.user_from_json(user_json))
      #(model, route_effect(model.config, model.route))
    }
    OpenAccount -> #(model, clerk_auth.open_account_effect())
    SignOut -> #(model, clerk_auth.sign_out_effect())
  }
}

fn nav_link(route: Route, current: Route, path: String, label: String) -> Element(Msg) {
  let active = nav_active(current, route)
  let classes = case active {
    True -> "rounded-lg bg-white/15 px-3 py-2 text-sm font-semibold text-white"
    False ->
      "rounded-lg px-3 py-2 text-sm font-medium text-white/75 transition hover:bg-white/10 hover:text-white"
  }
  a([attr.class(classes), attr.href(path)], [text(label)])
}

fn nav_active(current: Route, link: Route) -> Bool {
  case current, link {
    Orgs, Orgs -> True
    Keys, Keys -> True
    OrgRepos(_), Orgs -> False
    OrgRepos(_), Keys -> False
    _, _ -> current == link
  }
}

fn user_chip(user: auth.User) -> Element(Msg) {
  div([attr.class("flex items-center gap-2")], [
    span(
      [
        attr.class(
          "flex h-9 w-9 items-center justify-center rounded-full border border-white/20 bg-white/10 text-xs font-semibold text-white",
        ),
      ],
      [text(user.initials)],
    ),
    span(
      [attr.class("hidden max-w-[10rem] truncate text-sm text-white/90 sm:inline")],
      [text(auth.display_name(user))],
    ),
  ])
}

fn view(model: Model) -> Element(Msg) {
  let body = case model.route {
    Orgs -> orgs.view(model.orgs) |> map(OrgsMsg)
    OrgRepos(_) -> {
      case model.repos {
        option.Some(r) -> org_repos.view(r) |> map(ReposMsg)
        option.None ->
          div([attr.class(components.page)], [
            components.empty_state("Loading repositories…"),
          ])
      }
    }
    Keys -> keys.view(model.keys) |> map(KeysMsg)
    NotFound ->
      div([attr.class(components.page)], [
        components.page_header("Not found", "That page does not exist."),
        a([attr.class(components.btn_primary), attr.href("/orgs")], [
          text("Back to organizations"),
        ]),
      ])
  }

  div([attr.class("min-h-screen bg-gh-surface")], [
    header(
      [attr.class("border-b border-slate-800 bg-slate-900 text-white shadow-md")],
      [
        div(
          [
            attr.class(
              "mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-4 px-4 py-4 sm:px-6",
            ),
          ],
          [
            a([attr.href("/orgs"), attr.class("flex items-center gap-2 no-underline")], [
              span(
                [
                  attr.class(
                    "flex h-9 w-9 items-center justify-center rounded-lg bg-gh-accent text-sm font-bold text-white",
                  ),
                ],
                [text("G")],
              ),
              span([attr.class("text-lg font-semibold tracking-tight text-white")], [
                text("Gleamhub"),
              ]),
            ]),
            nav([attr.class("flex flex-wrap items-center gap-1")], [
              nav_link(Orgs, model.route, "/orgs", "Organizations"),
              nav_link(Keys, model.route, "/keys", "SSH keys"),
            ]),
            case model.auth_user {
              option.Some(user) ->
                div([attr.class("flex items-center gap-2")], [
                  user_chip(user),
                  button(
                    [
                      attr.class(components.btn_secondary <> " !text-xs"),
                      attr.type_("button"),
                      event.on_click(OpenAccount),
                    ],
                    [text("Account")],
                  ),
                  button(
                    [
                      attr.class(
                        "rounded-lg px-3 py-2 text-sm font-medium text-white/80 transition hover:bg-white/10 hover:text-white",
                      ),
                      attr.type_("button"),
                      event.on_click(SignOut),
                    ],
                    [text("Sign out")],
                  ),
                ])
              option.None -> text("")
            },
          ],
        ),
      ],
    ),
    div([attr.class("flex-1")], [body]),
  ])
}
