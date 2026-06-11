import auth/auth
import auth/clerk_auth
import components
import config
import gleam/int
import gleam/option
import gleam/uri.{type Uri}
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element, map, text}
import lustre/element/html.{a, button, div, header, nav, span}
import lustre/event
import modem
import pages/account
import pages/commits
import pages/issue_detail
import pages/issues
import pages/keys
import pages/merge_request_detail
import pages/merge_requests
import pages/milestones
import pages/my_space
import pages/org_members
import pages/org_repos
import pages/orgs
import pages/releases
import pages/repo_settings
import pages/repo_view
import routes.{
  type Route, Account, CommitsList, IssueDetail, IssueList, IssueNew, Keys,
  MilestoneDetail, MilestoneList, MilestoneNew, MrDetail, MrList, MrNew,
  MySpace, NotFound, OrgMembers, OrgRepos, Orgs, ReleaseDetail, ReleaseList,
  ReleaseNew, RepoMissingOrg, RepoSettings,
  RepoView, account_path, from_uri, keys_path, my_tab_path,
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
    members: option.Option(org_members.Model),
    repo_view: option.Option(repo_view.Model),
    repo_settings: option.Option(repo_settings.Model),
    mr: option.Option(merge_requests.Model),
    mr_detail: option.Option(merge_request_detail.Model),
    issues: option.Option(issues.Model),
    issue_detail: option.Option(issue_detail.Model),
    commits: option.Option(commits.Model),
    releases: option.Option(releases.Model),
    milestones: option.Option(milestones.Model),
    keys: keys.Model,
    my_space: my_space.Model,
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
  MembersMsg(org_members.Msg)
  RepoViewMsg(repo_view.Msg)
  RepoSettingsMsg(repo_settings.Msg)
  MrMsg(merge_requests.Msg)
  MrDetailMsg(merge_request_detail.Msg)
  IssueMsg(issues.Msg)
  IssueDetailMsg(issue_detail.Msg)
  CommitsMsg(commits.Msg)
  ReleasesMsg(releases.Msg)
  MilestonesMsg(milestones.Msg)
  KeysMsg(keys.Msg)
  MySpaceMsg(my_space.Msg)
  ClerkSessionUpdated(String)
  SignOut
  ToggleUserMenu
}

fn init(flags: Flags) -> #(Model, Effect(Msg)) {
  let config = config_from_auth(flags.api_url, flags.auth_user)
  let route = case modem.initial_uri() {
    Ok(uri) -> from_uri(uri)
    Error(_) -> from_uri(flags.path)
  }

  let #(mr_detail, mr_synced) =
    mr_detail_for_route(route, option.None, flags.auth_user)
  let #(repo_view, repo_synced) = repo_view_for_route(route, option.None)
  let issue_detail = issue_detail_model(route, flags.auth_user)
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
      members: members_model(route),
      repo_view:,
      repo_settings: repo_settings_model(route),
      mr: mr_model(route),
      mr_detail:,
      issues: issue_model(route),
      issue_detail:,
      commits: commits_model(route),
      releases: releases_model(route),
      milestones: milestones_model(route),
      keys: keys.init(),
      my_space: my_space.init(routes.MyOverview),
      user_menu_open: False,
    ),
    effect.batch([
      modem.init(fn(u) { OnRouteChange(from_uri(u)) }),
      listen_clerk_session_change(),
      route_effect(
        config,
        route,
        mr_synced,
        option.None,
        mr_detail,
        repo_synced,
        option.None,
        repo_view,
        issue_detail,
        my_space.init(routes.MyOverview),
      ),
      case route {
        MySpace(_) -> effect.none()
        _ -> me_refresh_effect(config, flags.auth_user, my_space.init(routes.MyOverview))
      },
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

fn session_token_changed(
  before: option.Option(auth.User),
  after: option.Option(auth.User),
) -> Bool {
  case before, after {
    option.None, option.Some(_) -> True
    option.Some(_), option.None -> True
    option.Some(b), option.Some(a) -> b.token != a.token
    option.None, option.None -> False
  }
}

fn repos_model(route: Route) -> option.Option(org_repos.Model) {
  case route {
    OrgRepos(slug) -> option.Some(org_repos.init(slug))
    _ -> option.None
  }
}

fn members_model(route: Route) -> option.Option(org_members.Model) {
  case route {
    OrgMembers(slug) -> option.Some(org_members.init(slug))
    _ -> option.None
  }
}

fn repo_view_for_route(
  route: Route,
  existing: option.Option(repo_view.Model),
) -> #(option.Option(repo_view.Model), Bool) {
  case route {
    RepoView(mode, org, repo, ref, path, line_range:) -> {
      case existing {
        option.Some(rv) -> {
          case repo_view.same_view(rv, org, repo, mode, ref, path) {
            True -> #(
              option.Some(repo_view.sync_line_range(rv, line_range)),
              True,
            )
            False -> #(
              option.Some(repo_view.init(org, repo, mode, ref, path, line_range)),
              False,
            )
          }
        }
        option.None -> #(
          option.Some(repo_view.init(org, repo, mode, ref, path, line_range)),
          False,
        )
      }
    }
    _ -> #(option.None, False)
  }
}

fn repo_settings_model(route: Route) -> option.Option(repo_settings.Model) {
  case route {
    RepoSettings(org, repo) -> option.Some(repo_settings.init(org, repo))
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

fn mr_detail_for_route(
  route: Route,
  existing: option.Option(merge_request_detail.Model),
  auth_user: option.Option(auth.User),
) -> #(option.Option(merge_request_detail.Model), Bool) {
  case route {
    MrDetail(org, repo, number, view) -> {
      case existing {
        option.Some(mrd) -> {
          case merge_request_detail.same_mr(mrd, org, repo, number) {
            True -> {
              let synced = merge_request_detail.sync_view(mrd, view)
              #(option.Some(synced), True)
            }
            False -> #(
              option.Some(merge_request_detail.init(
                org,
                repo,
                number,
                view,
                viewer_user_id(auth_user),
              )),
              False,
            )
          }
        }
        option.None -> #(
          option.Some(merge_request_detail.init(
            org,
            repo,
            number,
            view,
            viewer_user_id(auth_user),
          )),
          False,
        )
      }
    }
    _ -> #(option.None, False)
  }
}

fn issue_model(route: Route) -> option.Option(issues.Model) {
  case route {
    IssueList(org, repo) -> option.Some(issues.init(org, repo, issues.List))
    IssueNew(org, repo) -> option.Some(issues.init(org, repo, issues.New))
    _ -> option.None
  }
}

fn viewer_user_id(
  auth_user: option.Option(auth.User),
) -> option.Option(String) {
  case auth_user {
    option.Some(user) -> option.Some(user.id)
    option.None -> option.None
  }
}

fn issue_detail_model(
  route: Route,
  auth_user: option.Option(auth.User),
) -> option.Option(issue_detail.Model) {
  case route {
    IssueDetail(org, repo, number) ->
      option.Some(issue_detail.init(
        org,
        repo,
        number,
        viewer_user_id(auth_user),
      ))
    _ -> option.None
  }
}

fn commits_model(route: Route) -> option.Option(commits.Model) {
  case route {
    CommitsList(org, repo, ref) -> option.Some(commits.init(org, repo, ref))
    _ -> option.None
  }
}

fn releases_model(route: Route) -> option.Option(releases.Model) {
  case route {
    ReleaseList(org, repo) ->
      option.Some(releases.init(org, repo, releases.List))
    ReleaseNew(org, repo) ->
      option.Some(releases.init(org, repo, releases.New))
    ReleaseDetail(org, repo, tag) ->
      option.Some(releases.init(org, repo, releases.Detail(tag)))
    _ -> option.None
  }
}

fn milestones_model(route: Route) -> option.Option(milestones.Model) {
  case route {
    MilestoneList(org, repo) ->
      option.Some(milestones.init(org, repo, milestones.List))
    MilestoneNew(org, repo) ->
      option.Some(milestones.init(org, repo, milestones.New))
    MilestoneDetail(org, repo, number) ->
      option.Some(milestones.init(org, repo, milestones.Detail(number)))
    _ -> option.None
  }
}

fn me_refresh_effect(
  config: config.Config,
  auth_user: option.Option(auth.User),
  my_space_model: my_space.Model,
) -> Effect(Msg) {
  case auth_user {
    option.Some(_) ->
      effect.map(
        my_space.on_load(config, my_space_model),
        MySpaceMsg,
      )
    option.None -> effect.none()
  }
}

fn route_effect(
  config: config.Config,
  route: Route,
  mr_synced: Bool,
  mr_before: option.Option(merge_request_detail.Model),
  mr_after: option.Option(merge_request_detail.Model),
  repo_synced: Bool,
  repo_before: option.Option(repo_view.Model),
  repo_after: option.Option(repo_view.Model),
  issue_detail: option.Option(issue_detail.Model),
  my_space_model: my_space.Model,
) -> Effect(Msg) {
  case route {
    Orgs -> effect.map(orgs.on_load(config), OrgsMsg)
    OrgRepos(slug) -> effect.map(org_repos.on_load(config, slug), ReposMsg)
    OrgMembers(slug) ->
      effect.map(org_members.on_load(config, slug), MembersMsg)
    RepoView(_, _, _, _, _, _) ->
      case repo_after, repo_synced, repo_before {
        option.Some(after), True, option.Some(before) ->
          effect.map(
            repo_view.sync_line_range_effect(
              before.line_range,
              after.line_range,
            ),
            RepoViewMsg,
          )
        option.Some(m), False, _ ->
          effect.map(repo_view.on_load(config, m), RepoViewMsg)
        _, _, _ -> effect.none()
      }
    RepoSettings(_, _) ->
      case repo_settings_model(route) {
        option.Some(m) ->
          effect.map(repo_settings.on_load(config, m), RepoSettingsMsg)
        option.None -> effect.none()
      }
    MrList(_, _) | MrNew(_, _) ->
      case mr_model(route) {
        option.Some(m) -> effect.map(merge_requests.on_load(config, m), MrMsg)
        option.None -> effect.none()
      }
    MrDetail(_, _, _, _) ->
      case mr_after, mr_synced, mr_before {
        option.Some(after), True, option.Some(before) ->
          effect.map(
            merge_request_detail.sync_view_effect(before, after, config),
            MrDetailMsg,
          )
        option.Some(m), False, _ ->
          effect.map(merge_request_detail.on_load(config, m), MrDetailMsg)
        _, _, _ -> effect.none()
      }
    IssueList(_, _) | IssueNew(_, _) ->
      case issue_model(route) {
        option.Some(m) -> effect.map(issues.on_load(config, m), IssueMsg)
        option.None -> effect.none()
      }
    IssueDetail(_, _, _) ->
      case issue_detail {
        option.Some(m) ->
          effect.map(issue_detail.on_load(config, m), IssueDetailMsg)
        option.None -> effect.none()
      }
    CommitsList(_, _, _) ->
      case commits_model(route) {
        option.Some(m) -> effect.map(commits.on_load(config, m), CommitsMsg)
        option.None -> effect.none()
      }
    ReleaseList(_, _) | ReleaseNew(_, _) | ReleaseDetail(_, _, _) ->
      case releases_model(route) {
        option.Some(m) -> effect.map(releases.on_load(config, m), ReleasesMsg)
        option.None -> effect.none()
      }
    MilestoneList(_, _) | MilestoneNew(_, _) | MilestoneDetail(_, _, _) ->
      case milestones_model(route) {
        option.Some(m) -> effect.map(milestones.on_load(config, m), MilestonesMsg)
        option.None -> effect.none()
      }
    Keys -> effect.map(keys.on_load(config), KeysMsg)
    Account -> clerk_auth.mount_user_profile_effect(account.profile_element_id)
    MySpace(_) -> effect.map(my_space.on_load(config, my_space_model), MySpaceMsg)
    RepoMissingOrg(_) -> effect.none()
    NotFound -> effect.none()
  }
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    OnRouteChange(route) -> {
      let mr_before = model.mr_detail
      let repo_before = model.repo_view
      let #(mr_detail, mr_synced) =
        mr_detail_for_route(route, mr_before, model.auth_user)
      let #(repo_view, repo_synced) = repo_view_for_route(route, repo_before)
      let issue_detail = issue_detail_model(route, model.auth_user)
      let my_space_model = case route, model.route {
        MySpace(tab), MySpace(_) -> my_space.switch_tab(model.my_space, tab)
        MySpace(tab), _ -> my_space.init(tab)
        _, _ -> model.my_space
      }
      let leave_account = case model.route, route {
        Account, r if r != Account ->
          clerk_auth.unmount_user_profile_effect(account.profile_element_id)
        _, _ -> effect.none()
      }
      #(
        Model(
          ..model,
          route:,
          repos: repos_model(route),
          members: members_model(route),
          repo_view:,
          repo_settings: repo_settings_model(route),
          mr: mr_model(route),
          mr_detail:,
          issues: issue_model(route),
          issue_detail:,
          commits: commits_model(route),
          releases: releases_model(route),
          milestones: milestones_model(route),
          my_space: my_space_model,
          user_menu_open: False,
        ),
        effect.batch([
          leave_account,
          route_effect(
            model.config,
            route,
            mr_synced,
            mr_before,
            mr_detail,
            repo_synced,
            repo_before,
            repo_view,
            issue_detail,
            my_space_model,
          ),
          case route {
            MySpace(_) -> effect.none()
            _ -> me_refresh_effect(model.config, model.auth_user, my_space_model)
          },
        ]),
      )
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
    MembersMsg(m) -> {
      case model.members {
        option.Some(members) -> {
          let #(members, eff) = org_members.update(m, members, model.config)
          #(
            Model(..model, members: option.Some(members)),
            effect.map(eff, MembersMsg),
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
    RepoSettingsMsg(m) -> {
      case model.repo_settings {
        option.Some(rs) -> {
          let #(rs, eff) = repo_settings.update(m, rs, model.config)
          #(
            Model(..model, repo_settings: option.Some(rs)),
            effect.map(eff, RepoSettingsMsg),
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
    IssueMsg(m) -> {
      case model.issues {
        option.Some(issues_model) -> {
          let #(issues_model, eff) =
            issues.update(m, issues_model, model.config)
          #(
            Model(..model, issues: option.Some(issues_model)),
            effect.map(eff, IssueMsg),
          )
        }
        option.None -> #(model, effect.none())
      }
    }
    IssueDetailMsg(m) -> {
      case model.issue_detail {
        option.Some(issue) -> {
          let #(issue, eff) = issue_detail.update(m, issue, model.config)
          #(
            Model(..model, issue_detail: option.Some(issue)),
            effect.map(eff, IssueDetailMsg),
          )
        }
        option.None -> #(model, effect.none())
      }
    }
    CommitsMsg(m) -> {
      case model.commits {
        option.Some(c) -> {
          let #(c, eff) = commits.update(m, c, model.config)
          #(
            Model(..model, commits: option.Some(c)),
            effect.map(eff, CommitsMsg),
          )
        }
        option.None -> #(model, effect.none())
      }
    }
    ReleasesMsg(m) -> {
      case model.releases {
        option.Some(releases_model) -> {
          let #(releases_model, eff) =
            releases.update(m, releases_model, model.config)
          #(
            Model(..model, releases: option.Some(releases_model)),
            effect.map(eff, ReleasesMsg),
          )
        }
        option.None -> #(model, effect.none())
      }
    }
    MilestonesMsg(m) -> {
      case model.milestones {
        option.Some(milestones_model) -> {
          let #(milestones_model, eff) =
            milestones.update(m, milestones_model, model.config)
          #(
            Model(..model, milestones: option.Some(milestones_model)),
            effect.map(eff, MilestonesMsg),
          )
        }
        option.None -> #(model, effect.none())
      }
    }
    KeysMsg(m) -> {
      let #(keys, eff) = keys.update(m, model.keys, model.config)
      #(Model(..model, keys:), effect.map(eff, KeysMsg))
    }
    MySpaceMsg(m) -> {
      let #(space, eff) = my_space.update(m, model.my_space, model.config)
      #(
        Model(..model, my_space: space),
        effect.map(eff, MySpaceMsg),
      )
    }
    ClerkSessionUpdated(user_json) -> {
      let auth_user = auth.user_from_json(user_json)
      let session_changed = session_token_changed(model.auth_user, auth_user)
      let refreshed = with_refreshed_session(model, auth_user)
      let refreshed =
        Model(
          ..refreshed,
          issue_detail: option.map(refreshed.issue_detail, fn(detail) {
            issue_detail.Model(
              ..detail,
              viewer_user_id: viewer_user_id(auth_user),
            )
          }),
        )
      #(refreshed, case session_changed {
        True ->
          route_effect(
            refreshed.config,
            refreshed.route,
            False,
            model.mr_detail,
            refreshed.mr_detail,
            False,
            model.repo_view,
            refreshed.repo_view,
            refreshed.issue_detail,
            refreshed.my_space,
          )
        False -> effect.none()
      })
    }
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
    True -> "comic-pop bg-gh-accent px-3 py-2 text-sm font-black uppercase text-gh-ink"
    False ->
      "px-3 py-2 text-sm font-bold uppercase tracking-wide text-white/85 transition hover:bg-gh-accent/20 hover:text-white"
  }
  a([attr.class(classes), attr.href(path)], [text(label)])
}

fn nav_active(current: Route, link: Route) -> Bool {
  case current, link {
    Orgs, Orgs -> True
    MySpace(_), MySpace(_) -> True
    OrgRepos(_), Orgs -> False
    RepoView(_, _, _, _, _, _), Orgs -> False
    _, _ -> current == link
  }
}

fn my_space_nav_label(unread: Int) -> String {
  case unread {
    0 -> "My space"
    n -> "My space (" <> int.to_string(n) <> ")"
  }
}

fn user_menu_item_class(active: Bool) -> String {
  case active {
    True ->
      "block w-full px-3 py-2 text-left text-sm font-black uppercase text-gh-ink bg-gh-accent"
    False ->
      "block w-full px-3 py-2 text-left text-sm font-bold text-white/90 transition hover:bg-gh-accent/20 hover:text-white"
  }
}

fn user_menu(user: auth.User, route: Route, open: Bool) -> Element(Msg) {
  let account_active = route == Account
  let keys_active = route == Keys
  let my_space_active = case route {
    MySpace(_) -> True
    _ -> False
  }
  div([attr.class("relative")], [
    button(
      [
        attr.type_("button"),
        attr.class(
          "flex items-center gap-2 border-[3px] border-gh-accent bg-gh-ink px-2 py-1.5 transition hover:bg-gh-navy-deep",
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
              "comic-badge flex h-8 w-8 items-center justify-center bg-gh-accent text-xs font-black text-gh-ink",
            ),
          ],
          [text(user.initials)],
        ),
        span(
          [
            attr.class(
              "hidden max-w-[10rem] truncate text-sm font-bold text-white sm:inline",
            ),
          ],
          [text(auth.display_name(user))],
        ),
        span([attr.class("text-xs font-bold text-gh-banana")], [text("▾")]),
      ],
    ),
    case open {
      True ->
        div(
          [
            attr.class(
              "comic-dropdown absolute right-0 z-50 mt-2 min-w-[12rem] bg-gh-ink p-1",
            ),
          ],
          [
            a(
              [
                attr.class(user_menu_item_class(my_space_active)),
                attr.href(my_tab_path(routes.MyOverview)),
              ],
              [text("My space")],
            ),
            a(
              [
                attr.class(user_menu_item_class(keys_active)),
                attr.href(keys_path()),
              ],
              [text("SSH keys")],
            ),
            a(
              [
                attr.class(user_menu_item_class(account_active)),
                attr.href(account_path()),
              ],
              [text("Account")],
            ),
            div([attr.class("my-1 border-t border-gh-accent/30")], []),
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
            components.loading_state(),
          ])
      }
    }
    OrgMembers(_) -> {
      case model.members {
        option.Some(m) -> org_members.view(m) |> map(MembersMsg)
        option.None ->
          div([attr.class(components.page)], [
            components.loading_state(),
          ])
      }
    }
    RepoView(_, _, _, _, _, _) -> {
      case model.repo_view {
        option.Some(rv) -> repo_view.view(rv, model.config) |> map(RepoViewMsg)
        option.None ->
          div([attr.class(components.page)], [
            components.loading_state(),
          ])
      }
    }
    RepoSettings(_, _) -> {
      case model.repo_settings {
        option.Some(rs) -> repo_settings.view(rs) |> map(RepoSettingsMsg)
        option.None ->
          div([attr.class(components.page)], [
            components.loading_state(),
          ])
      }
    }
    MrList(_, _) | MrNew(_, _) -> {
      case model.mr {
        option.Some(mr) -> merge_requests.view(mr) |> map(MrMsg)
        option.None ->
          div([attr.class(components.page)], [
            components.loading_state(),
          ])
      }
    }
    MrDetail(_, _, _, _) -> {
      case model.mr_detail {
        option.Some(mrd) -> merge_request_detail.view(mrd) |> map(MrDetailMsg)
        option.None ->
          div([attr.class(components.page)], [
            components.loading_state(),
          ])
      }
    }
    IssueList(_, _) | IssueNew(_, _) -> {
      case model.issues {
        option.Some(issues_model) -> issues.view(issues_model) |> map(IssueMsg)
        option.None ->
          div([attr.class(components.page)], [
            components.loading_state(),
          ])
      }
    }
    IssueDetail(_, _, _) -> {
      case model.issue_detail {
        option.Some(issue) -> issue_detail.view(issue) |> map(IssueDetailMsg)
        option.None ->
          div([attr.class(components.page)], [
            components.loading_state(),
          ])
      }
    }
    CommitsList(_, _, _) -> {
      case model.commits {
        option.Some(c) -> commits.view(c) |> map(CommitsMsg)
        option.None ->
          div([attr.class(components.page)], [
            components.loading_state(),
          ])
      }
    }
    ReleaseList(_, _) | ReleaseNew(_, _) | ReleaseDetail(_, _, _) -> {
      case model.releases {
        option.Some(releases_model) ->
          releases.view(releases_model) |> map(ReleasesMsg)
        option.None ->
          div([attr.class(components.page)], [
            components.loading_state(),
          ])
      }
    }
    MilestoneList(_, _) | MilestoneNew(_, _) | MilestoneDetail(_, _, _) -> {
      case model.milestones {
        option.Some(milestones_model) ->
          milestones.view(milestones_model) |> map(MilestonesMsg)
        option.None ->
          div([attr.class(components.page)], [
            components.loading_state(),
          ])
      }
    }
    Keys -> keys.view(model.keys) |> map(KeysMsg)
    Account -> account.view()
    MySpace(_) ->
      my_space.view(model.my_space, model.auth_user) |> map(MySpaceMsg)
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
          "border-b-4 border-gh-accent bg-gh-ink text-white shadow-md",
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
                        "comic-badge flex h-9 w-9 items-center justify-center bg-gh-accent text-sm font-black text-gh-ink",
                      ),
                    ],
                    [text("G")],
                  ),
                  span(
                    [
                      attr.class(
                        "text-lg font-black uppercase tracking-wide text-gh-banana",
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
                    nav_link(
                      MySpace(routes.MyOverview),
                      model.route,
                      my_tab_path(routes.MyOverview),
                      my_space_nav_label(my_space.unread_count(model.my_space)),
                    ),
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
