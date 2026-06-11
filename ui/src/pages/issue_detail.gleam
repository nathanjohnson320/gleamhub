import components
import config.{type Config}
import content/markdown
import content/mentions
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import http/api.{
  type Issue, type IssueComment, type IssueDetail, type Label,
  type LinkedMergeRequest, type Milestone, type OrgMember,
}
import http/lustre_http
import labels_ui
import lustre/attribute as attr
import lustre/effect.{type Effect, batch, none}
import lustre/element.{type Element, text, unsafe_raw_html}
import lustre/element/html.{
  a, aside, button, div, form, h1, input, li, p, span, textarea, ul,
}
import lustre/event
import routes
import util/time_format

const timeline_list = "space-y-4"

const timeline_item = "relative flex gap-3"

const timeline_line = "absolute left-5 top-10 bottom-0 w-px -translate-x-1/2 bg-slate-200"

const avatar_class = "relative z-10 flex h-10 w-10 shrink-0 items-center justify-center rounded-full border-2 border-white bg-slate-200 text-sm font-semibold text-slate-600 ring-1 ring-slate-200"

const event_card = "min-w-0 flex-1 overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm"

const event_header = "border-b border-slate-200 bg-slate-50 px-4 py-2.5 text-sm text-gh-muted"

const event_body = "px-4 py-4"

pub type Model {
  Model(
    org_slug: String,
    repo_name: String,
    number: Int,
    detail: option.Option(IssueDetail),
    comments: List(IssueComment),
    repo_labels: List(Label),
    repo_milestones: List(Milestone),
    org_members: List(OrgMember),
    comment_body: String,
    editing: Bool,
    edit_title: String,
    edit_description: String,
    saving: Bool,
    loading: Bool,
    error: option.Option(String),
    labels_menu_open: Bool,
    label_filter: String,
    assignees_menu_open: Bool,
    assignee_filter: String,
    milestones_menu_open: Bool,
    milestone_filter: String,
    viewer_user_id: option.Option(String),
    editing_comment_id: option.Option(String),
    editing_comment_body: String,
  )
}

pub type Msg {
  DetailLoaded(Result(IssueDetail, lustre_http.HttpError))
  CommentsLoaded(Result(List(IssueComment), lustre_http.HttpError))
  LabelsLoaded(Result(List(Label), lustre_http.HttpError))
  MilestonesLoaded(Result(List(Milestone), lustre_http.HttpError))
  MembersLoaded(Result(List(OrgMember), lustre_http.HttpError))
  CommentBodyChanged(String)
  SubmitComment
  CommentPosted(Result(IssueComment, lustre_http.HttpError))
  StartEditComment(String, String)
  CancelEditComment
  EditCommentBodyChanged(String)
  SaveComment
  CommentUpdated(Result(IssueComment, lustre_http.HttpError))
  DeleteComment(String)
  CommentDeleted(Result(Nil, lustre_http.HttpError))
  CloseIssue
  Closed(Result(Issue, lustre_http.HttpError))
  ReopenIssue
  Reopened(Result(Issue, lustre_http.HttpError))
  StartEdit
  CancelEdit
  EditTitleChanged(String)
  EditDescriptionChanged(String)
  SaveEdit
  Saved(Result(Issue, lustre_http.HttpError))
  ToggleLabel(String)
  LabelToggled(Result(Issue, lustre_http.HttpError))
  ToggleAssignee(String)
  AssigneeToggled(Result(Issue, lustre_http.HttpError))
  ToggleLabelsMenu
  LabelFilterChanged(String)
  ToggleAssigneesMenu
  AssigneeFilterChanged(String)
  ToggleMilestonesMenu
  MilestoneFilterChanged(String)
  SelectMilestone(String)
  MilestoneToggled(Result(Issue, lustre_http.HttpError))
}

pub fn init(
  org_slug: String,
  repo_name: String,
  number: Int,
  viewer_user_id: option.Option(String),
) -> Model {
  Model(
    org_slug:,
    repo_name:,
    number:,
    viewer_user_id:,
    detail: option.None,
    comments: [],
    repo_labels: [],
    repo_milestones: [],
    org_members: [],
    comment_body: "",
    editing: False,
    edit_title: "",
    edit_description: "",
    saving: False,
    loading: True,
    error: option.None,
    labels_menu_open: False,
    label_filter: "",
    assignees_menu_open: False,
    assignee_filter: "",
    milestones_menu_open: False,
    milestone_filter: "",
    editing_comment_id: option.None,
    editing_comment_body: "",
  )
}

fn api_base(config: Config, model: Model) -> String {
  config.api_url
  <> "/api/orgs/"
  <> model.org_slug
  <> "/repos/"
  <> model.repo_name
  <> "/issues/"
  <> int.to_string(model.number)
}

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  let base = api_base(config, model)
  batch([
    lustre_http.get(
      config,
      base,
      lustre_http.expect_json(api.issue_detail_decoder(), DetailLoaded),
    ),
    lustre_http.get(
      config,
      base <> "/comments",
      lustre_http.expect_json(api.issue_comments_decoder(), CommentsLoaded),
    ),
    lustre_http.get(
      config,
      config.api_url
        <> "/api/orgs/"
        <> model.org_slug
        <> "/repos/"
        <> model.repo_name
        <> "/labels",
      lustre_http.expect_json(api.labels_decoder(), LabelsLoaded),
    ),
    lustre_http.get(
      config,
      config.api_url
        <> "/api/orgs/"
        <> model.org_slug
        <> "/repos/"
        <> model.repo_name
        <> "/milestones",
      lustre_http.expect_json(api.milestones_decoder(), MilestonesLoaded),
    ),
    lustre_http.get(
      config,
      config.api_url <> "/api/orgs/" <> model.org_slug <> "/members",
      lustre_http.expect_json(api.members_decoder(), MembersLoaded),
    ),
  ])
}

fn issue_from_detail(model: Model) -> option.Option(Issue) {
  case model.detail {
    option.Some(d) -> option.Some(d.issue)
    option.None -> option.None
  }
}

fn selected_label_ids(issue: Issue) -> List(String) {
  list.map(issue.labels, fn(label) { label.id })
}

fn selected_assignee_ids(issue: Issue) -> List(String) {
  list.map(issue.assignees, fn(assignee) { assignee.user_id })
}

fn labels_for_ids(repo_labels: List(Label), ids: List(String)) -> List(Label) {
  list.filter(repo_labels, fn(label) { list.contains(ids, label.id) })
}

fn assignees_for_ids(
  members: List(OrgMember),
  ids: List(String),
) -> List(api.IssueAssignee) {
  list.map(ids, fn(id) {
    let display_name = case
      list.first(list.filter(members, fn(m) { m.user_id == id }))
    {
      Ok(member) -> member_label(member)
      Error(_) -> id
    }
    api.IssueAssignee(user_id: id, display_name:)
  })
}

fn patch_issue(
  config: Config,
  model: Model,
  issue: Issue,
  label_ids: List(String),
  assignee_user_ids: List(String),
  on_done: fn(Result(Issue, lustre_http.HttpError)) -> Msg,
) -> Effect(Msg) {
  lustre_http.patch(
    config,
    api_base(config, model),
    api.update_issue_body(
      issue.title,
      issue.description,
      label_ids,
      assignee_user_ids,
      option.None,
    ),
    lustre_http.expect_json(api.issue_decoder(), on_done),
  )
}

fn patch_issue_milestone(
  config: Config,
  model: Model,
  milestone_id: option.Option(String),
  on_done: fn(Result(Issue, lustre_http.HttpError)) -> Msg,
) -> Effect(Msg) {
  lustre_http.patch(
    config,
    api_base(config, model),
    api.update_issue_milestone_body(milestone_id),
    lustre_http.expect_json(api.issue_decoder(), on_done),
  )
}

fn reload_issue_detail(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model),
    lustre_http.expect_json(api.issue_detail_decoder(), DetailLoaded),
  )
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    DetailLoaded(Ok(d)) -> #(
      Model(
        ..model,
        detail: option.Some(d),
        edit_title: d.issue.title,
        edit_description: option.unwrap(d.issue.description, ""),
        loading: False,
        error: option.None,
      ),
      none(),
    )
    DetailLoaded(Error(_)) -> #(
      Model(..model, loading: False, error: option.Some("Failed to load issue")),
      none(),
    )
    CommentsLoaded(Ok(comments)) -> #(Model(..model, comments:), none())
    CommentsLoaded(Error(_)) -> #(model, none())
    LabelsLoaded(Ok(labels)) -> #(Model(..model, repo_labels: labels), none())
    LabelsLoaded(Error(_)) -> #(model, none())
    MembersLoaded(Ok(members)) -> #(
      Model(..model, org_members: members),
      none(),
    )
    MembersLoaded(Error(_)) -> #(model, none())
    CommentBodyChanged(v) -> #(Model(..model, comment_body: v), none())
    SubmitComment -> #(
      model,
      lustre_http.post(
        config,
        api_base(config, model) <> "/comments",
        api.create_issue_comment_body(model.comment_body),
        lustre_http.expect_json(api.issue_comment_decoder(), CommentPosted),
      ),
    )
    CommentPosted(Ok(_)) -> #(
      Model(..model, comment_body: ""),
      lustre_http.get(
        config,
        api_base(config, model) <> "/comments",
        lustre_http.expect_json(api.issue_comments_decoder(), CommentsLoaded),
      ),
    )
    CommentPosted(Error(_)) -> #(
      Model(..model, error: option.Some("Could not post comment")),
      none(),
    )
    StartEditComment(id, body) -> #(
      Model(
        ..model,
        editing_comment_id: option.Some(id),
        editing_comment_body: body,
        error: option.None,
      ),
      none(),
    )
    CancelEditComment -> #(
      Model(..model, editing_comment_id: option.None, editing_comment_body: ""),
      none(),
    )
    EditCommentBodyChanged(body) -> #(
      Model(..model, editing_comment_body: body),
      none(),
    )
    SaveComment -> {
      case model.editing_comment_id {
        option.None -> #(model, none())
        option.Some(comment_id) -> #(
          model,
          lustre_http.patch(
            config,
            api_base(config, model) <> "/comments/" <> comment_id,
            api.update_comment_body(model.editing_comment_body),
            lustre_http.expect_json(api.issue_comment_decoder(), CommentUpdated),
          ),
        )
      }
    }
    CommentUpdated(Ok(_)) -> #(
      Model(
        ..model,
        editing_comment_id: option.None,
        editing_comment_body: "",
        error: option.None,
      ),
      lustre_http.get(
        config,
        api_base(config, model) <> "/comments",
        lustre_http.expect_json(api.issue_comments_decoder(), CommentsLoaded),
      ),
    )
    CommentUpdated(Error(_)) -> #(
      Model(..model, error: option.Some("Could not update comment")),
      none(),
    )
    DeleteComment(comment_id) -> #(
      model,
      lustre_http.delete(
        config,
        api_base(config, model) <> "/comments/" <> comment_id,
        lustre_http.expect_anything(CommentDeleted),
      ),
    )
    CommentDeleted(Ok(_)) -> #(
      Model(..model, error: option.None),
      lustre_http.get(
        config,
        api_base(config, model) <> "/comments",
        lustre_http.expect_json(api.issue_comments_decoder(), CommentsLoaded),
      ),
    )
    CommentDeleted(Error(_)) -> #(
      Model(..model, error: option.Some("Could not delete comment")),
      none(),
    )
    CloseIssue -> #(
      model,
      lustre_http.post(
        config,
        api_base(config, model) <> "/close",
        json.object([]),
        lustre_http.expect_json(api.issue_decoder(), Closed),
      ),
    )
    Closed(Ok(issue)) -> #(
      Model(
        ..model,
        detail: option.map(model.detail, fn(d) {
          api.IssueDetail(issue:, linked_merge_requests: d.linked_merge_requests)
        }),
        editing: False,
        error: option.None,
      ),
      none(),
    )
    Closed(Error(_)) -> #(
      Model(..model, error: option.Some("Could not close issue")),
      none(),
    )
    ReopenIssue -> #(
      model,
      lustre_http.post(
        config,
        api_base(config, model) <> "/reopen",
        json.object([]),
        lustre_http.expect_json(api.issue_decoder(), Reopened),
      ),
    )
    Reopened(Ok(issue)) -> #(
      Model(
        ..model,
        detail: option.map(model.detail, fn(d) {
          api.IssueDetail(issue:, linked_merge_requests: d.linked_merge_requests)
        }),
        editing: False,
        error: option.None,
      ),
      none(),
    )
    Reopened(Error(_)) -> #(
      Model(..model, error: option.Some("Could not reopen issue")),
      none(),
    )
    StartEdit -> #(
      case issue_from_detail(model) {
        option.Some(issue) ->
          Model(
            ..model,
            editing: True,
            edit_title: issue.title,
            edit_description: option.unwrap(issue.description, ""),
            error: option.None,
          )
        option.None -> model
      },
      none(),
    )
    CancelEdit -> #(Model(..model, editing: False, error: option.None), none())
    EditTitleChanged(v) -> #(Model(..model, edit_title: v), none())
    EditDescriptionChanged(v) -> #(Model(..model, edit_description: v), none())
    SaveEdit ->
      case issue_from_detail(model) {
        option.None -> #(model, none())
        option.Some(issue) -> #(
          Model(..model, saving: True),
          lustre_http.patch(
            config,
            api_base(config, model),
            api.update_issue_body(
              string.trim(model.edit_title),
              case string.trim(model.edit_description) {
                "" -> option.None
                d -> option.Some(d)
              },
              selected_label_ids(issue),
              selected_assignee_ids(issue),
              option.None,
            ),
            lustre_http.expect_json(api.issue_decoder(), Saved),
          ),
        )
      }
    Saved(Ok(issue)) -> #(
      Model(
        ..model,
        detail: option.map(model.detail, fn(d) {
          api.IssueDetail(issue:, linked_merge_requests: d.linked_merge_requests)
        }),
        editing: False,
        saving: False,
        edit_title: issue.title,
        edit_description: option.unwrap(issue.description, ""),
        error: option.None,
      ),
      none(),
    )
    Saved(Error(_)) -> #(
      Model(..model, saving: False, error: option.Some("Could not save issue")),
      none(),
    )
    ToggleLabel(label_id) ->
      case issue_from_detail(model) {
        option.None -> #(model, none())
        option.Some(issue) -> {
          let ids = selected_label_ids(issue)
          let next_ids = case list.contains(ids, label_id) {
            True -> list.filter(ids, fn(id) { id != label_id })
            False -> [label_id, ..ids]
          }
          let optimistic =
            api.Issue(
              ..issue,
              labels: labels_for_ids(model.repo_labels, next_ids),
            )
          #(
            Model(
              ..model,
              detail: option.map(model.detail, fn(d) {
                api.IssueDetail(
                  issue: optimistic,
                  linked_merge_requests: d.linked_merge_requests,
                )
              }),
              error: option.None,
            ),
            patch_issue(
              config,
              model,
              issue,
              next_ids,
              selected_assignee_ids(issue),
              LabelToggled,
            ),
          )
        }
      }
    LabelToggled(result) ->
      case result {
        Ok(updated) -> #(
          Model(
            ..model,
            detail: option.map(model.detail, fn(d) {
              api.IssueDetail(
                issue: updated,
                linked_merge_requests: d.linked_merge_requests,
              )
            }),
            error: option.None,
          ),
          none(),
        )
        Error(_) -> #(
          Model(..model, error: option.Some("Could not update labels")),
          reload_issue_detail(config, model),
        )
      }
    ToggleAssignee(user_id) ->
      case issue_from_detail(model) {
        option.None -> #(model, none())
        option.Some(issue) -> {
          let ids = selected_assignee_ids(issue)
          let next_ids = case list.contains(ids, user_id) {
            True -> list.filter(ids, fn(id) { id != user_id })
            False -> [user_id, ..ids]
          }
          let optimistic =
            api.Issue(
              ..issue,
              assignees: assignees_for_ids(model.org_members, next_ids),
            )
          #(
            Model(
              ..model,
              detail: option.map(model.detail, fn(d) {
                api.IssueDetail(
                  issue: optimistic,
                  linked_merge_requests: d.linked_merge_requests,
                )
              }),
              error: option.None,
            ),
            patch_issue(
              config,
              model,
              issue,
              selected_label_ids(issue),
              next_ids,
              AssigneeToggled,
            ),
          )
        }
      }
    AssigneeToggled(result) ->
      case result {
        Ok(updated) -> #(
          Model(
            ..model,
            detail: option.map(model.detail, fn(d) {
              api.IssueDetail(
                issue: updated,
                linked_merge_requests: d.linked_merge_requests,
              )
            }),
            error: option.None,
          ),
          none(),
        )
        Error(_) -> #(
          Model(..model, error: option.Some("Could not update assignees")),
          reload_issue_detail(config, model),
        )
      }
    ToggleLabelsMenu -> #(
      Model(
        ..model,
        labels_menu_open: !model.labels_menu_open,
        assignees_menu_open: False,
        milestones_menu_open: False,
        label_filter: "",
      ),
      none(),
    )
    LabelFilterChanged(query) -> #(Model(..model, label_filter: query), none())
    ToggleAssigneesMenu -> #(
      Model(
        ..model,
        assignees_menu_open: !model.assignees_menu_open,
        labels_menu_open: False,
        milestones_menu_open: False,
        assignee_filter: "",
      ),
      none(),
    )
    AssigneeFilterChanged(query) -> #(
      Model(..model, assignee_filter: query),
      none(),
    )
    MilestonesLoaded(Ok(milestones)) -> #(
      Model(..model, repo_milestones: milestones),
      none(),
    )
    MilestonesLoaded(Error(_)) -> #(model, none())
    ToggleMilestonesMenu -> #(
      Model(
        ..model,
        milestones_menu_open: !model.milestones_menu_open,
        labels_menu_open: False,
        assignees_menu_open: False,
        milestone_filter: "",
      ),
      none(),
    )
    MilestoneFilterChanged(query) -> #(
      Model(..model, milestone_filter: query),
      none(),
    )
    SelectMilestone(value) ->
      case issue_from_detail(model) {
        option.None -> #(model, none())
        option.Some(issue) -> {
          let next_milestone = case value {
            "" -> option.None
            id -> option.Some(id)
          }
          let optimistic_milestone = case value {
            "" -> option.None
            id ->
              case
                list.first(list.filter(model.repo_milestones, fn(m) { m.id == id }))
              {
                Ok(m) ->
                  option.Some(api.IssueMilestone(
                    id: m.id,
                    number: m.number,
                    title: m.title,
                  ))
                Error(_) -> option.None
              }
          }
          let optimistic =
            api.Issue(..issue, milestone: optimistic_milestone)
          #(
            Model(
              ..model,
              milestones_menu_open: False,
              milestone_filter: "",
              detail: option.map(model.detail, fn(d) {
                api.IssueDetail(
                  issue: optimistic,
                  linked_merge_requests: d.linked_merge_requests,
                )
              }),
              error: option.None,
            ),
            patch_issue_milestone(config, model, next_milestone, MilestoneToggled),
          )
        }
      }
    MilestoneToggled(result) ->
      case result {
        Ok(updated) -> #(
          Model(
            ..model,
            detail: option.map(model.detail, fn(d) {
              api.IssueDetail(
                issue: updated,
                linked_merge_requests: d.linked_merge_requests,
              )
            }),
            error: option.None,
          ),
          none(),
        )
        Error(_) -> #(
          Model(..model, error: option.Some("Could not update milestone")),
          reload_issue_detail(config, model),
        )
      }
  }
}

fn member_label(member: OrgMember) -> String {
  case member.username {
    option.Some(username) -> "@" <> username
    option.None -> member.display_name
  }
}

pub fn view(model: Model) -> Element(Msg) {
  let error = case model.error {
    option.Some(e) -> components.error_alert(e)
    option.None -> text("")
  }
  case model.detail {
    option.None ->
      div([attr.class(components.page <> " max-w-5xl")], [
        components.breadcrumb_back(
          routes.issue_list_path(model.org_slug, model.repo_name),
          "Issues",
        ),
        error,
        case model.loading {
          True -> components.loading_state()
          False -> components.empty_state("Issue not found")
        },
      ])
    option.Some(detail) -> detail_view(model, detail, error)
  }
}

const action_size = "!h-10 shrink-0"

fn detail_view(
  model: Model,
  detail: IssueDetail,
  error: Element(Msg),
) -> Element(Msg) {
  let issue = detail.issue
  div([attr.class(components.page <> " max-w-5xl")], [
    components.breadcrumb_back(
      routes.issue_list_path(model.org_slug, model.repo_name),
      "Issues",
    ),
    error,
    div([attr.class("mt-4 grid gap-8 lg:grid-cols-[minmax(0,1fr)_14rem]")], [
      div([attr.class("min-w-0")], [
        issue_header(model, issue),
        conversation_timeline(model, issue),
      ]),
      aside(
        [attr.class("space-y-5 lg:sticky lg:top-6 lg:self-start")],
        issue_sidebar(model, issue, detail.linked_merge_requests),
      ),
    ]),
  ])
}

fn issue_header(model: Model, issue: Issue) -> Element(Msg) {
  div([attr.class("mb-6 space-y-3")], [
    case model.editing {
      True -> edit_title_form(model, issue)
      False ->
        h1([attr.class(components.detail_title)], [
          text("#" <> int.to_string(issue.number) <> " " <> issue.title),
        ])
    },
    div([attr.class("detail-header-toolbar")], [
      div([attr.class("detail-header-meta")], [
        issue_state_badge(issue.state),
      ]),
      div([attr.class("mr-detail-actions-wrap")], [
        issue_toolbar(model, issue),
      ]),
    ]),
  ])
}

fn issue_toolbar(model: Model, issue: Issue) -> Element(Msg) {
  case model.editing {
    True -> edit_toolbar(model)
    False -> issue_actions(model, issue)
  }
}

fn edit_toolbar(model: Model) -> Element(Msg) {
  div([attr.class("mr-detail-actions")], [
    button(
      [
        attr.type_("button"),
        attr.class(components.btn_secondary <> " " <> action_size <> " !px-4"),
        attr.disabled(model.saving),
        event.on_click(CancelEdit),
      ],
      [text("Cancel")],
    ),
    button(
      [
        attr.type_("button"),
        attr.class(
          components.btn_primary
          <> " "
          <> action_size
          <> " !border-transparent !bg-gh-accent !px-5 !text-gh-ink hover:!bg-gh-accent-hover",
        ),
        attr.disabled(model.saving),
        event.on_click(SaveEdit),
      ],
      [text("Save")],
    ),
  ])
}

fn issue_actions(_model: Model, issue: Issue) -> Element(Msg) {
  div([attr.class("mr-detail-actions")], [
    case issue.state {
      "open" ->
        button(
          [
            attr.type_("button"),
            attr.class(components.btn_secondary <> " " <> action_size <> " !px-4"),
            event.on_click(CloseIssue),
          ],
          [text("Close")],
        )
      "closed" ->
        button(
          [
            attr.type_("button"),
            attr.class(
              components.btn_primary
              <> " "
              <> action_size
              <> " !border-transparent !bg-gh-accent !px-5 !text-gh-ink hover:!bg-gh-accent-hover",
            ),
            event.on_click(ReopenIssue),
          ],
          [text("Reopen")],
        )
      _ -> text("")
    },
    button(
      [
        attr.type_("button"),
        attr.class(components.btn_secondary <> " " <> action_size <> " !px-4"),
        event.on_click(StartEdit),
      ],
      [text("Edit")],
    ),
  ])
}

fn milestone_options(
  milestones: List(Milestone),
) -> List(labels_ui.MilestoneOption) {
  list.map(milestones, fn(milestone) {
    labels_ui.MilestoneOption(
      id: milestone.id,
      number: milestone.number,
      title: milestone.title,
    )
  })
}

fn selected_milestone_option(
  issue: Issue,
) -> option.Option(labels_ui.MilestoneOption) {
  case issue.milestone {
    option.None -> option.None
    option.Some(milestone) ->
      option.Some(labels_ui.MilestoneOption(
        id: milestone.id,
        number: milestone.number,
        title: milestone.title,
      ))
  }
}

fn org_member_options(
  members: List(OrgMember),
) -> List(labels_ui.AssigneeOption) {
  list.map(members, fn(member) {
    labels_ui.AssigneeOption(
      user_id: member.user_id,
      name: member_label(member),
    )
  })
}

fn issue_sidebar(
  model: Model,
  issue: Issue,
  linked_merge_requests: List(LinkedMergeRequest),
) -> List(Element(Msg)) {
  [
    labels_ui.sidebar_section(
      "Labels",
      labels_ui.searchable_label_field(
        model.repo_labels,
        issue.labels,
        model.labels_menu_open,
        model.label_filter,
        ToggleLabelsMenu,
        LabelFilterChanged,
        ToggleLabel,
      ),
    ),
    labels_ui.sidebar_section(
      "Milestone",
      labels_ui.searchable_milestone_field(
        milestone_options(model.repo_milestones),
        selected_milestone_option(issue),
        model.milestones_menu_open,
        model.milestone_filter,
        ToggleMilestonesMenu,
        MilestoneFilterChanged,
        SelectMilestone,
      ),
    ),
    labels_ui.sidebar_section(
      "Assignees",
      labels_ui.searchable_assignee_field(
        org_member_options(model.org_members),
        selected_assignee_ids(issue),
        model.assignees_menu_open,
        model.assignee_filter,
        model.viewer_user_id,
        ToggleAssigneesMenu,
        AssigneeFilterChanged,
        ToggleAssignee,
      ),
    ),
    labels_ui.sidebar_section(
      "Linked merge requests",
      linked_merge_requests_view(model, linked_merge_requests),
    ),
  ]
}

fn linked_merge_requests_view(
  model: Model,
  linked_merge_requests: List(LinkedMergeRequest),
) -> Element(Msg) {
  case linked_merge_requests {
    [] ->
      p([attr.class("text-xs text-slate-500")], [text("None")])
    mrs ->
      div([attr.class("space-y-2")], list.map(mrs, fn(mr) {
        linked_merge_request_row(model, mr)
      }))
  }
}

fn linked_merge_request_row(
  model: Model,
  mr: LinkedMergeRequest,
) -> Element(Msg) {
  a(
    [
      attr.href(
        routes.mr_detail_path(model.org_slug, model.repo_name, mr.number),
      ),
      attr.class(
        "flex min-w-0 items-center gap-2 no-underline hover:opacity-80",
      ),
    ],
    [
      span([attr.class("comic-issue-num shrink-0")], [
        text("#" <> int.to_string(mr.number)),
      ]),
      span(
        [attr.class("min-w-0 flex-1 truncate text-sm font-semibold text-gh-ink")],
        [text(mr.title)],
      ),
      linked_mr_state_badge(mr),
    ],
  )
}

fn linked_mr_state_badge(mr: LinkedMergeRequest) -> Element(Msg) {
  let badges = case mr.is_draft {
    True -> [draft_badge(), mr_state_badge(mr.state)]
    False -> [mr_state_badge(mr.state)]
  }
  div([attr.class("flex shrink-0 flex-wrap items-center gap-1")], badges)
}

fn draft_badge() -> Element(Msg) {
  span([attr.class("comic-state-badge comic-state-draft")], [text("Draft")])
}

fn mr_state_badge(state: String) -> Element(Msg) {
  let state_class = case state {
    "open" -> "comic-state-badge comic-state-open"
    "merged" -> "comic-state-badge comic-state-merged"
    "closed" -> "comic-state-badge comic-state-closed"
    _ -> "comic-state-badge comic-state-closed"
  }
  span([attr.class(state_class)], [text(state)])
}

fn edit_title_form(model: Model, issue: Issue) -> Element(Msg) {
  div([attr.class("flex min-w-0 flex-wrap items-center gap-2")], [
    span([attr.class("comic-issue-num !text-2xl")], [
      text("#" <> int.to_string(issue.number)),
    ]),
    input([
      attr.class(
        components.input
        <> " !h-auto min-w-0 flex-1 !py-1 text-2xl font-bold leading-tight text-gh-ink",
      ),
      attr.value(model.edit_title),
      attr.autofocus(True),
      attr.disabled(model.saving),
      event.on_input(EditTitleChanged),
    ]),
  ])
}

fn description_edit_textarea(model: Model) -> Element(Msg) {
  textarea(
    [
      attr.class(components.textarea <> " min-h-32 text-sm"),
      attr.disabled(model.saving),
      event.on_input(EditDescriptionChanged),
    ],
    model.edit_description,
  )
}

fn issue_state_badge(state: String) -> Element(Msg) {
  let state_class = case state {
    "open" -> "comic-state-badge comic-state-open"
    "closed" -> "comic-state-badge comic-state-closed"
    _ -> "comic-state-badge comic-state-closed"
  }
  span([attr.class(state_class)], [text(state)])
}

fn conversation_timeline(model: Model, issue: Issue) -> Element(Msg) {
  let comment_count = list.length(model.comments)
  let items =
    list.flatten([
      [opening_post(model, issue, comment_count > 0)],
      list.index_map(model.comments, fn(c, index) {
        comment_item(model, c, index < comment_count - 1)
      }),
      [comment_form(model)],
    ])
  ul([attr.class(timeline_list)], items)
}

fn opening_post(model: Model, issue: Issue, has_more: Bool) -> Element(Msg) {
  let author = api.issue_author_label(issue)
  let body = case model.editing {
    True -> description_edit_textarea(model)
    False -> issue_body(issue.description)
  }
  timeline_event(
    initials: author_initials(author),
    header: event_header_text(author, "opened this issue", issue.created_at),
    body:,
    show_line: has_more,
  )
}

fn issue_body(description: option.Option(String)) -> Element(Msg) {
  case description {
    option.Some(d) ->
      unsafe_raw_html(
        "",
        "div",
        [attr.class("markdown-body text-sm")],
        markdown_body(d, []),
      )
    option.None ->
      p([attr.class("text-sm italic text-gh-muted")], [
        text("No description provided."),
      ])
  }
}

fn viewer_is_owner(model: Model) -> Bool {
  case model.viewer_user_id {
    option.None -> False
    option.Some(viewer) ->
      list.any(model.org_members, fn(m) {
        m.user_id == viewer && m.role == "owner"
      })
  }
}

fn can_edit_comment(model: Model, comment: IssueComment) -> Bool {
  case model.viewer_user_id {
    option.Some(id) if id == comment.author_user_id -> True
    _ -> False
  }
}

fn can_delete_comment(model: Model, comment: IssueComment) -> Bool {
  case model.viewer_user_id {
    option.Some(id) if id == comment.author_user_id -> True
    _ -> viewer_is_owner(model)
  }
}

fn comment_item(
  model: Model,
  c: IssueComment,
  show_line: Bool,
) -> Element(Msg) {
  let author = api.issue_comment_author_label(c)
  let editing = model.editing_comment_id == option.Some(c.id)
  let header = case api.comment_is_edited(c.created_at, c.updated_at) {
    True -> event_header_text(author, "commented (edited)", c.created_at)
    False -> event_header_text(author, "commented", c.created_at)
  }
  let actions = case can_edit_comment(model, c), can_delete_comment(model, c) {
    False, False -> text("")
    can_edit, can_delete ->
      div([attr.class("flex shrink-0 gap-2")], [
        case can_edit {
          True ->
            button(
              [
                attr.type_("button"),
                attr.class("text-xs font-medium text-gh-accent hover:underline"),
                event.on_click(StartEditComment(c.id, c.body)),
              ],
              [text("Edit")],
            )
          False -> text("")
        },
        case can_delete {
          True ->
            button(
              [
                attr.type_("button"),
                attr.class("text-xs font-medium text-red-600 hover:underline"),
                event.on_click(DeleteComment(c.id)),
              ],
              [text("Delete")],
            )
          False -> text("")
        },
      ])
  }
  let body = case editing {
    True ->
      form([event.on_submit(fn(_) { SaveComment }), attr.class("space-y-2")], [
        textarea(
          [
            attr.class(components.textarea <> " !min-h-[5rem]"),
            event.on_input(EditCommentBodyChanged),
          ],
          model.editing_comment_body,
        ),
        div([attr.class("flex justify-end gap-2")], [
          button(
            [
              attr.type_("button"),
              attr.class(components.btn_secondary),
              event.on_click(CancelEditComment),
            ],
            [text("Cancel")],
          ),
          button([attr.type_("submit"), attr.class(components.btn_primary)], [
            text("Save"),
          ]),
        ]),
      ])
    False ->
      unsafe_raw_html(
        "",
        "div",
        [attr.class("markdown-body text-sm")],
        markdown_body(c.body, c.mentioned_usernames),
      )
  }
  timeline_event_with_actions(
    initials: author_initials(author),
    header:,
    actions:,
    body:,
    show_line:,
  )
}

fn timeline_event_with_actions(
  initials initials: String,
  header header: Element(Msg),
  actions actions: Element(Msg),
  body body: Element(Msg),
  show_line show_line: Bool,
) -> Element(Msg) {
  let line = case show_line {
    True -> span([attr.class(timeline_line)], [])
    False -> text("")
  }
  li([attr.class(timeline_item)], [
    line,
    span([attr.class(avatar_class)], [text(initials)]),
    div([attr.class(event_card)], [
      div(
        [attr.class(event_header <> " flex items-start justify-between gap-3")],
        [
          header,
          actions,
        ],
      ),
      div([attr.class(event_body)], [body]),
    ]),
  ])
}

fn timeline_event(
  initials initials: String,
  header header: Element(Msg),
  body body: Element(Msg),
  show_line show_line: Bool,
) -> Element(Msg) {
  timeline_event_with_actions(
    initials:,
    header:,
    actions: text(""),
    body:,
    show_line:,
  )
}

fn event_header_text(
  author: String,
  action: String,
  timestamp: String,
) -> Element(Msg) {
  span([], [
    span([attr.class("font-semibold text-gh-ink")], [text(author)]),
    text(" " <> action <> " · " <> time_format.format_timestamp(timestamp)),
  ])
}

fn comment_form(model: Model) -> Element(Msg) {
  li([attr.class(timeline_item <> " pt-1")], [
    span([attr.class(avatar_class <> " opacity-60")], [text("?")]),
    div([attr.class("min-w-0 flex-1")], [
      form(
        [
          event.on_submit(fn(_) { SubmitComment }),
          attr.class(
            "overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm",
          ),
        ],
        [
          textarea(
            [
              attr.class(
                "block w-full resize-y border-0 px-4 py-3 text-sm text-gh-ink outline-none focus:ring-0",
              ),
              attr.placeholder("Leave a comment…"),
              attr.value(model.comment_body),
              event.on_input(CommentBodyChanged),
            ],
            "",
          ),
          div(
            [
              attr.class(
                "flex items-center justify-end border-t border-slate-200 bg-slate-50 px-4 py-2",
              ),
            ],
            [
              button(
                [attr.type_("submit"), attr.class(components.btn_primary)],
                [text("Comment")],
              ),
            ],
          ),
        ],
      ),
    ]),
  ])
}

fn author_initials(author: String) -> String {
  let parts =
    author
    |> string.split(on: " ")
    |> list.filter(fn(s) { string.trim(s) != "" })
  case parts {
    [] -> "?"
    [only] -> string.uppercase(string.slice(only, 0, 1))
    [first, second, ..] ->
      string.uppercase(string.slice(first, 0, 1))
      <> string.uppercase(string.slice(second, 0, 1))
  }
}

fn markdown_body(content: String, mentioned_usernames: List(String)) -> String {
  content
  |> markdown.to_html
  |> mentions.highlight(mentioned_usernames)
}
