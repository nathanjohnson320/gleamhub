import components
import config.{type Config}
import gleam/list
import gleam/option
import gleam/string
import gleam/uri
import http/api.{
  type Org, type OrgInvitation, type OrgMember, type UserSearchResult,
}
import http/lustre_http
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{
  button, div, input, option as html_option, p, select, span,
}
import lustre/event
import pages/org_access
import pages/org_nav
import util/time_format

pub type Model {
  Model(
    org_slug: String,
    gate: org_access.Gate,
    org_role: option.Option(String),
    members: List(OrgMember),
    invitations: List(OrgInvitation),
    search_query: String,
    search_results: List(UserSearchResult),
    invite_role: String,
    error: option.Option(String),
  )
}

pub type Msg {
  OrgLoaded(Result(Org, lustre_http.HttpError))
  MembersLoaded(Result(List(OrgMember), lustre_http.HttpError))
  InvitationsLoaded(Result(List(OrgInvitation), lustre_http.HttpError))
  SearchChanged(String)
  SearchResults(Result(List(UserSearchResult), lustre_http.HttpError))
  Invite(String)
  Invited(Result(OrgInvitation, lustre_http.HttpError))
  RemoveMember(String)
  MemberRemoved(Result(Nil, lustre_http.HttpError))
  CancelInvitation(String)
  InvitationCancelled(Result(Nil, lustre_http.HttpError))
  InviteRoleChanged(String)
  UpdateMemberRole(String, String)
  MemberRoleUpdated(Result(OrgMember, lustre_http.HttpError))
}

pub fn init(org_slug: String) -> Model {
  Model(
    org_slug:,
    gate: org_access.Pending,
    org_role: option.None,
    members: [],
    invitations: [],
    search_query: "",
    search_results: [],
    invite_role: "member",
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

fn reload_members(config: Config, org_slug: String) -> Effect(Msg) {
  lustre_http.get(
    config,
    config.api_url <> "/api/orgs/" <> org_slug <> "/members",
    lustre_http.expect_json(api.members_decoder(), MembersLoaded),
  )
}

fn reload_invitations(config: Config, org_slug: String) -> Effect(Msg) {
  lustre_http.get(
    config,
    config.api_url <> "/api/orgs/" <> org_slug <> "/invitations",
    lustre_http.expect_json(api.invitations_decoder(), InvitationsLoaded),
  )
}

fn search_users(
  config: Config,
  org_slug: String,
  query: String,
) -> Effect(Msg) {
  let encoded = uri.percent_encode(query)
  lustre_http.get(
    config,
    config.api_url
      <> "/api/users/search?q="
      <> encoded
      <> "&org="
      <> uri.percent_encode(org_slug),
    lustre_http.expect_json(api.user_search_results_decoder(), SearchResults),
  )
}

fn member_label(member: OrgMember) -> String {
  case member.username {
    option.Some(username) -> "@" <> username
    option.None -> member.display_name
  }
}

fn invitation_label(invitation: OrgInvitation) -> String {
  case invitation.username {
    option.Some(username) -> "@" <> username
    option.None -> invitation.display_name
  }
}

fn is_owner(role: option.Option(String)) -> Bool {
  case role {
    option.Some("owner") -> True
    _ -> False
  }
}

fn owner_count(members: List(OrgMember)) -> Int {
  list.count(members, fn(member) { member.role == "owner" })
}

fn sole_owner(member: OrgMember, members: List(OrgMember)) -> Bool {
  member.role == "owner" && owner_count(members) == 1
}

fn role_select(
  id: String,
  value: String,
  on_change: fn(String) -> Msg,
) -> Element(Msg) {
  select(
    [
      attr.id(id),
      attr.class(components.input),
      event.on_change(on_change),
    ],
    [
      html_option(
        [attr.value("member"), attr.selected(value == "member")],
        "Member",
      ),
      html_option(
        [attr.value("owner"), attr.selected(value == "owner")],
        "Owner",
      ),
    ],
  )
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    OrgLoaded(Ok(org)) -> {
      let owner = is_owner(org.role)
      #(
        Model(
          ..model,
          gate: org_access.Allowed(org.role, org.name),
          org_role: org.role,
          error: option.None,
        ),
        effect.batch([
          reload_members(config, model.org_slug),
          case owner {
            True -> reload_invitations(config, model.org_slug)
            False -> effect.none()
          },
        ]),
      )
    }
    OrgLoaded(Error(err)) -> #(
      Model(..model, gate: org_access.gate_from_org(Error(err))),
      effect.none(),
    )
    MembersLoaded(Ok(members)) -> #(
      Model(..model, members:, error: option.None),
      effect.none(),
    )
    MembersLoaded(Error(_)) -> #(
      Model(..model, error: option.Some("Failed to load members")),
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
    SearchChanged(query) -> {
      let trimmed = string.trim(query)
      #(
        Model(..model, search_query: query, search_results: []),
        case string.length(trimmed) >= 2 {
          True -> search_users(config, model.org_slug, trimmed)
          False -> effect.none()
        },
      )
    }
    SearchResults(Ok(results)) -> #(
      Model(..model, search_results: results),
      effect.none(),
    )
    SearchResults(Error(err)) -> #(
      Model(
        ..model,
        search_results: [],
        error: option.Some(search_error_message(err, "Search failed")),
      ),
      effect.none(),
    )
    InviteRoleChanged(role) -> #(
      Model(..model, invite_role: role),
      effect.none(),
    )
    Invite(user_id) -> #(
      Model(..model, error: option.None),
      lustre_http.post(
        config,
        config.api_url <> "/api/orgs/" <> model.org_slug <> "/invitations",
        api.create_invitation_body(user_id, model.invite_role),
        lustre_http.expect_json(api.invitation_decoder(), Invited),
      ),
    )
    Invited(Ok(invitation)) -> #(
      Model(
        ..model,
        invitations: [invitation, ..model.invitations],
        search_query: "",
        search_results: [],
        error: option.None,
      ),
      effect.none(),
    )
    Invited(Error(lustre_http.OtherError(409, _))) -> #(
      Model(
        ..model,
        error: option.Some("That user is already invited or a member."),
      ),
      effect.none(),
    )
    Invited(Error(_)) -> #(
      Model(..model, error: option.Some("Could not send invitation")),
      effect.none(),
    )
    RemoveMember(user_id) -> #(
      model,
      lustre_http.delete(
        config,
        config.api_url
          <> "/api/orgs/"
          <> model.org_slug
          <> "/members/"
          <> uri.percent_encode(user_id),
        lustre_http.expect_anything(MemberRemoved),
      ),
    )
    MemberRemoved(Ok(_)) -> #(model, reload_members(config, model.org_slug))
    MemberRemoved(Error(_)) -> #(
      Model(..model, error: option.Some("Could not remove member")),
      effect.none(),
    )
    CancelInvitation(id) -> #(
      model,
      lustre_http.delete(
        config,
        config.api_url
          <> "/api/orgs/"
          <> model.org_slug
          <> "/invitations/"
          <> id,
        lustre_http.expect_anything(InvitationCancelled),
      ),
    )
    InvitationCancelled(Ok(_)) -> #(
      model,
      reload_invitations(config, model.org_slug),
    )
    InvitationCancelled(Error(_)) -> #(
      Model(..model, error: option.Some("Could not cancel invitation")),
      effect.none(),
    )
    UpdateMemberRole(user_id, role) -> #(
      Model(..model, error: option.None),
      lustre_http.patch(
        config,
        config.api_url
          <> "/api/orgs/"
          <> model.org_slug
          <> "/members/"
          <> uri.percent_encode(user_id),
        api.update_member_role_body(role),
        lustre_http.expect_json(api.member_decoder(), MemberRoleUpdated),
      ),
    )
    MemberRoleUpdated(Ok(_)) -> #(model, reload_members(config, model.org_slug))
    MemberRoleUpdated(Error(lustre_http.OtherError(422, _))) -> #(
      Model(
        ..model,
        error: option.Some("Cannot demote or remove the last owner."),
      ),
      effect.none(),
    )
    MemberRoleUpdated(Error(_)) -> #(
      Model(..model, error: option.Some("Could not update member role")),
      effect.none(),
    )
  }
}

fn search_error_message(
  err: lustre_http.HttpError,
  fallback: String,
) -> String {
  let body = case err {
    lustre_http.OtherError(_, b) | lustre_http.InternalServerError(b) -> b
    _ -> ""
  }
  case body {
    "" -> fallback
    json_str -> api.error_message_from_json(json_str, fallback)
  }
}

fn role_badge(role: String) -> Element(Msg) {
  span(
    [
      attr.class(
        "rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium uppercase text-gh-muted",
      ),
    ],
    [text(role)],
  )
}

pub fn view(model: Model) -> Element(Msg) {
  case model.gate {
    org_access.Pending -> org_access.pending_view()
    org_access.Forbidden -> org_access.forbidden_view()
    org_access.NotFound -> org_access.not_found_view()
    org_access.Failed(message) -> org_access.failed_view(message)
    org_access.Allowed(role, name) -> members_view(model, role, name)
  }
}

fn members_view(
  model: Model,
  role: option.Option(String),
  org_name: String,
) -> Element(Msg) {
  let owner = is_owner(role)
  let member_items = case model.members {
    [] -> [components.empty_state("No members yet.")]
    members ->
      list.map(members, fn(member) {
        let last_owner = sole_owner(member, members)
        div([attr.class(components.list_item)], [
          div([], [
            p([attr.class("font-semibold text-gh-ink")], [
              text(member_label(member)),
            ]),
            p([attr.class("mt-1 text-sm text-gh-muted")], [
              text(member.display_name),
            ]),
            case owner {
              True ->
                div([attr.class("mt-3 max-w-xs")], [
                  components.field_label(
                    "member-role-" <> member.user_id,
                    "Role",
                  ),
                  role_select(
                    "member-role-" <> member.user_id,
                    member.role,
                    fn(role) { UpdateMemberRole(member.user_id, role) },
                  ),
                  case last_owner {
                    True ->
                      components.field_hint(
                        "This is the only owner — promote another owner before demoting.",
                      )
                    False -> text("")
                  },
                ])
              False -> div([attr.class("mt-2")], [role_badge(member.role)])
            },
          ]),
          case owner, last_owner {
            True, True -> text("")
            True, False ->
              button(
                [
                  attr.class(components.btn_danger),
                  attr.type_("button"),
                  event.on_click(RemoveMember(member.user_id)),
                ],
                [text("Remove")],
              )
            _, _ -> text("")
          },
        ])
      })
  }

  let search_results = case model.search_results {
    [] -> []
    results ->
      list.map(results, fn(result) {
        div([attr.class(components.list_item)], [
          div([], [
            p([attr.class("font-semibold text-gh-ink")], [
              text(case result.username {
                option.Some(username) -> "@" <> username
                option.None -> result.display_name
              }),
            ]),
            p([attr.class("mt-1 text-sm text-gh-muted")], [
              text(result.display_name),
            ]),
          ]),
          button(
            [
              attr.class(components.btn_secondary),
              attr.type_("button"),
              event.on_click(Invite(result.id)),
            ],
            [text("Invite")],
          ),
        ])
      })
  }

  let invitation_items = case model.invitations {
    [] -> [components.empty_state("No pending invitations.")]
    invitations ->
      list.map(invitations, fn(invitation) {
        div([attr.class(components.list_item)], [
          div([], [
            p([attr.class("font-semibold text-gh-ink")], [
              text(invitation_label(invitation)),
            ]),
            p([attr.class("mt-1 text-sm text-gh-muted")], [
              text(
                "Invited " <> time_format.format_timestamp(invitation.created_at),
              ),
            ]),
            div([attr.class("mt-2")], [role_badge(invitation.role)]),
          ]),
          button(
            [
              attr.class(components.btn_danger),
              attr.type_("button"),
              event.on_click(CancelInvitation(invitation.id)),
            ],
            [text("Cancel")],
          ),
        ])
      })
  }

  div([attr.class(components.page)], [
    components.breadcrumb_back("/orgs", "Organizations"),
    components.page_header(
      org_name,
      "Members who can access repositories in this organization.",
    ),
    org_nav.tabs(model.org_slug, org_nav.Members),
    div([attr.class("mt-6")], [
      case model.error {
        option.Some(e) -> components.error_alert(e)
        option.None -> text("")
      },
      div([attr.class(components.card <> " mb-6")], [
        p([attr.class(components.section_title)], [text("Members")]),
        div([attr.class("space-y-2")], member_items),
      ]),
      case owner {
        True ->
          div([attr.class(components.card <> " mb-6")], [
            p([attr.class(components.section_title)], [text("Invite member")]),
            div([attr.class("mb-4 grid gap-4 sm:grid-cols-2")], [
              div([], [
                components.field_label("invite-role", "Invite as"),
                role_select("invite-role", model.invite_role, InviteRoleChanged),
              ]),
              div([], [
                components.field_label("member-search", "Search by username"),
                input([
                  attr.id("member-search"),
                  attr.class(components.input),
                  attr.value(model.search_query),
                  attr.placeholder("Search by username…"),
                  event.on_input(SearchChanged),
                ]),
                components.field_hint(
                  "Type at least 2 characters to search Clerk users.",
                ),
              ]),
            ]),
            div([attr.class("space-y-2")], search_results),
          ])
        False -> text("")
      },
      case owner {
        True -> components.card_section("Pending invitations", invitation_items)
        False -> text("")
      },
    ]),
  ])
}
