import auth
import clerk_auth
import components
import config
import gleam/option
import gleam/uri.{type Uri}
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element, map, text}
import lustre/element/html.{a, button, div, header, nav, span}
import lustre/event
import blob_lines
import modem
import pages/keys
import pages/merge_request_detail
import pages/merge_requests
import pages/org_repos
import pages/orgs
import pages/repo_view
import routes.{
  type Route, Blob, Keys, MrDetail, MrList, MrNew, NotFound, OrgRepos, Orgs,
  RepoMissingOrg, RepoView, from_uri, keys_path,
}

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
    repo_view: option.Option(repo_view.Model),
    mr: option.Option(merge_requests.Model),
    mr_detail: option.Option(merge_request_detail.Model),
    keys: keys.Model,
    user_menu_open: Bool,
  )
}

type Flags {
  Flags(api_url: String, path: Uri, auth_user: option.Option(auth.User))
}

pub type Msg {
  OnRouteChange(Route)
  OrgsMsg(orgs.Msg)
  ReposMsg(org_repos.Msg)
  RepoViewMsg(repo_view.Msg)
  MrMsg(merge_requests.Msg)
  MrDetailMsg(merge_request_detail.Msg)
  KeysMsg(keys.Msg)
  ClerkSessionUpdated(String)
  OpenAccount
  SignOut
  ToggleUserMenu
}

fn init(flags: Flags) -> #(Model, Effect(Msg)) {
  let config = config_from_auth(flags.api_url, flags.auth_user)
  let route = case modem.initial_uri() {
    Ok(uri) -> from_uri(uri)
    Error(_) -> from_uri(flags.path)
  }

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
      repo_view: repo_view_model(route),
      mr: mr_model(route),
      mr_detail: mr_detail_model(route),
      keys: keys.init(),
      user_menu_open: False,
    ),
    effect.batch([
      modem.init(fn(u) { OnRouteChange(from_uri(u)) }),
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

fn repo_view_model(route: Route) -> option.Option(repo_view.Model) {
  case route {
    RepoView(mode, org, repo, ref, path) ->
      option.Some(repo_view.init(org, repo, mode, ref, path))
    _ -> option.None
  }
}

fn mr_model(route: Route) -> option.Option(merge_requests.Model) {
  case route {
    MrList(org, repo) ->
      option.Some(merge_requests.init(org, repo, merge_requests.List))
    MrNew(org, repo) ->
      option.Some(merge_requests.init(org, repo, merge_requests.New))
    _ -> option.None
  }
}

fn mr_detail_model(route: Route) -> option.Option(merge_request_detail.Model) {
  case route {
    MrDetail(org, repo, number) ->
      option.Some(merge_request_detail.init(org, repo, number))
    _ -> option.None
  }
}

fn route_effect(config: config.Config, route: Route) -> Effect(Msg) {
  case route {
    Orgs -> effect.map(orgs.on_load(config), OrgsMsg)
    OrgRepos(slug) -> effect.map(org_repos.on_load(config, slug), ReposMsg)
    RepoView(_, _, _, _, _) ->
      case repo_view_model(route) {
        option.Some(m) -> effect.map(repo_view.on_load(config, m), RepoViewMsg)
        option.None -> effect.none()
      }
    MrList(_, _) | MrNew(_, _) ->
      case mr_model(route) {
        option.Some(m) -> effect.map(merge_requests.on_load(config, m), MrMsg)
        option.None -> effect.none()
      }
    MrDetail(_, _, _) ->
      case mr_detail_model(route) {
        option.Some(m) ->
          effect.map(merge_request_detail.on_load(config, m), MrDetailMsg)
        option.None -> effect.none()
      }
    Keys -> effect.map(keys.on_load(config), KeysMsg)
    RepoMissingOrg(_) -> effect.none()
    NotFound -> effect.none()
  }
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    OnRouteChange(route) -> {
      // Hash-only line links (#L10) keep the same Route; don't re-init the view.
      case model.route == route {
        True -> #(
          model,
          case route {
            RepoView(Blob, _, _, _, _) -> blob_lines.init_effect()
            MrDetail(_, _, _) -> effect.none()
            _ -> effect.none()
          },
        )
        False -> #(
          Model(
            ..model,
            route:,
            repos: repos_model(route),
            repo_view: repo_view_model(route),
            mr: mr_model(route),
            mr_detail: mr_detail_model(route),
            user_menu_open: False,
          ),
          route_effect(model.config, route),
        )
      }
    }
    OrgsMsg(m) -> {
      let #(orgs, eff) = orgs.update(m, model.orgs, model.config)
      #(Model(..model, orgs:), effect.map(eff, OrgsMsg))
    }
    ReposMsg(m) -> {
      case model.repos {
        option.Some(repos) -> {
          let #(repos, eff) = org_repos.update(m, repos, model.config)
          #(
            Model(..model, repos: option.Some(repos)),
            effect.map(eff, ReposMsg),
          )
        }
        option.None -> #(model, effect.none())
      }
    }
    RepoViewMsg(m) -> {
      case model.repo_view {
        option.Some(rv) -> {
          let #(rv, eff) = repo_view.update(m, rv, model.config)
          #(
            Model(..model, repo_view: option.Some(rv)),
            effect.map(eff, RepoViewMsg),
          )
        }
        option.None -> #(model, effect.none())
      }
    }
    MrMsg(m) -> {
      case model.mr {
        option.Some(mr) -> {
          let #(mr, eff) = merge_requests.update(m, mr, model.config)
          #(Model(..model, mr: option.Some(mr)), effect.map(eff, MrMsg))
        }
        option.None -> #(model, effect.none())
      }
    }
    MrDetailMsg(m) -> {
      case model.mr_detail {
        option.Some(mrd) -> {
          let #(mrd, eff) = merge_request_detail.update(m, mrd, model.config)
          #(
            Model(..model, mr_detail: option.Some(mrd)),
            effect.map(eff, MrDetailMsg),
          )
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
    OpenAccount -> #(
      Model(..model, user_menu_open: False),
      clerk_auth.open_account_effect(),
    )
    SignOut -> #(
      Model(..model, user_menu_open: False),
      clerk_auth.sign_out_effect(),
    )
    ToggleUserMenu -> #(
      Model(..model, user_menu_open: !model.user_menu_open),
      effect.none(),
    )
  }
}

fn nav_link(
  route: Route,
  current: Route,
  path: String,
  label: String,
) -> Element(Msg) {
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
    OrgRepos(_), Orgs -> False
    RepoView(_, _, _, _, _), Orgs -> False
    _, _ -> current == link
  }
}

fn user_menu_item_class(active: Bool) -> String {
  case active {
    True ->
      "block w-full rounded-md px-3 py-2 text-left text-sm font-medium text-white bg-white/10"
    False ->
      "block w-full rounded-md px-3 py-2 text-left text-sm text-white/90 transition hover:bg-white/10 hover:text-white"
  }
}

fn user_menu(user: auth.User, route: Route, open: Bool) -> Element(Msg) {
  let keys_active = route == Keys
  div([attr.class("relative")], [
    button(
      [
        attr.type_("button"),
        attr.class(
          "flex items-center gap-2 rounded-lg border border-white/10 bg-white/5 px-2 py-1.5 transition hover:bg-white/10",
        ),
        event.on_click(ToggleUserMenu),
        attr.attribute("aria-expanded", case open {
          True -> "true"
          False -> "false"
        }),
        attr.attribute("aria-haspopup", "true"),
      ],
      [
        span(
          [
            attr.class(
              "flex h-8 w-8 items-center justify-center rounded-full border border-white/20 bg-white/10 text-xs font-semibold text-white",
            ),
          ],
          [text(user.initials)],
        ),
        span(
          [
            attr.class(
              "hidden max-w-[10rem] truncate text-sm text-white/90 sm:inline",
            ),
          ],
          [text(auth.display_name(user))],
        ),
        span([attr.class("text-xs text-white/60")], [text("▾")]),
      ],
    ),
    case open {
      True ->
        div(
          [
            attr.class(
              "absolute right-0 z-50 mt-2 min-w-[12rem] rounded-lg border border-white/10 bg-slate-800 p-1 shadow-lg",
            ),
          ],
          [
            a(
              [
                attr.class(user_menu_item_class(keys_active)),
                attr.href(keys_path()),
              ],
              [text("SSH keys")],
            ),
            button(
              [
                attr.class(user_menu_item_class(False)),
                attr.type_("button"),
                event.on_click(OpenAccount),
              ],
              [text("Account")],
            ),
            div([attr.class("my-1 border-t border-white/10")], []),
            button(
              [
                attr.class(user_menu_item_class(False)),
                attr.type_("button"),
                event.on_click(SignOut),
              ],
              [text("Sign out")],
            ),
          ],
        )
      False -> text("")
    },
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
    RepoView(_, _, _, _, _) -> {
      case model.repo_view {
        option.Some(rv) -> repo_view.view(rv) |> map(RepoViewMsg)
        option.None ->
          div([attr.class(components.page)], [
            components.empty_state("Loading repository…"),
          ])
      }
    }
    MrList(_, _) | MrNew(_, _) -> {
      case model.mr {
        option.Some(mr) -> merge_requests.view(mr) |> map(MrMsg)
        option.None ->
          div([attr.class(components.page)], [
            components.empty_state("Loading merge requests…"),
          ])
      }
    }
    MrDetail(_, _, _) -> {
      case model.mr_detail {
        option.Some(mrd) -> merge_request_detail.view(mrd) |> map(MrDetailMsg)
        option.None ->
          div([attr.class(components.page)], [
            components.empty_state("Loading merge request…"),
          ])
      }
    }
    Keys -> keys.view(model.keys) |> map(KeysMsg)
    RepoMissingOrg(repo) ->
      div([attr.class(components.page)], [
        components.page_header(
          "Repository link incomplete",
          "The URL is missing the organization. Open "
            <> repo
            <> " from your organization's repository list.",
        ),
        a([attr.class(components.btn_primary), attr.href("/orgs")], [
          text("Back to organizations"),
        ]),
      ])
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
      [
        attr.class(
          "border-b border-slate-800 bg-slate-900 text-white shadow-md",
        ),
      ],
      [
        div(
          [
            attr.class(
              "mx-auto flex max-w-5xl items-center justify-between gap-4 px-4 py-4 sm:px-6",
            ),
          ],
          [
            div([attr.class("flex min-w-0 items-center gap-6")], [
              a(
                [
                  attr.href("/orgs"),
                  attr.class("flex shrink-0 items-center gap-2 no-underline"),
                ],
                [
                  span(
                    [
                      attr.class(
                        "flex h-9 w-9 items-center justify-center rounded-lg bg-gh-accent text-sm font-bold text-white",
                      ),
                    ],
                    [text("G")],
                  ),
                  span(
                    [
                      attr.class(
                        "text-lg font-semibold tracking-tight text-white",
                      ),
                    ],
                    [text("Gleamhub")],
                  ),
                ],
              ),
              case model.auth_user {
                option.Some(_) ->
                  nav([attr.class("flex items-center gap-1")], [
                    nav_link(Orgs, model.route, "/orgs", "Organizations"),
                  ])
                option.None -> text("")
              },
            ]),
            case model.auth_user {
              option.Some(user) ->
                user_menu(user, model.route, model.user_menu_open)
              option.None -> text("")
            },
          ],
        ),
      ],
    ),
    div([attr.class("flex-1")], [body]),
  ])
}
