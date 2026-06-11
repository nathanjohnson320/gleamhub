import auth/auth
import components
import config.{type Config}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import http/api
import http/lustre_http
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{a, button, div, h2, img, p}
import lustre/event
import pages/my_nav
import routes.{type MyTab, MyNotifications, MyOverview}
import util/time_format

pub type Model {
  Model(
    tab: MyTab,
    me: option.Option(api.Me),
    notifications: List(api.Notification),
    notifications_loaded: Bool,
    pending_mark_read: option.Option(String),
    error: option.Option(String),
    marking_all: Bool,
  )
}

pub type Msg {
  MeLoaded(Result(api.Me, lustre_http.HttpError))
  NotificationsLoaded(Result(List(api.Notification), lustre_http.HttpError))
  MarkRead(String)
  MarkReadDone(Result(Nil, lustre_http.HttpError))
  MarkAllRead
  MarkAllReadDone(Result(Nil, lustre_http.HttpError))
}

pub fn init(tab: MyTab) -> Model {
  Model(
    tab:,
    me: option.None,
    notifications: [],
    notifications_loaded: False,
    pending_mark_read: option.None,
    error: option.None,
    marking_all: False,
  )
}

pub fn switch_tab(model: Model, tab: MyTab) -> Model {
  Model(..model, tab:, error: option.None)
}

pub fn unread_count(model: Model) -> Int {
  case model.me {
    option.Some(me) -> me.unread_notifications
    option.None -> 0
  }
}

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  let me_effect = case model.me {
    option.None ->
      lustre_http.get(
        config,
        config.api_url <> "/api/me",
        lustre_http.expect_json(api.me_decoder(), MeLoaded),
      )
    option.Some(_) -> effect.none()
  }
  let notifications_effect = case model.tab, model.notifications_loaded {
    MyNotifications, False ->
      lustre_http.get(
        config,
        config.api_url <> "/api/notifications",
        lustre_http.expect_json(
          api.notifications_decoder(),
          NotificationsLoaded,
        ),
      )
    _, _ -> effect.none()
  }
  effect.batch([me_effect, notifications_effect])
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    MeLoaded(Ok(me)) -> #(
      Model(..model, me: option.Some(me), error: option.None),
      effect.none(),
    )
    MeLoaded(Error(_)) -> #(
      Model(..model, error: option.Some("Failed to load profile")),
      effect.none(),
    )
    NotificationsLoaded(Ok(notifications)) -> #(
      Model(
        ..model,
        notifications:,
        notifications_loaded: True,
        error: option.None,
      ),
      effect.none(),
    )
    NotificationsLoaded(Error(_)) -> #(
      Model(..model, error: option.Some("Failed to load notifications")),
      effect.none(),
    )
    MarkRead(id) -> #(
      Model(..model, pending_mark_read: option.Some(id), error: option.None),
      lustre_http.patch(
        config,
        config.api_url <> "/api/notifications/" <> id <> "/read",
        json.object([]),
        lustre_http.expect_anything(MarkReadDone),
      ),
    )
    MarkReadDone(Ok(_)) -> #(
      Model(
        ..model,
        pending_mark_read: option.None,
        notifications: mark_notification_read(
          model.notifications,
          model.pending_mark_read,
        ),
        me: decrement_unread(model.me),
        error: option.None,
      ),
      effect.none(),
    )
    MarkReadDone(Error(_)) -> #(
      Model(
        ..model,
        pending_mark_read: option.None,
        error: option.Some("Could not mark notification read"),
      ),
      effect.none(),
    )
    MarkAllRead -> #(
      Model(..model, marking_all: True, error: option.None),
      lustre_http.post(
        config,
        config.api_url <> "/api/notifications/read-all",
        json.object([]),
        lustre_http.expect_anything(MarkAllReadDone),
      ),
    )
    MarkAllReadDone(Ok(_)) -> #(
      Model(
        ..model,
        marking_all: False,
        notifications: mark_all_read_local(model.notifications),
        me: clear_unread(model.me),
        error: option.None,
      ),
      effect.none(),
    )
    MarkAllReadDone(Error(_)) -> #(
      Model(
        ..model,
        marking_all: False,
        error: option.Some("Could not mark all read"),
      ),
      effect.none(),
    )
  }
}

pub fn view(model: Model, auth_user: option.Option(auth.User)) -> Element(Msg) {
  div([attr.class(components.page)], [
    profile_header(auth_user),
    my_nav.tabs(model.tab, unread_count(model)),
    div([attr.class("mt-6")], [
      case model.error {
        option.Some(e) -> components.error_alert(e)
        option.None -> text("")
      },
      case model.tab {
        MyOverview -> overview_tab(model)
        MyNotifications -> notifications_tab(model)
      },
    ]),
  ])
}

fn profile_header(auth_user: option.Option(auth.User)) -> Element(Msg) {
  let name = case auth_user {
    option.Some(user) -> auth.display_name(user)
    option.None -> "Your profile"
  }
  div(
    [
      attr.class(
        "mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between",
      ),
    ],
    [
      div([attr.class("flex items-center gap-4")], [
        avatar(auth_user),
        div([], [
          h2([attr.class(components.page_title_sm)], [text(name)]),
        ]),
      ]),
    ],
  )
}

fn avatar(auth_user: option.Option(auth.User)) -> Element(Msg) {
  case auth_user {
    option.Some(user) ->
      case user.image_url {
        option.Some(url) ->
          img([
            attr.src(url),
            attr.alt(user.initials),
            attr.class("h-16 w-16 border-[3px] border-gh-ink object-cover"),
          ])
        option.None ->
          div(
            [
              attr.class(
                "comic-panel flex h-16 w-16 items-center justify-center bg-gh-accent text-xl font-black text-gh-ink",
              ),
            ],
            [text(user.initials)],
          )
      }
    option.None ->
      div(
        [
          attr.class(
            "comic-panel-inset flex h-16 w-16 items-center justify-center text-xl font-black text-gh-muted",
          ),
        ],
        [text("?")],
      )
  }
}

fn overview_tab(model: Model) -> Element(Msg) {
  case model.me {
    option.None -> components.loading_state()
    option.Some(me) ->
      div([attr.class("space-y-8")], [
        stats_grid(me.stats),
        orgs_section(me),
      ])
  }
}

fn stats_grid(stats: api.UserStats) -> Element(Msg) {
  div([attr.class("grid gap-4 sm:grid-cols-2 lg:grid-cols-3")], [
    stat_card("Open merge requests", stats.open_merge_requests),
    stat_card("Merged merge requests", stats.merged_merge_requests),
    stat_card("Open issues authored", stats.open_issues_authored),
    stat_card("Open issues assigned", stats.open_issues_assigned),
    stat_card("Reviews given", stats.reviews_given),
  ])
}

fn stat_card(label: String, value: Int) -> Element(Msg) {
  div([attr.class(components.card <> " text-center sm:text-left")], [
    p(
      [attr.class("text-xs font-black uppercase tracking-widest text-gh-muted")],
      [
        text(label),
      ],
    ),
    p([attr.class("mt-2 text-4xl font-black tabular-nums text-gh-ink")], [
      text(int.to_string(value)),
    ]),
  ])
}

fn orgs_section(me: api.Me) -> Element(Msg) {
  div([attr.class(components.card)], [
    h2([attr.class("text-lg font-black uppercase tracking-wide text-gh-ink")], [
      text("Organizations"),
    ]),
    p([attr.class("mt-1 text-sm text-gh-muted")], [
      text("Repositories you belong to across Gleamhub."),
    ]),
    div([attr.class("mt-4 space-y-2")], {
      case me.organizations {
        [] -> [components.empty_state("No organizations yet.")]
        orgs ->
          list.map(orgs, fn(org) {
            components.list_link_card(
              routes.org_repos_path(org.slug),
              org.name,
              option.Some(org.slug),
            )
          })
      }
    }),
  ])
}

fn notifications_tab(model: Model) -> Element(Msg) {
  div([attr.class("space-y-4")], [
    div([attr.class("flex items-center justify-between gap-3")], [
      h2(
        [
          attr.class(
            "flex items-center gap-2 text-lg font-semibold text-gh-ink",
          ),
        ],
        [
          text("Notifications"),
          components.unread_count_badge(unread_count(model)),
        ],
      ),
      button(
        [
          attr.type_("button"),
          attr.class(components.btn_secondary),
          attr.disabled(model.marking_all || model.notifications == []),
          event.on_click(MarkAllRead),
        ],
        [text("Mark all read")],
      ),
    ]),
    case model.notifications_loaded, model.notifications {
      False, [] -> components.loading_state()
      _, [] -> components.empty_state("You're all caught up.")
      _, items ->
        div([attr.class("space-y-2")], list.map(items, notification_item))
    },
  ])
}

fn notification_item(notification: api.Notification) -> Element(Msg) {
  let unread = notification.read_at == option.None
  let row_class = case unread {
    True -> "comic-panel-inset border-gh-accent bg-gh-accent-soft/40"
    False -> "comic-panel-inset bg-white"
  }
  let body =
    div(
      [
        attr.class(
          "block px-4 py-3 transition hover:border-gh-accent " <> row_class,
        ),
      ],
      [
        p([attr.class("text-sm font-medium text-gh-ink")], [
          text(notification_summary(notification)),
        ]),
        p([attr.class("mt-1 text-xs text-gh-muted")], [
          text(time_format.format_timestamp(notification.created_at)),
        ]),
      ],
    )
  case notification_href(notification) {
    option.Some(path) ->
      a(
        [
          attr.href(path),
          event.on_click(MarkRead(notification.id)),
        ],
        [body],
      )
    option.None -> div([event.on_click(MarkRead(notification.id))], [body])
  }
}

pub fn notification_summary(notification: api.Notification) -> String {
  case notification.type_ {
    "mention.mr_comment" ->
      "You were mentioned on " <> merge_request_label(notification.payload)
    "mention.issue_comment" ->
      "You were mentioned on " <> issue_label(notification.payload)
    "mr.review" ->
      "Review submitted on " <> merge_request_label(notification.payload)
    "ci.complete" ->
      case payload_string(notification.payload, "pipeline_state") {
        option.Some("failure") ->
          "CI failed on " <> merge_request_label(notification.payload)
        option.Some("success") ->
          "CI passed on " <> merge_request_label(notification.payload)
        _ -> "CI finished on " <> merge_request_label(notification.payload)
      }
    "org.invitation" ->
      case payload_string(notification.payload, "org_name") {
        option.Some(name) -> "You were invited to join " <> name
        option.None -> "You were invited to join an organization"
      }
    _ -> "New notification"
  }
}

pub fn merge_request_label(payload: String) -> String {
  let repo = payload_string(payload, "repo_name") |> option.unwrap("repository")
  case payload_int(payload, "merge_request_number") {
    option.Some(number) ->
      case payload_string(payload, "merge_request_title") {
        option.Some(title) ->
          repo <> " #" <> int.to_string(number) <> " " <> title
        option.None -> repo <> " #" <> int.to_string(number)
      }
    option.None -> repo
  }
}

fn issue_label(payload: String) -> String {
  let repo = payload_string(payload, "repo_name") |> option.unwrap("repository")
  case payload_int(payload, "issue_number") {
    option.Some(number) ->
      case payload_string(payload, "issue_title") {
        option.Some(title) ->
          repo <> " #" <> int.to_string(number) <> " " <> title
        option.None -> repo <> " #" <> int.to_string(number)
      }
    option.None -> repo
  }
}

fn notification_href(notification: api.Notification) -> option.Option(String) {
  let org = payload_string(notification.payload, "org_slug")
  let repo = payload_string(notification.payload, "repo_name")
  case notification.type_, org, repo {
    "org.invitation", option.Some(slug), _ ->
      option.Some(routes.org_repos_path(slug))
    _, option.Some(org_slug), option.Some(repo_name) ->
      case payload_int(notification.payload, "merge_request_number") {
        option.Some(n) ->
          option.Some(routes.mr_detail_path(org_slug, repo_name, n))
        option.None ->
          case payload_int(notification.payload, "issue_number") {
            option.Some(n) ->
              option.Some(routes.issue_detail_path(org_slug, repo_name, n))
            option.None -> option.None
          }
      }
    _, _, _ -> option.None
  }
}

fn mark_notification_read(
  notifications: List(api.Notification),
  pending: option.Option(String),
) -> List(api.Notification) {
  case pending {
    option.None -> notifications
    option.Some(id) ->
      list.map(notifications, fn(notification) {
        case notification.id == id {
          True -> api.Notification(..notification, read_at: option.Some("read"))
          False -> notification
        }
      })
  }
}

fn mark_all_read_local(
  notifications: List(api.Notification),
) -> List(api.Notification) {
  list.map(notifications, fn(notification) {
    api.Notification(..notification, read_at: option.Some("read"))
  })
}

fn decrement_unread(me: option.Option(api.Me)) -> option.Option(api.Me) {
  option.map(me, fn(profile) {
    api.Me(
      ..profile,
      unread_notifications: int.max(0, profile.unread_notifications - 1),
    )
  })
}

fn clear_unread(me: option.Option(api.Me)) -> option.Option(api.Me) {
  option.map(me, fn(profile) { api.Me(..profile, unread_notifications: 0) })
}

fn payload_string(payload: String, key: String) -> option.Option(String) {
  let decoder = {
    use value <- decode.optional_field(
      key,
      option.None,
      decode.optional(decode.string),
    )
    decode.success(value)
  }
  case json.parse(payload, decoder) {
    Ok(value) -> value
    Error(_) -> option.None
  }
}

fn payload_int(payload: String, key: String) -> option.Option(Int) {
  let decoder = {
    use value <- decode.optional_field(
      key,
      option.None,
      decode.optional(decode.int),
    )
    decode.success(value)
  }
  case json.parse(payload, decoder) {
    Ok(value) -> value
    Error(_) -> option.None
  }
}
