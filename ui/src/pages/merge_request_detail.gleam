import ci/log as ci_log
import ci/pipeline_stream
import ci/status as ci_status
import components
import config.{type Config}
import content/issue_refs
import content/markdown
import content/mentions
import diff/conflict
import diff/mr_line as mr_diff_line
import diff/view as diff_view
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/order
import gleam/string
import gleam/uri
import http/api.{
  type ConflictFile, type DiffFile, type Label, type LinkedIssue, type MergeCheck,
  type MergeRequest, type MergeRequestDetail, type MrComment, type MrCommit,
  type MrReview, type OrgMember, type Pipeline,
}
import http/lustre_http
import labels_ui
import lustre/attribute as attr
import lustre/effect.{type Effect, batch, from, none}
import lustre/element.{type Element, memo, ref, text, unsafe_raw_html}
import lustre/element/html.{
  a, aside, button, div, form, h1, input, label, li, ol, option, p, select, span,
  textarea, ul,
}
import lustre/event
import modem
import routes.{type MrView}
import util/clipboard
import util/time_format

pub type Tab {
  Conversation
  Checks
  Commits
  Changes
}

pub type Model {
  Model(
    org_slug: String,
    repo_name: String,
    number: Int,
    tab: Tab,
    detail: option.Option(MergeRequestDetail),
    comments: List(MrComment),
    commits: List(MrCommit),
    diff_files: List(DiffFile),
    selected_file: option.Option(String),
    patch: option.Option(String),
    conflict_file: option.Option(ConflictFile),
    comment_body: String,
    comment_file: option.Option(String),
    comment_line: option.Option(Int),
    show_merge_confirm: Bool,
    merge_method: api.MergeMethod,
    delete_source_branch: Bool,
    updating_branch: Bool,
    loading: Bool,
    commits_loading: Bool,
    copied_commit_sha: option.Option(String),
    loading_patch: Bool,
    error: option.Option(String),
    pipeline_stream_stop: option.Option(fn() -> Nil),
    prior_pipelines: List(Pipeline),
    expanded_prior_run_ids: List(String),
    show_commented_files_only: Bool,
    pending_diff_line: option.Option(#(String, Int)),
    scroll_to_line: option.Option(Int),
    repo_labels: List(Label),
    saving_labels: Bool,
    toggling_draft: Bool,
    labels_menu_open: Bool,
    label_filter: String,
    assignees_menu_open: Bool,
    assignee_filter: String,
    saving_assignees: Bool,
    reviewers_menu_open: Bool,
    reviewer_filter: String,
    saving_reviewers: Bool,
    editing: Bool,
    editing_description: Bool,
    edit_title: String,
    edit_description: String,
    edit_description_seed: Int,
    saving: Bool,
    viewer_user_id: option.Option(String),
    org_members: List(OrgMember),
    editing_comment_id: option.Option(String),
    editing_comment_body: String,
    description_menu_open: Bool,
    submitting_review: Bool,
  )
}

pub type Msg {
  DetailLoaded(Result(MergeRequestDetail, lustre_http.HttpError))
  CommentsLoaded(Result(List(MrComment), lustre_http.HttpError))
  MembersLoaded(Result(List(OrgMember), lustre_http.HttpError))
  CommitsLoaded(Result(List(MrCommit), lustre_http.HttpError))
  DiffLoaded(Result(List(DiffFile), lustre_http.HttpError))
  PatchLoaded(Result(String, lustre_http.HttpError))
  ConflictLoaded(Result(ConflictFile, lustre_http.HttpError))
  TabChanged(Tab)
  CommentBodyChanged(String)
  CommentOnLine(String, Int)
  CancelInlineComment
  GoToLineComment(String, Int)
  GoToConflictFile(String)
  SubmitComment
  CommentPosted(Result(MrComment, lustre_http.HttpError))
  StartEditComment(String, String)
  CancelEditComment
  EditCommentBodyChanged(String)
  SaveComment
  CommentUpdated(Result(MrComment, lustre_http.HttpError))
  DeleteComment(String)
  CommentDeleted(Result(Nil, lustre_http.HttpError))
  SelectFile(String)
  CopyCommitSha(String)
  MergeMethodChanged(api.MergeMethod)
  DeleteSourceBranchChanged(Bool)
  ShowMergeConfirm
  CancelMergeConfirm
  Merge
  Merged(Result(MergeRequest, lustre_http.HttpError))
  CloseMr
  Closed(Result(MergeRequest, lustre_http.HttpError))
  UpdateBranch
  BranchUpdated(Result(MergeRequestDetail, lustre_http.HttpError))
  RerunChecks
  ChecksRerun(Result(api.Pipeline, lustre_http.HttpError))
  PipelineStreamStarted(fn() -> Nil)
  PipelineStreamUpdate(String)
  PipelineStreamError
  PriorPipelinesLoaded(Result(List(Pipeline), lustre_http.HttpError))
  TogglePriorPipeline(String)
  CommentedFilesFilterChanged(Bool)
  LabelsLoaded(Result(List(Label), lustre_http.HttpError))
  ToggleMrLabel(String)
  MrLabelsUpdated(Result(MergeRequest, lustre_http.HttpError))
  ToggleDraft
  MrDraftUpdated(Result(MergeRequest, lustre_http.HttpError))
  ToggleLabelsMenu
  LabelFilterChanged(String)
  ToggleAssignee(String)
  AssigneeToggled(Result(MergeRequest, lustre_http.HttpError))
  ToggleAssigneesMenu
  AssigneeFilterChanged(String)
  ToggleReviewer(String)
  ReviewerToggled(Result(MergeRequest, lustre_http.HttpError))
  ToggleReviewersMenu
  ReviewerFilterChanged(String)
  StartEdit
  StartEditDescription
  ToggleDescriptionMenu
  SubmitReview(String)
  ReviewSubmitted(Result(MrReview, lustre_http.HttpError))
  CancelEdit
  EditTitleChanged(String)
  EditDescriptionChanged(String)
  TitleKeyPressed(String)
  DescriptionKeyPressed(String)
  SaveEdit
  Saved(Result(MergeRequest, lustre_http.HttpError))
}

const timeline_list = "space-y-4"

const timeline_item = "relative flex gap-3"

const timeline_line = "comic-timeline-line"

const avatar_class = "comic-timeline-avatar"

const event_card = "comic-event-card"

const event_header = "comic-event-header"

const event_body = "comic-event-body"

fn view_to_tab(view: MrView) -> Tab {
  case view {
    routes.Conversation -> Conversation
    routes.Checks -> Checks
    routes.Commits -> Commits
    routes.Changes(_, _) -> Changes
  }
}

fn tab_to_mr_view(tab: Tab) -> MrView {
  case tab {
    Conversation -> routes.Conversation
    Checks -> routes.Checks
    Commits -> routes.Commits
    Changes -> routes.Changes(option.None, option.None)
  }
}

fn pending_line_from_view(view: MrView) -> option.Option(#(String, Int)) {
  case view {
    routes.Changes(option.Some(file), option.Some(line)) ->
      option.Some(#(file, line))
    _ -> option.None
  }
}

fn selected_file_from_view(view: MrView) -> option.Option(String) {
  case view {
    routes.Changes(option.Some(file), _) -> option.Some(file)
    _ -> option.None
  }
}

pub fn init(
  org_slug: String,
  repo_name: String,
  number: Int,
  view: MrView,
  viewer_user_id: option.Option(String),
) -> Model {
  let tab = view_to_tab(view)
  let pending = pending_line_from_view(view)
  let selected = selected_file_from_view(view)
  let scroll_to_line = case pending {
    option.Some(#(_, line)) -> option.Some(line)
    option.None -> option.None
  }
  Model(
    org_slug:,
    repo_name:,
    number:,
    tab:,
    detail: option.None,
    comments: [],
    commits: [],
    diff_files: [],
    selected_file: selected,
    patch: option.None,
    conflict_file: option.None,
    comment_body: "",
    comment_file: option.None,
    comment_line: option.None,
    show_merge_confirm: False,
    merge_method: api.MergeCommit,
    delete_source_branch: True,
    updating_branch: False,
    loading: True,
    commits_loading: False,
    copied_commit_sha: option.None,
    loading_patch: False,
    error: option.None,
    pipeline_stream_stop: option.None,
    prior_pipelines: [],
    expanded_prior_run_ids: [],
    show_commented_files_only: False,
    pending_diff_line: pending,
    scroll_to_line:,
    repo_labels: [],
    saving_labels: False,
    toggling_draft: False,
    labels_menu_open: False,
    label_filter: "",
    assignees_menu_open: False,
    assignee_filter: "",
    saving_assignees: False,
    reviewers_menu_open: False,
    reviewer_filter: "",
    saving_reviewers: False,
    editing: False,
    editing_description: False,
    edit_title: "",
    edit_description: "",
    edit_description_seed: 0,
    saving: False,
    viewer_user_id:,
    org_members: [],
    editing_comment_id: option.None,
    editing_comment_body: "",
    description_menu_open: False,
    submitting_review: False,
  )
}

pub fn same_mr(model: Model, org: String, repo: String, number: Int) -> Bool {
  model.org_slug == org && model.repo_name == repo && model.number == number
}

/// Update tab/file/line from the URL without resetting loaded MR data.
pub fn sync_view(model: Model, view: MrView) -> Model {
  let tab = view_to_tab(view)
  let pending = pending_line_from_view(view)
  let selected = selected_file_from_view(view)
  let scroll_to_line = case pending {
    option.Some(#(_, line)) -> option.Some(line)
    option.None -> option.None
  }
  let file_changed = selected != model.selected_file

  Model(
    ..model,
    tab:,
    pending_diff_line: pending,
    scroll_to_line:,
    selected_file: selected,
    patch: case tab, file_changed {
      Changes, True -> option.None
      _, _ -> model.patch
    },
    conflict_file: case tab, file_changed {
      Changes, True -> option.None
      _, _ -> model.conflict_file
    },
    loading_patch: case tab, file_changed {
      Changes, True -> True
      _, _ -> False
    },
  )
}

pub fn sync_view_effect(
  before: Model,
  after: Model,
  config: Config,
) -> Effect(Msg) {
  let tab_changed = before.tab != after.tab
  let file_changed = before.selected_file != after.selected_file
  let line_changed = before.pending_diff_line != after.pending_diff_line

  case tab_changed {
    True -> tab_load(config, after, after.tab)
    False ->
      case after.tab {
        Changes ->
          case file_changed, after.selected_file {
            True, option.Some(path) -> file_load_effect(config, after, path)
            False, _
              if line_changed && after.pending_diff_line != option.None
            -> apply_pending_diff_effect(config, after)
            _, _ -> none()
          }
        _ -> none()
      }
  }
}

fn api_base(config: Config, model: Model) -> String {
  config.api_url
  <> "/api/orgs/"
  <> model.org_slug
  <> "/repos/"
  <> model.repo_name
  <> "/merge-requests/"
  <> int.to_string(model.number)
}

fn load_prior_pipelines(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model) <> "/pipelines",
    lustre_http.expect_json(api.pipelines_decoder(), PriorPipelinesLoaded),
  )
}

fn prior_runs(
  current: option.Option(Pipeline),
  all: List(Pipeline),
) -> List(Pipeline) {
  case current {
    option.None -> list.drop(all, 1)
    option.Some(latest) -> list.filter(all, fn(run) { run.id != latest.id })
  }
}

fn pipeline_is_newer(a: Pipeline, b: Pipeline) -> Bool {
  case a.created_at, b.created_at {
    option.Some(at_a), option.Some(at_b) ->
      string.compare(at_a, at_b) == order.Gt
    option.Some(_), option.None -> True
    option.None, option.Some(_) -> False
    option.None, option.None ->
      pipeline_is_in_progress(option.Some(a))
      && !pipeline_is_in_progress(option.Some(b))
  }
}

fn optional_first(items: List(Pipeline)) -> option.Option(Pipeline) {
  case list.first(items) {
    Ok(item) -> option.Some(item)
    Error(_) -> option.None
  }
}

fn reconcile_detail_pipeline(
  detail: option.Option(MergeRequestDetail),
  pipelines: List(Pipeline),
) -> option.Option(MergeRequestDetail) {
  option.map(detail, fn(d) {
    api.MergeRequestDetail(
      ..d,
      pipeline: pick_current_pipeline(d.pipeline, optional_first(pipelines)),
    )
  })
}

fn pick_current_pipeline(
  from_detail: option.Option(Pipeline),
  from_list: option.Option(Pipeline),
) -> option.Option(Pipeline) {
  case from_detail, from_list {
    option.None, option.None -> option.None
    option.Some(d), option.None -> option.Some(d)
    option.None, option.Some(l) -> option.Some(l)
    option.Some(d), option.Some(l) ->
      case d.id == l.id {
        True -> option.Some(d)
        False ->
          case pipeline_is_newer(d, l) {
            True -> option.Some(d)
            False -> option.Some(l)
          }
      }
  }
}

fn current_pipeline_run(model: Model) -> option.Option(Pipeline) {
  pick_current_pipeline(
    detail_pipeline(model),
    optional_first(model.prior_pipelines),
  )
}

fn upsert_pipeline(runs: List(Pipeline), pipeline: Pipeline) -> List(Pipeline) {
  let rest = list.filter(runs, fn(r) { r.id != pipeline.id })
  sort_pipelines_by_created([pipeline, ..rest])
}

fn sort_pipelines_by_created(runs: List(Pipeline)) -> List(Pipeline) {
  list.sort(runs, fn(a, b) {
    case pipeline_is_newer(a, b) {
      True -> order.Lt
      False -> order.Gt
    }
  })
}

fn trigger_label(trigger: String) -> String {
  case trigger {
    "push" -> "push"
    "manual" -> "manual re-run"
    "mr_open" -> "MR opened"
    _ -> trigger
  }
}

fn is_prior_run_expanded(model: Model, run_id: String) -> Bool {
  list.contains(model.expanded_prior_run_ids, run_id)
}

fn toggle_prior_run_expanded(
  ids: List(String),
  run_id: String,
) -> List(String) {
  case list.contains(ids, run_id) {
    True -> list.filter(ids, fn(id) { id != run_id })
    False -> [run_id, ..ids]
  }
}

fn load_detail(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model),
    lustre_http.expect_json(api.merge_request_detail_decoder(), DetailLoaded),
  )
}

fn pipeline_stream_url(config: Config, model: Model) -> String {
  config.api_url
  <> "/api/orgs/"
  <> model.org_slug
  <> "/repos/"
  <> model.repo_name
  <> "/merge-requests/"
  <> int.to_string(model.number)
  <> "/pipeline/stream"
}

fn stop_pipeline_stream(model: Model) -> Model {
  case model.pipeline_stream_stop {
    option.Some(stop) -> {
      stop()
      Model(..model, pipeline_stream_stop: option.None)
    }
    option.None -> model
  }
}

fn detail_pipeline(model: Model) -> option.Option(Pipeline) {
  case model.detail {
    option.Some(d) -> d.pipeline
    option.None -> option.None
  }
}

fn pipeline_stream_effect(model: Model, config: Config) -> Effect(Msg) {
  case model.tab, model.detail, config.token, model.pipeline_stream_stop {
    Checks, option.Some(_), option.Some(token), option.None ->
      from(fn(dispatch) {
        let abort =
          pipeline_stream.subscribe(
            pipeline_stream_url(config, model),
            token,
            fn(json) { dispatch(PipelineStreamUpdate(json)) },
            fn() { dispatch(PipelineStreamError) },
          )
        dispatch(PipelineStreamStarted(abort))
      })
    _, _, _, _ -> none()
  }
}

fn apply_pipeline_update(model: Model, json: String) -> Model {
  case json.parse(json, api.pipeline_decoder()) {
    Ok(pipeline) ->
      Model(
        ..model,
        detail: option.map(model.detail, fn(d) {
          api.MergeRequestDetail(..d, pipeline: option.Some(pipeline))
        }),
        prior_pipelines: upsert_pipeline(model.prior_pipelines, pipeline),
      )
    Error(_) -> model
  }
}

fn pipeline_is_in_progress(pipeline: option.Option(Pipeline)) -> Bool {
  case pipeline {
    option.Some(run) -> run.state == "running" || run.state == "queued"
    option.None -> False
  }
}

fn repo_labels_path(config: Config, model: Model) -> String {
  config.api_url
  <> "/api/orgs/"
  <> model.org_slug
  <> "/repos/"
  <> model.repo_name
  <> "/labels"
}

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  let base = api_base(config, model)
  let pending = apply_pending_on_init(config, model)
  batch([
    pending,
    load_detail(config, model),
    lustre_http.get(
      config,
      repo_labels_path(config, model),
      lustre_http.expect_json(api.labels_decoder(), LabelsLoaded),
    ),
    lustre_http.get(
      config,
      base <> "/comments",
      lustre_http.expect_json(api.mr_comments_decoder(), CommentsLoaded),
    ),
    lustre_http.get(
      config,
      config.api_url <> "/api/orgs/" <> model.org_slug <> "/members",
      lustre_http.expect_json(api.members_decoder(), MembersLoaded),
    ),
    tab_load(config, model, model.tab),
  ])
}

fn tab_load(config: Config, model: Model, tab: Tab) -> Effect(Msg) {
  let base = api_base(config, model)
  case tab {
    Conversation -> none()
    Checks -> load_prior_pipelines(config, model)
    Commits ->
      case model.commits {
        [] ->
          lustre_http.get(
            config,
            base <> "/commits",
            lustre_http.expect_json(api.mr_commits_decoder(), CommitsLoaded),
          )
        _ -> none()
      }
    Changes -> {
      let load_diff = case model.diff_files {
        [] ->
          lustre_http.get(
            config,
            base <> "/diff",
            lustre_http.expect_json(api.diff_files_decoder(), DiffLoaded),
          )
        _ -> none()
      }
      let load_comments = case model.comments {
        [] ->
          lustre_http.get(
            config,
            base <> "/comments",
            lustre_http.expect_json(api.mr_comments_decoder(), CommentsLoaded),
          )
        _ -> none()
      }
      batch([load_diff, load_comments])
    }
  }
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    DetailLoaded(Ok(d)) -> {
      let refresh_only = model.detail != option.None && model.tab == Checks
      let model = case refresh_only {
        True ->
          Model(
            ..model,
            detail: option.Some(d),
            loading: False,
            error: option.None,
          )
        False ->
          stop_pipeline_stream(model)
          |> fn(m) {
            Model(
              ..m,
              detail: option.Some(d),
              loading: False,
              error: option.None,
            )
          }
      }
      let stream = case refresh_only, model.tab {
        False, Checks -> pipeline_stream_effect(model, config)
        _, _ -> none()
      }
      let prior = case model.tab {
        Checks -> load_prior_pipelines(config, model)
        _ -> none()
      }
      let conflict_reload = case model.tab, model.selected_file, refresh_only {
        Changes, option.Some(path), False ->
          case
            !d.merge_check.mergeable
            && list.contains(d.merge_check.conflict_paths, path)
          {
            True -> file_load_effect(config, model, path)
            False -> none()
          }
        _, _, _ -> none()
      }
      #(model, batch([stream, prior, conflict_reload]))
    }
    DetailLoaded(Error(_)) -> #(
      Model(
        ..model,
        loading: False,
        error: option.Some("Failed to load merge request"),
      ),
      none(),
    )
    CommentsLoaded(Ok(comments)) -> #(Model(..model, comments:), none())
    CommentsLoaded(Error(_)) -> #(model, none())
    MembersLoaded(Ok(members)) -> #(
      Model(..model, org_members: members),
      none(),
    )
    MembersLoaded(Error(_)) -> #(model, none())
    CommitsLoaded(Ok(commits)) -> #(
      Model(..model, commits:, commits_loading: False),
      none(),
    )
    CommitsLoaded(Error(_)) -> #(
      Model(
        ..model,
        commits_loading: False,
        error: option.Some("Failed to load commits"),
      ),
      none(),
    )
    DiffLoaded(Ok(files)) -> {
      let target = selected_change_file(model, files)
      #(
        Model(
          ..model,
          diff_files: files,
          selected_file: target,
          patch: option.None,
          conflict_file: option.None,
          loading_patch: target != option.None,
        ),
        case target {
          option.Some(path) -> file_load_effect(config, model, path)
          option.None -> none()
        },
      )
    }
    DiffLoaded(Error(_)) -> #(
      Model(..model, error: option.Some("Failed to load diff")),
      none(),
    )
    PatchLoaded(Ok(patch)) -> #(
      Model(
        ..model,
        patch: option.Some(patch),
        conflict_file: option.None,
        loading_patch: False,
      ),
      none(),
    )
    ConflictLoaded(Ok(file)) -> #(
      Model(
        ..model,
        patch: option.None,
        conflict_file: option.Some(file),
        loading_patch: False,
      ),
      none(),
    )
    ConflictLoaded(Error(_)) -> #(
      Model(
        ..model,
        conflict_file: option.None,
        loading_patch: False,
        error: option.Some("Failed to load conflict"),
      ),
      none(),
    )
    PatchLoaded(Error(_)) -> #(
      Model(
        ..model,
        loading_patch: False,
        error: option.Some("Failed to load patch"),
      ),
      none(),
    )
    TabChanged(tab) -> #(
      model,
      modem.replace(
        routes.mr_detail_tab_path(
          model.org_slug,
          model.repo_name,
          model.number,
          tab_to_mr_view(tab),
        ),
        option.None,
        option.None,
      ),
    )
    CopyCommitSha(sha) -> {
      let _ = clipboard.copy(sha)
      #(Model(..model, copied_commit_sha: option.Some(sha)), none())
    }
    CommentBodyChanged(v) -> #(Model(..model, comment_body: v), none())
    CommentOnLine(file, line) -> #(
      Model(
        ..model,
        comment_file: option.Some(file),
        comment_line: option.Some(line),
        comment_body: "",
      ),
      none(),
    )
    CancelInlineComment -> #(
      Model(
        ..model,
        comment_file: option.None,
        comment_line: option.None,
        comment_body: "",
      ),
      none(),
    )
    GoToLineComment(file, line) -> #(
      Model(
        ..model,
        comment_file: option.Some(file),
        comment_line: option.Some(line),
      ),
      modem.replace(
        routes.mr_changes_line_path(
          model.org_slug,
          model.repo_name,
          model.number,
          file,
          line,
        ),
        option.None,
        option.None,
      ),
    )
    GoToConflictFile(path) -> #(
      model,
      modem.replace(
        routes.mr_detail_tab_path(
          model.org_slug,
          model.repo_name,
          model.number,
          routes.Changes(option.Some(path), option.None),
        ),
        option.None,
        option.None,
      ),
    )
    SubmitComment -> #(
      model,
      lustre_http.post(
        config,
        api_base(config, model) <> "/comments",
        api.create_mr_comment_body(
          model.comment_body,
          model.comment_file,
          model.comment_line,
        ),
        lustre_http.expect_json(api.mr_comment_decoder(), CommentPosted),
      ),
    )
    CommentPosted(Ok(_)) -> #(
      Model(
        ..model,
        comment_body: "",
        comment_file: option.None,
        comment_line: option.None,
      ),
      lustre_http.get(
        config,
        api_base(config, model) <> "/comments",
        lustre_http.expect_json(api.mr_comments_decoder(), CommentsLoaded),
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
            lustre_http.expect_json(api.mr_comment_decoder(), CommentUpdated),
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
        lustre_http.expect_json(api.mr_comments_decoder(), CommentsLoaded),
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
        lustre_http.expect_json(api.mr_comments_decoder(), CommentsLoaded),
      ),
    )
    CommentDeleted(Error(_)) -> #(
      Model(..model, error: option.Some("Could not delete comment")),
      none(),
    )
    SelectFile(path) -> #(
      model,
      modem.replace(
        routes.mr_detail_tab_path(
          model.org_slug,
          model.repo_name,
          model.number,
          routes.Changes(option.Some(path), option.None),
        ),
        option.None,
        option.None,
      ),
    )
    CommentedFilesFilterChanged(checked) -> {
      let files_for_selection = case checked {
        True -> files_with_comments(model, model.diff_files)
        False -> model.diff_files
      }
      let #(selected, reload) =
        ensure_selected_among_files(model, files_for_selection)
      let clear_line_url = model.pending_diff_line != option.None
      #(
        Model(
          ..model,
          show_commented_files_only: checked,
          selected_file: selected,
          patch: case reload {
            True -> option.None
            False -> model.patch
          },
          conflict_file: case reload {
            True -> option.None
            False -> model.conflict_file
          },
          loading_patch: reload,
        ),
        case reload, selected, clear_line_url {
          True, option.Some(path), True ->
            modem.replace(
              routes.mr_detail_tab_path(
                model.org_slug,
                model.repo_name,
                model.number,
                routes.Changes(option.Some(path), option.None),
              ),
              option.None,
              option.None,
            )
          True, option.Some(path), False ->
            file_load_effect(config, model, path)
          _, _, _ -> none()
        },
      )
    }
    MergeMethodChanged(method) -> #(
      Model(..model, merge_method: method),
      none(),
    )
    DeleteSourceBranchChanged(delete) -> #(
      Model(..model, delete_source_branch: delete),
      none(),
    )
    ShowMergeConfirm -> #(Model(..model, show_merge_confirm: True), none())
    CancelMergeConfirm -> #(Model(..model, show_merge_confirm: False), none())
    Merge -> #(
      Model(..model, show_merge_confirm: False),
      lustre_http.post(
        config,
        api_base(config, model) <> "/merge",
        api.merge_request_merge_body(
          model.merge_method,
          model.delete_source_branch,
        ),
        lustre_http.expect_json(api.merge_request_decoder(), Merged),
      ),
    )
    Merged(Ok(mr)) -> #(
      Model(
        ..model,
        detail: option.map(model.detail, fn(d) {
          api.MergeRequestDetail(..d, merge_request: mr)
        }),
        error: option.None,
      ),
      lustre_http.get(
        config,
        api_base(config, model),
        lustre_http.expect_json(
          api.merge_request_detail_decoder(),
          DetailLoaded,
        ),
      ),
    )
    Merged(Error(lustre_http.OtherError(409, _))) -> #(
      Model(
        ..model,
        error: option.Some(
          "Merge failed: conflicts. Resolve on the branch and try again.",
        ),
      ),
      none(),
    )
    Merged(Error(_)) -> #(
      Model(..model, error: option.Some("Merge failed")),
      none(),
    )
    CloseMr -> #(
      model,
      lustre_http.post(
        config,
        api_base(config, model) <> "/close",
        json.object([]),
        lustre_http.expect_json(api.merge_request_decoder(), Closed),
      ),
    )
    Closed(Ok(mr)) -> #(
      Model(
        ..model,
        detail: option.map(model.detail, fn(d) {
          api.MergeRequestDetail(..d, merge_request: mr)
        }),
      ),
      none(),
    )
    Closed(Error(_)) -> #(
      Model(..model, error: option.Some("Could not close merge request")),
      none(),
    )
    UpdateBranch -> #(
      Model(..model, updating_branch: True, error: option.None),
      lustre_http.post(
        config,
        api_base(config, model) <> "/update-branch",
        json.object([]),
        lustre_http.expect_json(
          api.merge_request_detail_decoder(),
          BranchUpdated,
        ),
      ),
    )
    BranchUpdated(Ok(detail)) -> #(
      Model(
        ..model,
        detail: option.Some(detail),
        updating_branch: False,
        commits: [],
        commits_loading: model.commits != [],
        diff_files: [],
        patch: option.None,
        selected_file: option.None,
        error: option.None,
      ),
      batch([
        case model.commits != [] {
          True ->
            lustre_http.get(
              config,
              api_base(config, model) <> "/commits",
              lustre_http.expect_json(api.mr_commits_decoder(), CommitsLoaded),
            )
          False -> none()
        },
        case model.diff_files != [] {
          True ->
            lustre_http.get(
              config,
              api_base(config, model) <> "/diff",
              lustre_http.expect_json(api.diff_files_decoder(), DiffLoaded),
            )
          False -> none()
        },
      ]),
    )
    BranchUpdated(Error(lustre_http.OtherError(409, _))) -> #(
      Model(
        ..model,
        updating_branch: False,
        error: option.Some(
          "Could not update branch: merge conflicts. Resolve on the branch and try again.",
        ),
      ),
      none(),
    )
    BranchUpdated(Error(_)) -> #(
      Model(
        ..model,
        updating_branch: False,
        error: option.Some("Could not update branch"),
      ),
      none(),
    )
    RerunChecks -> #(
      model,
      lustre_http.post(
        config,
        api_base(config, model) <> "/rerun-checks",
        json.object([]),
        lustre_http.expect_json(api.pipeline_decoder(), ChecksRerun),
      ),
    )
    ChecksRerun(Ok(pipeline)) -> {
      let updated =
        stop_pipeline_stream(model)
        |> fn(m) {
          Model(
            ..m,
            detail: option.map(m.detail, fn(d) {
              api.MergeRequestDetail(..d, pipeline: option.Some(pipeline))
            }),
            error: option.None,
          )
        }
      #(
        updated,
        batch([
          pipeline_stream_effect(updated, config),
          load_prior_pipelines(config, updated),
        ]),
      )
    }
    PipelineStreamStarted(stop) -> #(
      Model(..model, pipeline_stream_stop: option.Some(stop)),
      none(),
    )
    PipelineStreamUpdate(json) -> {
      let previous = detail_pipeline(model)
      let updated = apply_pipeline_update(model, json)
      let new_pipeline = detail_pipeline(updated)
      let was_in_progress = pipeline_is_in_progress(previous)
      let now_in_progress = pipeline_is_in_progress(new_pipeline)
      let sha_changed = case previous, new_pipeline {
        option.Some(old), option.Some(new) -> old.commit_sha != new.commit_sha
        option.None, option.Some(_) -> True
        _, _ -> False
      }
      #(
        updated,
        batch([
          case was_in_progress, now_in_progress {
            True, False -> load_detail(config, updated)
            _, _ -> none()
          },
          case updated.tab, sha_changed {
            Checks, True -> load_prior_pipelines(config, updated)
            _, _ -> none()
          },
        ]),
      )
    }
    PipelineStreamError -> {
      let model = stop_pipeline_stream(model)
      #(model, pipeline_stream_effect(model, config))
    }
    ChecksRerun(Error(_)) -> #(
      Model(..model, error: option.Some("Could not re-run checks")),
      none(),
    )
    PriorPipelinesLoaded(Ok(pipelines)) -> #(
      Model(
        ..model,
        prior_pipelines: pipelines,
        detail: reconcile_detail_pipeline(model.detail, pipelines),
      ),
      none(),
    )
    PriorPipelinesLoaded(Error(_)) -> #(model, none())
    TogglePriorPipeline(run_id) -> #(
      Model(
        ..model,
        expanded_prior_run_ids: toggle_prior_run_expanded(
          model.expanded_prior_run_ids,
          run_id,
        ),
      ),
      none(),
    )
    LabelsLoaded(Ok(labels)) -> #(Model(..model, repo_labels: labels), none())
    LabelsLoaded(Error(_)) -> #(model, none())
    ToggleMrLabel(label_id) ->
      case model.detail {
        option.None -> #(model, none())
        option.Some(detail) -> {
          let ids = selected_mr_label_ids(detail.merge_request)
          let next_ids = case list.contains(ids, label_id) {
            True -> list.filter(ids, fn(id) { id != label_id })
            False -> [label_id, ..ids]
          }
          #(
            Model(..model, saving_labels: True),
            patch_mr_labels(config, model, next_ids),
          )
        }
      }
    MrLabelsUpdated(Ok(mr)) -> #(
      Model(
        ..model,
        detail: option.map(model.detail, fn(d) {
          api.MergeRequestDetail(..d, merge_request: mr)
        }),
        saving_labels: False,
        error: option.None,
      ),
      none(),
    )
    MrLabelsUpdated(Error(_)) -> #(
      Model(
        ..model,
        saving_labels: False,
        error: option.Some("Could not update labels"),
      ),
      none(),
    )
    ToggleDraft ->
      case model.detail {
        option.None -> #(model, none())
        option.Some(detail) -> #(
          Model(..model, toggling_draft: True, error: option.None),
          patch_mr_draft(config, model, !detail.merge_request.is_draft),
        )
      }
    MrDraftUpdated(Ok(_)) -> #(
      Model(..model, toggling_draft: False),
      load_detail(config, model),
    )
    MrDraftUpdated(Error(_)) -> #(
      Model(
        ..model,
        toggling_draft: False,
        error: option.Some("Could not update draft status"),
      ),
      none(),
    )
    ToggleLabelsMenu -> #(
      Model(
        ..model,
        labels_menu_open: !model.labels_menu_open,
        label_filter: "",
      ),
      none(),
    )
    LabelFilterChanged(query) -> #(Model(..model, label_filter: query), none())
    ToggleAssignee(user_id) ->
      case model.detail {
        option.None -> #(model, none())
        option.Some(detail) -> {
          let ids = selected_mr_assignee_ids(detail.merge_request)
          let next_ids = case list.contains(ids, user_id) {
            True -> list.filter(ids, fn(id) { id != user_id })
            False -> [user_id, ..ids]
          }
          #(
            Model(..model, saving_assignees: True),
            patch_mr_assignees(config, model, detail.merge_request, next_ids),
          )
        }
      }
    AssigneeToggled(Ok(mr)) -> #(
      Model(
        ..model,
        detail: option.map(model.detail, fn(d) {
          api.MergeRequestDetail(..d, merge_request: mr)
        }),
        saving_assignees: False,
        error: option.None,
      ),
      none(),
    )
    AssigneeToggled(Error(_)) -> #(
      Model(
        ..model,
        saving_assignees: False,
        error: option.Some("Could not update assignees"),
      ),
      none(),
    )
    ToggleAssigneesMenu -> #(
      Model(
        ..model,
        assignees_menu_open: !model.assignees_menu_open,
        assignee_filter: "",
      ),
      none(),
    )
    AssigneeFilterChanged(query) -> #(
      Model(..model, assignee_filter: query),
      none(),
    )
    ToggleReviewer(user_id) ->
      case model.detail {
        option.None -> #(model, none())
        option.Some(detail) ->
          case user_id == detail.merge_request.author_user_id {
            True -> #(model, none())
            False -> {
              let ids = selected_mr_reviewer_ids(detail.merge_request)
              let next_ids = case list.contains(ids, user_id) {
                True -> list.filter(ids, fn(id) { id != user_id })
                False -> [user_id, ..ids]
              }
              #(
                Model(..model, saving_reviewers: True),
                patch_mr_reviewers(config, model, detail.merge_request, next_ids),
              )
            }
          }
      }
    ReviewerToggled(Ok(mr)) -> #(
      Model(
        ..model,
        detail: option.map(model.detail, fn(d) {
          api.MergeRequestDetail(..d, merge_request: mr)
        }),
        saving_reviewers: False,
        error: option.None,
      ),
      none(),
    )
    ReviewerToggled(Error(_)) -> #(
      Model(
        ..model,
        saving_reviewers: False,
        error: option.Some("Could not update reviewers"),
      ),
      none(),
    )
    ToggleReviewersMenu -> #(
      Model(
        ..model,
        reviewers_menu_open: !model.reviewers_menu_open,
        reviewer_filter: "",
      ),
      none(),
    )
    ReviewerFilterChanged(query) -> #(
      Model(..model, reviewer_filter: query),
      none(),
    )
    StartEdit ->
      case model.detail {
        option.None -> #(model, none())
        option.Some(detail) ->
          case detail.merge_request.state {
            "open" -> #(
              Model(
                ..model,
                editing: True,
                edit_title: detail.merge_request.title,
                error: option.None,
              ),
              none(),
            )
            _ -> #(model, none())
          }
      }
    StartEditDescription ->
      case model.detail {
        option.None -> #(model, none())
        option.Some(detail) ->
          case detail.merge_request.state {
            "open" -> {
              let description =
                option.unwrap(detail.merge_request.description, "")
              #(
                Model(
                  ..model,
                  editing_description: True,
                  description_menu_open: False,
                  edit_description: description,
                  edit_description_seed: model.edit_description_seed + 1,
                  error: option.None,
                ),
                none(),
              )
            }
            _ -> #(model, none())
          }
      }
    ToggleDescriptionMenu -> #(
      Model(..model, description_menu_open: !model.description_menu_open),
      none(),
    )
    SubmitReview(state) ->
      case model.detail, model.submitting_review {
        option.None, _ | _, True -> #(model, none())
        option.Some(_), False ->
          #(
            Model(..model, submitting_review: True, error: option.None),
            lustre_http.post(
              config,
              api_base(config, model) <> "/reviews",
              api.submit_mr_review_body(state, option.None),
              lustre_http.expect_json(api.mr_review_decoder(), ReviewSubmitted),
            ),
          )
      }
    ReviewSubmitted(Ok(_review)) -> #(
      Model(..model, submitting_review: False),
      load_detail(config, model),
    )
    ReviewSubmitted(Error(_)) -> #(
      Model(
        ..model,
        submitting_review: False,
        error: option.Some("Could not submit review"),
      ),
      none(),
    )
    CancelEdit ->
      #(
        Model(
          ..model,
          editing: False,
          editing_description: False,
          description_menu_open: False,
          error: option.None,
        ),
        none(),
      )
    EditTitleChanged(v) -> #(Model(..model, edit_title: v), none())
    EditDescriptionChanged(v) -> #(Model(..model, edit_description: v), none())
    TitleKeyPressed(key) ->
      case key {
        "Enter" -> save_title_edit(config, model)
        "Escape" -> #(
          Model(..model, editing: False, error: option.None),
          none(),
        )
        _ -> #(model, none())
      }
    DescriptionKeyPressed(key) ->
      case key {
        "Escape" -> #(
          Model(..model, editing_description: False, error: option.None),
          none(),
        )
        _ -> #(model, none())
      }
    SaveEdit ->
      case model.saving {
        True -> #(model, none())
        False ->
          case model.editing_description {
            True -> save_description_edit(config, model)
            False ->
              case model.editing {
                True -> save_title_edit(config, model)
                False -> #(model, none())
              }
          }
      }
    Saved(Ok(mr)) -> #(
      Model(
        ..model,
        detail: option.map(model.detail, fn(d) {
          api.MergeRequestDetail(..d, merge_request: mr)
        }),
        editing: False,
        editing_description: False,
        description_menu_open: False,
        saving: False,
        edit_title: mr.title,
        edit_description: option.unwrap(mr.description, ""),
        error: option.None,
      ),
      none(),
    )
    Saved(Error(_)) -> #(
      Model(
        ..model,
        saving: False,
        error: option.Some("Could not save merge request"),
      ),
      none(),
    )
  }
}

fn selected_mr_label_ids(mr: MergeRequest) -> List(String) {
  list.map(mr.labels, fn(label) { label.id })
}

fn selected_mr_assignee_ids(mr: MergeRequest) -> List(String) {
  list.map(mr.assignees, fn(assignee) { assignee.user_id })
}

fn selected_mr_reviewer_ids(mr: MergeRequest) -> List(String) {
  list.map(mr.reviewers, fn(reviewer) { reviewer.user_id })
}

fn save_title_edit(
  config: Config,
  model: Model,
) -> #(Model, Effect(Msg)) {
  case model.detail {
    option.None -> #(model, none())
    option.Some(detail) -> {
      let trimmed = string.trim(model.edit_title)
      case trimmed {
        "" ->
          #(
            Model(
              ..model,
              editing: False,
              error: option.Some("Title is required"),
            ),
            none(),
          )
        title ->
          case title == detail.merge_request.title {
            True -> #(Model(..model, editing: False), none())
            False ->
              #(
                Model(..model, saving: True),
                lustre_http.patch(
                  config,
                  api_base(config, model),
                  api.update_merge_request_patch(
                    option.Some(title),
                    option.None,
                    option.None,
                    option.None,
                    option.None,
                    option.None,
                  ),
                  lustre_http.expect_json(
                    api.merge_request_decoder(),
                    Saved,
                  ),
                ),
              )
          }
      }
    }
  }
}

fn save_description_edit(
  config: Config,
  model: Model,
) -> #(Model, Effect(Msg)) {
  case model.detail {
    option.None -> #(model, none())
    option.Some(detail) -> {
      let next_description =
        case string.trim(model.edit_description) {
          "" -> option.None
          d -> option.Some(d)
        }
      case next_description == detail.merge_request.description {
        True -> #(Model(..model, editing_description: False), none())
        False ->
          #(
            Model(..model, saving: True),
            lustre_http.patch(
              config,
              api_base(config, model),
              api.update_merge_request_patch(
                option.None,
                option.Some(next_description),
                option.None,
                option.None,
                option.None,
                option.None,
              ),
              lustre_http.expect_json(
                api.merge_request_decoder(),
                Saved,
              ),
            ),
          )
      }
    }
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

fn org_reviewer_options(
  members: List(OrgMember),
  author_user_id: String,
) -> List(labels_ui.AssigneeOption) {
  members
  |> list.filter(fn(member) { member.user_id != author_user_id })
  |> list.map(fn(member) {
    labels_ui.AssigneeOption(
      user_id: member.user_id,
      name: member_label(member),
    )
  })
}

fn reviewers_field(
  model: Model,
  mr: MergeRequest,
  reviews: List(MrReview),
) -> Element(Msg) {
  let options = org_reviewer_options(model.org_members, mr.author_user_id)
  div([attr.class("space-y-2")], [
    case options {
      [] ->
        p([attr.class("text-sm text-gh-muted")], [
          text("No other org members to request."),
        ])
      _ ->
        labels_ui.searchable_assignee_field(
          options,
          selected_mr_reviewer_ids(mr),
          model.reviewers_menu_open,
          model.reviewer_filter,
          option.None,
          ToggleReviewersMenu,
          ReviewerFilterChanged,
          ToggleReviewer,
        )
    },
    reviewers_status_summary(mr, reviews),
  ])
}

fn member_label(member: OrgMember) -> String {
  case string.trim(member.display_name) {
    "" -> member.user_id
    name -> name
  }
}

fn patch_mr_assignees(
  config: Config,
  model: Model,
  mr: MergeRequest,
  assignee_user_ids: List(String),
) -> Effect(Msg) {
  lustre_http.patch(
    config,
    api_base(config, model),
    api.update_merge_request_patch(
      option.None,
      option.None,
      option.Some(selected_mr_label_ids(mr)),
      option.None,
      option.Some(assignee_user_ids),
      option.None,
    ),
    lustre_http.expect_json(api.merge_request_decoder(), AssigneeToggled),
  )
}

fn patch_mr_reviewers(
  config: Config,
  model: Model,
  mr: MergeRequest,
  reviewer_user_ids: List(String),
) -> Effect(Msg) {
  lustre_http.patch(
    config,
    api_base(config, model),
    api.update_merge_request_patch(
      option.None,
      option.None,
      option.Some(selected_mr_label_ids(mr)),
      option.None,
      option.None,
      option.Some(reviewer_user_ids),
    ),
    lustre_http.expect_json(api.merge_request_decoder(), ReviewerToggled),
  )
}

fn patch_mr_labels(
  config: Config,
  model: Model,
  label_ids: List(String),
) -> Effect(Msg) {
  lustre_http.patch(
    config,
    api_base(config, model),
    api.update_merge_request_body(option.Some(label_ids), option.None),
    lustre_http.expect_json(api.merge_request_decoder(), MrLabelsUpdated),
  )
}

fn patch_mr_draft(config: Config, model: Model, draft: Bool) -> Effect(Msg) {
  lustre_http.patch(
    config,
    api_base(config, model),
    api.update_merge_request_body(option.None, option.Some(draft)),
    lustre_http.expect_json(api.merge_request_decoder(), MrDraftUpdated),
  )
}

fn apply_pending_on_init(config: Config, model: Model) -> Effect(Msg) {
  case model.pending_diff_line, model.tab {
    option.Some(_), Changes ->
      case model.diff_files {
        [] ->
          lustre_http.get(
            config,
            api_base(config, model) <> "/diff",
            lustre_http.expect_json(api.diff_files_decoder(), DiffLoaded),
          )
        _ -> apply_pending_diff_effect(config, model)
      }
    _, _ -> none()
  }
}

fn apply_pending_diff_effect(config: Config, model: Model) -> Effect(Msg) {
  case model.pending_diff_line {
    option.Some(#(file, _)) ->
      case model.selected_file, model.patch {
        option.Some(f), option.Some(_) if f == file -> none()
        _, _ -> file_load_effect(config, model, file)
      }
    option.None -> none()
  }
}

fn uri_encode(s: String) -> String {
  uri.percent_encode(s)
}

fn target_file_from_diff_files(
  files: List(DiffFile),
  pending: option.Option(#(String, Int)),
) -> option.Option(String) {
  case files {
    [] -> option.None
    [first, ..] ->
      case pending {
        option.Some(#(path, _)) ->
          case list.any(files, fn(f) { f.path == path }) {
            True -> option.Some(path)
            False -> option.Some(first.path)
          }
        option.None -> option.Some(first.path)
      }
  }
}

fn selected_change_file(
  model: Model,
  files: List(DiffFile),
) -> option.Option(String) {
  let conflict_only = conflict_paths(model)
  case model.selected_file {
    option.Some(path) ->
      case
        list.any(files, fn(f) { f.path == path })
        || list.contains(conflict_only, path)
      {
        True -> option.Some(path)
        False -> target_file_from_diff_files(files, model.pending_diff_line)
      }
    option.None ->
      case target_file_from_diff_files(files, model.pending_diff_line) {
        option.Some(path) -> option.Some(path)
        option.None ->
          case conflict_only {
            [first, ..] -> option.Some(first)
            [] -> option.None
          }
      }
  }
}

fn patch_load_effect(
  config: Config,
  model: Model,
  path: String,
) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model) <> "/diff?path=" <> uri_encode(path),
    lustre_http.expect_json(api.diff_patch_decoder(), PatchLoaded),
  )
}

fn conflict_load_effect(
  config: Config,
  model: Model,
  path: String,
) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model) <> "/conflict?path=" <> uri_encode(path),
    lustre_http.expect_json(api.conflict_file_decoder(), ConflictLoaded),
  )
}

fn file_load_effect(config: Config, model: Model, path: String) -> Effect(Msg) {
  case is_conflict_file(model, path) {
    True -> conflict_load_effect(config, model, path)
    False -> patch_load_effect(config, model, path)
  }
}

fn conflict_paths(model: Model) -> List(String) {
  case model.detail {
    option.Some(d) -> d.merge_check.conflict_paths
    option.None -> []
  }
}

fn is_conflict_file(model: Model, path: String) -> Bool {
  case model.detail {
    option.Some(d) ->
      !d.merge_check.mergeable
      && list.contains(d.merge_check.conflict_paths, path)
    option.None -> False
  }
}

fn all_change_files(model: Model) -> List(DiffFile) {
  let existing_paths = list.map(model.diff_files, fn(f: DiffFile) { f.path })
  let extras =
    list.filter(conflict_paths(model), fn(path) {
      !list.contains(existing_paths, path)
    })
  list.append(
    model.diff_files,
    list.map(extras, fn(path) {
      api.DiffFile(path:, status: "conflict", additions: 0, deletions: 0)
    }),
  )
}

fn files_with_comments(model: Model, files: List(DiffFile)) -> List(DiffFile) {
  list.filter(files, fn(f) {
    comment_count_for_file(model.comments, f.path) > 0
  })
}

fn ensure_selected_among_files(
  model: Model,
  files: List(DiffFile),
) -> #(option.Option(String), Bool) {
  case files {
    [] -> #(option.None, False)
    [first, ..] ->
      case model.selected_file {
        option.Some(path) ->
          case list.any(files, fn(f) { f.path == path }) {
            True -> #(option.Some(path), False)
            False -> #(option.Some(first.path), True)
          }
        option.None -> #(option.Some(first.path), True)
      }
  }
}

fn commented_files_summary_label(count: Int) -> String {
  case count {
    0 -> "No files with comments"
    1 -> "1 file with comments"
    n -> int.to_string(n) <> " files with comments"
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
          routes.mr_list_path(model.org_slug, model.repo_name),
          "Merge requests",
        ),
        error,
        case model.loading {
          True -> components.loading_state()
          False -> components.empty_state("Merge request not found")
        },
      ])
    option.Some(detail) -> detail_view(model, detail, error)
  }
}

fn detail_view(
  model: Model,
  detail: MergeRequestDetail,
  error: Element(Msg),
) -> Element(Msg) {
  let mr = detail.merge_request
  let title = "#" <> int.to_string(mr.number) <> " " <> mr.title
  div([attr.class(components.page <> " max-w-5xl")], [
    components.breadcrumb_back(
      routes.mr_list_path(model.org_slug, model.repo_name),
      "Merge requests",
    ),
    div([attr.class("mb-4 space-y-3")], [
      case model.editing {
        True -> edit_title_form(model, mr)
        False ->
          h1(editable_title_attrs(mr.state == "open"), [text(title)])
      },
      div([attr.class("detail-header-toolbar")], [
        div([attr.class("detail-header-meta")], [
          mr_status_badges(mr),
          span([attr.class("comic-branch-flow")], [
            span([], [text(mr.source_branch)]),
            span([attr.class("comic-branch-arrow")], [text("→")]),
            span([], [text(mr.target_branch)]),
          ]),
        ]),
        div([attr.class("mr-detail-actions-wrap")], [
          detail_actions(model, mr, detail.merge_check),
        ]),
      ]),
      merge_status_banner(
        model,
        mr,
        detail.merge_check,
        current_pipeline_run(model),
      ),
    ]),
    error,
    tab_bar(model.tab, current_pipeline_run(model)),
    case model.tab {
      Conversation ->
        div([attr.class("grid gap-8 lg:grid-cols-[minmax(0,1fr)_14rem]")], [
          div([attr.class("min-w-0")], [tab_content(model, detail)]),
          aside([attr.class("space-y-5 lg:sticky lg:top-6 lg:self-start")], [
            labels_ui.sidebar_section(
              "Labels",
              labels_ui.searchable_label_field(
                model.repo_labels,
                mr.labels,
                model.labels_menu_open,
                model.label_filter,
                ToggleLabelsMenu,
                LabelFilterChanged,
                ToggleMrLabel,
              ),
            ),
            labels_ui.sidebar_section(
              "Assignees",
              labels_ui.searchable_assignee_field(
                org_member_options(model.org_members),
                selected_mr_assignee_ids(mr),
                model.assignees_menu_open,
                model.assignee_filter,
                model.viewer_user_id,
                ToggleAssigneesMenu,
                AssigneeFilterChanged,
                ToggleAssignee,
              ),
            ),
            labels_ui.sidebar_section(
              "Reviewers",
              div([attr.class("space-y-2")], [
                reviewers_field(model, mr, detail.reviews),
              ]),
            ),
            labels_ui.sidebar_section(
              "Linked issues",
              linked_issues_view(model, detail.linked_issues),
            ),
          ]),
        ])
      _ -> div([attr.class("min-w-0")], [tab_content(model, detail)])
    },
  ])
}

fn merge_status_banner(
  model: Model,
  mr: MergeRequest,
  check: MergeCheck,
  pipeline: option.Option(Pipeline),
) -> Element(Msg) {
  case mr.state {
    "merged" -> merged_banner(model, mr)
    "closed" -> closed_banner(mr)
    _ ->
      div([], [
        behind_target_banner(check),
        merge_check_banner(check, pipeline),
      ])
  }
}

fn behind_target_banner(check: MergeCheck) -> Element(Msg) {
  case check.behind_target {
    True ->
      p([attr.class("comic-banner-info")], [
        text(
          "This branch is out of date with the base branch. Update it to merge the latest changes.",
        ),
      ])
    False -> text("")
  }
}

fn linked_issues_view(
  model: Model,
  linked_issues: List(LinkedIssue),
) -> Element(Msg) {
  case linked_issues {
    [] ->
      p([attr.class("text-xs text-slate-500")], [text("None")])
    issues ->
      div([attr.class("space-y-2")], list.map(issues, fn(issue) {
        linked_issue_row(model, issue)
      }))
  }
}

fn linked_issue_row(model: Model, issue: LinkedIssue) -> Element(Msg) {
  a(
    [
      attr.href(
        routes.issue_detail_path(model.org_slug, model.repo_name, issue.number),
      ),
      attr.class(
        "flex min-w-0 items-center gap-2 no-underline hover:opacity-80",
      ),
    ],
    [
      span([attr.class("comic-issue-num shrink-0")], [
        text("#" <> int.to_string(issue.number)),
      ]),
      span(
        [attr.class("min-w-0 flex-1 truncate text-sm font-semibold text-gh-ink")],
        [text(issue.title)],
      ),
      issue_state_badge(issue.state),
    ],
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

fn mr_status_badges(mr: MergeRequest) -> Element(Msg) {
  let badges = case mr.is_draft {
    True -> [draft_badge(), mr_state_badge(mr.state)]
    False -> [mr_state_badge(mr.state)]
  }
  div([attr.class("flex flex-wrap items-center gap-1.5")], badges)
}

fn draft_toggle_label(toggling: Bool, is_draft: Bool) -> String {
  case toggling, is_draft {
    True, _ -> "Saving…"
    False, True -> "Ready for review"
    False, False -> "Mark as draft"
  }
}

fn detail_actions(
  model: Model,
  mr: MergeRequest,
  check: MergeCheck,
) -> Element(Msg) {
  case mr.state {
    "open" ->
      case mr.is_draft {
        True -> draft_action_panel(model, mr)
        False -> open_action_panel(model, mr, check)
      }
    _ -> text("")
  }
}

fn detail_actions_shell(children: List(Element(Msg))) -> Element(Msg) {
  div([attr.class("mr-detail-actions")], children)
}

fn draft_action_panel(model: Model, mr: MergeRequest) -> Element(Msg) {
  detail_actions_shell([
    p([attr.class("mr-detail-draft-copy")], [
      text("Draft — merge stays blocked until you're ready."),
    ]),
    button(
      [
        attr.type_("button"),
        attr.class(
          components.btn_primary
          <> " "
          <> action_size
          <> " !border-transparent !bg-gh-accent !px-5 !text-gh-ink hover:!bg-gh-accent-hover",
        ),
        attr.disabled(model.toggling_draft),
        event.on_click(ToggleDraft),
      ],
      [text(draft_toggle_label(model.toggling_draft, mr.is_draft))],
    ),
    button(
      [
        attr.type_("button"),
        attr.class(components.btn_secondary <> " " <> action_size <> " !px-4"),
        event.on_click(CloseMr),
      ],
      [text("Close")],
    ),
  ])
}

fn mark_as_draft_button(model: Model) -> Element(Msg) {
  button(
    [
      attr.type_("button"),
      attr.class("mr-detail-mark-draft"),
      attr.disabled(model.toggling_draft),
      event.on_click(ToggleDraft),
    ],
    [text(draft_toggle_label(model.toggling_draft, False))],
  )
}

fn open_action_panel(
  model: Model,
  mr: MergeRequest,
  check: MergeCheck,
) -> Element(Msg) {
  div([attr.class("relative w-full shrink-0 sm:w-auto")], [
    detail_actions_shell([
      mark_as_draft_button(model),
      span([attr.class("mr-detail-actions-divider")], []),
      span([attr.class("mr-detail-merge-label")], [text("Merge as")]),
      merge_method_select(model),
      update_branch_button(model, check),
      button(
        [
          attr.type_("button"),
          attr.class(components.btn_secondary <> " " <> action_size <> " !px-4"),
          event.on_click(CloseMr),
        ],
        [text("Close")],
      ),
      case model.show_merge_confirm {
        False ->
          button(
            [
              attr.type_("button"),
              attr.class(
                components.btn_primary
                <> " "
                <> action_size
                <> " !border-transparent !bg-gh-accent !px-5 !text-gh-ink hover:!bg-gh-accent-hover",
              ),
              attr.disabled(!check.mergeable),
              event.on_click(ShowMergeConfirm),
            ],
            [text("Merge")],
          )
        True ->
          button(
            [
              attr.type_("button"),
              attr.class(
                components.btn_secondary <> " " <> action_size <> " !px-4",
              ),
              event.on_click(CancelMergeConfirm),
            ],
            [text("Cancel")],
          )
      },
    ]),
    case model.show_merge_confirm {
      False -> text("")
      True -> merge_confirm_popover(model, mr, check)
    },
  ])
}

fn closed_banner(mr: MergeRequest) -> Element(Msg) {
  let closed_time = case mr.closed_at {
    option.Some(at) -> " · " <> time_format.format_timestamp(at)
    option.None -> ""
  }
  p([attr.class("comic-banner-neutral")], [
    text("Not merged"),
    text(closed_time),
  ])
}

fn merged_banner(model: Model, mr: MergeRequest) -> Element(Msg) {
  let merge_ref = case mr.merge_commit_sha {
    option.Some(sha) ->
      a(
        [
          attr.href(routes.commit_tree_path(
            model.org_slug,
            model.repo_name,
            sha,
          )),
          attr.class("font-mono font-semibold text-gh-ink hover:underline"),
        ],
        [text(short_sha(sha))],
      )
    option.None -> text("")
  }
  let merged_time = case mr.merged_at {
    option.Some(at) -> " · " <> time_format.format_timestamp(at)
    option.None -> ""
  }
  p([attr.class("comic-status-banner")], [
    text("Merged " <> mr.source_branch <> " into " <> mr.target_branch),
    text(merged_time <> " · "),
    merge_ref,
  ])
}

const max_conflict_paths_shown = 10

fn merge_check_banner(
  check: MergeCheck,
  pipeline: option.Option(Pipeline),
) -> Element(Msg) {
  let approval = approval_status_banner(check)
  let conflict = case check.mergeable, pipeline {
    True, _ -> text("")
    False, option.Some(_) ->
      case
        is_ci_merge_message(check.message)
        || is_approval_merge_message(check.message)
        || is_review_merge_message(check.message)
      {
        True -> text("")
        False -> merge_conflict_banner(check)
      }
    False, option.None ->
      case
        is_approval_merge_message(check.message)
        || is_review_merge_message(check.message)
      {
        True -> text("")
        False -> merge_conflict_banner(check)
      }
  }
  div([], [approval, conflict])
}

fn approval_status_banner(check: MergeCheck) -> Element(Msg) {
  case check.required_approvals {
    0 -> text("")
    _ ->
      p([attr.class("comic-banner-neutral")], [
        text(
          int.to_string(check.approval_count)
            <> " of "
            <> int.to_string(check.required_approvals)
            <> " required approval"
            <> case check.required_approvals {
              1 -> ""
              _ -> "s"
            },
        ),
      ])
  }
}

fn is_approval_merge_message(message: String) -> Bool {
  string.starts_with(message, "Needs ") && string.contains(message, "approval")
}

fn is_review_merge_message(message: String) -> Bool {
  is_approval_merge_message(message)
  || string.starts_with(message, "Changes requested")
}

fn merge_conflict_banner(check: MergeCheck) -> Element(Msg) {
  case check.message {
    "Mark as ready for review first" -> text("")
    _ -> merge_conflict_banner_inner(check)
  }
}

fn merge_conflict_banner_inner(check: MergeCheck) -> Element(Msg) {
  let banner_class = "comic-banner-warning"
  case check.conflict_paths {
    [] -> p([attr.class(banner_class)], [text(check.message)])
    paths -> {
      let #(shown, rest) = list.split(paths, max_conflict_paths_shown)
      let path_items =
        list.map(shown, fn(path) {
          li([], [
            button(
              [
                attr.type_("button"),
                attr.class(
                  "font-mono text-xs text-amber-950 underline decoration-amber-400/70 underline-offset-2 hover:text-amber-900",
                ),
                event.on_click(GoToConflictFile(path)),
              ],
              [text(path)],
            ),
          ])
        })
      let more = case rest {
        [] -> []
        _ -> [
          li([], [
            text("and " <> int.to_string(list.length(rest)) <> " more"),
          ]),
        ]
      }
      div([attr.class(banner_class)], [
        p([], [text(check.message)]),
        ul([attr.class("mt-2 list-disc pl-5")], list.append(path_items, more)),
      ])
    }
  }
}

fn is_ci_merge_message(message: String) -> Bool {
  case message {
    "Checks running"
    | "Checks failed"
    | "Checks stale - push to re-run"
    | "Checks incomplete"
    | "CI not configured" -> True
    _ -> False
  }
}

fn pipeline_status_detail(pipeline: Pipeline) -> String {
  case pipeline.state {
    "running" -> "In progress - running Dagger pipeline…"
    "queued" -> "Waiting for CI worker…"
    "success" -> "Completed successfully"
    "failure" -> "Failed"
    "skipped" -> "No CI module configured"
    _ -> pipeline.state
  }
}

fn checks_status_circle(
  state: String,
  size: String,
  animated: Bool,
) -> Element(Msg) {
  ci_status.status_circle(state, size, animated)
}

fn checks_summary(pipeline: option.Option(Pipeline)) -> String {
  case pipeline {
    option.None -> "No checks have run for this merge request yet."
    option.Some(run) ->
      case run.state {
        "success" -> "All checks passed"
        "failure" -> "Some checks failed"
        "running" -> "Checks are running"
        "queued" -> "Checks are queued"
        "skipped" -> "CI not configured for this commit"
        _ -> "Check status: " <> run.state
      }
  }
}

fn rerun_checks_button(pipeline: option.Option(Pipeline)) -> Element(Msg) {
  let checks_busy = pipeline_is_in_progress(pipeline)
  button(
    [
      attr.type_("button"),
      attr.class(components.btn_secondary <> " !h-9 shrink-0 !px-4"),
      attr.disabled(checks_busy),
      attr.title(case checks_busy {
        True -> "Wait for the current check run to finish"
        False -> ""
      }),
      event.on_click(RerunChecks),
    ],
    [text("Re-run checks")],
  )
}

fn checks_tab_header(
  mr: MergeRequest,
  pipeline: option.Option(Pipeline),
) -> Element(Msg) {
  div([attr.class("mb-4 flex flex-wrap items-center justify-between gap-3")], [
    p([attr.class("text-sm font-medium text-gh-ink")], [
      text(checks_summary(pipeline)),
    ]),
    case mr.state {
      "open" -> rerun_checks_button(pipeline)
      _ -> text("")
    },
  ])
}

fn checks_tab(model: Model) -> Element(Msg) {
  case model.detail {
    option.None -> text("")
    option.Some(detail) -> {
      let mr = detail.merge_request
      let pipeline = current_pipeline_run(model)
      case pipeline {
        option.None ->
          div([attr.class(components.card)], [
            checks_tab_header(mr, option.None),
            p([attr.class("text-sm text-gh-muted")], [
              text(
                "Re-run checks after pushing a Dagger module (e.g. ci/dagger.json) to trigger a pipeline.",
              ),
            ]),
          ])
        option.Some(run) -> {
          let prior = prior_runs(option.Some(run), model.prior_pipelines)
          div([attr.class(components.card)], [
            checks_tab_header(mr, option.Some(run)),
            pipeline_run_card(run, True, True),
            case pipeline_is_in_progress(option.Some(run)) {
              True ->
                p([attr.class("mt-3 text-xs text-gh-muted")], [
                  text("Log updates stream live from the server."),
                ])
              False ->
                p([attr.class("mt-3 text-xs text-gh-muted")], [
                  text(
                    "Watching for new checks after push. Log updates stream live while a run is in progress.",
                  ),
                ])
            },
            prior_pipeline_runs(model, prior),
          ])
        }
      }
    }
  }
}

fn prior_pipeline_runs(model: Model, runs: List(Pipeline)) -> Element(Msg) {
  case runs {
    [] -> text("")
    _ ->
      div([attr.class("comic-section-divider")], [
        p(
          [
            attr.class(
              "mb-3 text-xs font-black uppercase tracking-widest text-gh-ink",
            ),
          ],
          [
            text("Previous runs"),
          ],
        ),
        div(
          [attr.class("space-y-2")],
          list.map(runs, fn(run) { prior_pipeline_run_row(model, run) }),
        ),
      ])
  }
}

fn prior_pipeline_run_row(model: Model, run: Pipeline) -> Element(Msg) {
  let expanded = is_prior_run_expanded(model, run.id)
  let module_name = case run.module_path {
    option.Some(path) -> path
    option.None -> "ci"
  }
  div([attr.class("comic-prior-run")], [
    button(
      [
        attr.type_("button"),
        attr.class("comic-prior-run-toggle"),
        event.on_click(TogglePriorPipeline(run.id)),
      ],
        [
          checks_status_circle(run.state, "mt-0.5 h-4 w-4 shrink-0", False),
          div([attr.class("min-w-0 flex-1")], [
            p([attr.class("text-sm font-medium text-gh-ink")], [
              text(module_name),
            ]),
            p([attr.class("mt-0.5 text-sm text-gh-muted")], [
              text(pipeline_status_detail(run)),
            ]),
            p([attr.class("mt-1 font-mono text-xs text-gh-muted")], [
              text(short_sha(run.commit_sha)),
              text(" · "),
              text(trigger_label(run.trigger)),
              case run.created_at {
                option.Some(at) ->
                  text(" · " <> time_format.format_timestamp(at))
                option.None -> text("")
              },
            ]),
          ]),
          span([attr.class("shrink-0 text-xs text-gh-muted")], [
            text(case expanded {
              True -> "Hide log"
              False -> "Show log"
            }),
          ]),
        ],
      ),
      case expanded {
        True ->
          div([attr.class("comic-prior-run-log")], [
            pipeline_log_panel(run),
          ])
        False -> text("")
      },
    ],
  )
}

fn pipeline_run_card(
  run: Pipeline,
  show_log: Bool,
  live: Bool,
) -> Element(Msg) {
  let module_name = case run.module_path {
    option.Some(path) -> path
    option.None -> "ci"
  }
  div([attr.class("comic-pipeline-card")], [
    checks_status_circle(run.state, "mt-0.5 h-4 w-4", live),
    div([attr.class("min-w-0 flex-1")], [
      p([attr.class("text-sm font-semibold text-gh-ink")], [text(module_name)]),
      p([attr.class("mt-0.5 text-sm text-gh-muted")], [
        text(pipeline_status_detail(run)),
      ]),
      p([attr.class("mt-1 font-mono text-xs text-gh-muted")], [
        text(short_sha(run.commit_sha)),
        text(" · "),
        text(trigger_label(run.trigger)),
        case run.module_path {
          option.Some(path) -> text(" · " <> path)
          option.None -> text("")
        },
      ]),
      case show_log {
        True -> pipeline_log_panel(run)
        False -> text("")
      },
    ]),
  ])
}

fn pipeline_log_panel(run: Pipeline) -> Element(Msg) {
  let log_body = case run.log {
    option.Some(log) if log != "" -> log
    _ ->
      case run.state {
        "running" | "queued" -> "Waiting for log output from the CI worker…"
        _ -> ""
      }
  }
  case log_body {
    "" -> text("")
    content -> {
      let base_class = "comic-log-panel"
      let attrs = [attr.class(base_class)]
      unsafe_raw_html("", "pre", attrs, ci_log.ansi_to_html(content))
    }
  }
}

fn short_sha(sha: String) -> String {
  case string.length(sha) {
    n if n >= 7 -> string.slice(sha, 0, 7)
    _ -> sha
  }
}

fn merge_method_label(method: api.MergeMethod) -> String {
  case method {
    api.MergeCommit -> "Create merge commit"
    api.Squash -> "Squash and merge"
    api.Rebase -> "Rebase and merge"
  }
}

fn editable_title_attrs(editable: Bool) -> List(attr.Attribute(Msg)) {
  case editable {
    True -> [
      attr.class(components.detail_title <> " cursor-text"),
      attr.title("Double-click to edit"),
      event.on("dblclick", decode.success(StartEdit)),
    ]
    False -> [attr.class(components.detail_title)]
  }
}

fn edit_title_form(model: Model, mr: MergeRequest) -> Element(Msg) {
  div([attr.class("flex min-w-0 flex-wrap items-center gap-2")], [
    span([attr.class("comic-issue-num !text-2xl")], [
      text("#" <> int.to_string(mr.number)),
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
      event.on_blur(SaveEdit),
      event.on_keydown(fn(key) { TitleKeyPressed(key) }),
    ]),
  ])
}

const action_size = "!h-10 shrink-0"

fn merge_method_select(model: Model) -> Element(Msg) {
  select(
    [
      attr.class(
        components.input
        <> " "
        <> action_size
        <> " !w-auto !min-w-[11rem] !py-0",
      ),
      event.on_change(fn(value) {
        case value {
          "squash" -> MergeMethodChanged(api.Squash)
          "rebase" -> MergeMethodChanged(api.Rebase)
          _ -> MergeMethodChanged(api.MergeCommit)
        }
      }),
    ],
    [
      option(
        [
          attr.value("merge"),
          attr.selected(model.merge_method == api.MergeCommit),
        ],
        "Create merge commit",
      ),
      option(
        [
          attr.value("squash"),
          attr.selected(model.merge_method == api.Squash),
        ],
        "Squash and merge",
      ),
      option(
        [
          attr.value("rebase"),
          attr.selected(model.merge_method == api.Rebase),
        ],
        "Rebase and merge",
      ),
    ],
  )
}

fn merge_confirm_message(model: Model, mr: MergeRequest) -> String {
  merge_method_label(model.merge_method)
  <> " "
  <> mr.source_branch
  <> " into "
  <> mr.target_branch
  <> "?"
}

fn merge_confirm_popover(
  model: Model,
  mr: MergeRequest,
  check: MergeCheck,
) -> Element(Msg) {
  div(
    [
      attr.class("comic-merge-popover"),
      attr.role("dialog"),
    ],
    [
      p([attr.class("mb-3 text-sm leading-snug text-gh-ink")], [
        text(merge_confirm_message(model, mr)),
      ]),
      label(
        [
          attr.class(
            "mb-4 flex cursor-pointer items-center gap-2 text-sm text-gh-ink",
          ),
        ],
        [
          input([
            attr.type_("checkbox"),
            attr.checked(model.delete_source_branch),
            event.on_check(DeleteSourceBranchChanged),
          ]),
          text("Delete branch " <> mr.source_branch),
        ],
      ),
      div([attr.class("flex gap-2")], [
        button(
          [
            attr.type_("button"),
            attr.class(
              components.btn_secondary
              <> " "
              <> action_size
              <> " min-w-0 flex-1 !px-3",
            ),
            event.on_click(CancelMergeConfirm),
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
              <> " min-w-0 flex-1 !border-transparent !bg-gh-accent !px-3 !text-gh-ink hover:!bg-gh-accent-hover",
            ),
            attr.disabled(!check.mergeable),
            event.on_click(Merge),
          ],
          [text("Confirm")],
        ),
      ]),
    ],
  )
}

fn update_branch_button(model: Model, check: MergeCheck) -> Element(Msg) {
  case check.behind_target {
    True ->
      button(
        [
          attr.type_("button"),
          attr.class(components.btn_secondary <> " " <> action_size <> " !px-4"),
          attr.disabled(model.updating_branch),
          event.on_click(UpdateBranch),
        ],
        [
          text(case model.updating_branch {
            True -> "Updating…"
            False -> "Update branch"
          }),
        ],
      )
    False -> text("")
  }
}

fn review_actions_section(
  model: Model,
  mr: MergeRequest,
  check: MergeCheck,
) -> Element(Msg) {
  case mr.state, mr.is_draft {
    "open", False -> {
      let show_warning =
        !check.mergeable && is_review_merge_message(check.message)
      case can_submit_review(model, mr), show_warning {
        True, _ | _, True ->
          div([attr.class("mb-4 space-y-3")], [
            review_actions(model, mr),
            case show_warning {
              True ->
                p([attr.class("comic-banner-warning")], [text(check.message)])
              False -> text("")
            },
          ])
        False, False -> text("")
      }
    }
    _, _ -> text("")
  }
}

fn can_submit_review(model: Model, mr: MergeRequest) -> Bool {
  case model.viewer_user_id {
    option.None -> False
    option.Some(viewer) ->
      viewer != mr.author_user_id
      && list.any(mr.reviewers, fn(reviewer) { reviewer.user_id == viewer })
      && list.any(model.org_members, fn(m) {
        m.user_id == viewer && { m.role == "owner" || m.role == "member" }
      })
  }
}

fn review_actions(model: Model, mr: MergeRequest) -> Element(Msg) {
  case can_submit_review(model, mr) {
    False -> text("")
    True ->
      case model.viewer_user_id {
        option.None -> text("")
        option.Some(viewer) -> review_action_buttons(model, viewer)
      }
  }
}

fn review_action_buttons(model: Model, viewer: String) -> Element(Msg) {
  let reviews = case model.detail {
    option.Some(detail) -> detail.reviews
    option.None -> []
  }
  let latest = latest_review_by_user(reviews, viewer)
  let show_approve = case latest {
    option.Some(review) -> review.state != "approved"
    option.None -> True
  }
  let show_request_changes = case latest {
    option.Some(review) -> review.state != "changes_requested"
    option.None -> True
  }
  case show_approve, show_request_changes {
    False, False -> text("")
    _, _ ->
      div([attr.class("flex flex-wrap items-center gap-2")], [
        case show_approve {
          True ->
            button(
              [
                attr.type_("button"),
                attr.class(components.btn_primary <> " !h-9 !px-4"),
                attr.disabled(model.submitting_review),
                event.on_click(SubmitReview("approved")),
              ],
              [text("Approve")],
            )
          False -> text("")
        },
        case show_request_changes {
          True ->
            button(
              [
                attr.type_("button"),
                attr.class(components.btn_secondary <> " !h-9 !px-4"),
                attr.disabled(model.submitting_review),
                event.on_click(SubmitReview("changes_requested")),
              ],
              [text("Request changes")],
            )
          False -> text("")
        },
      ])
  }
}

fn review_state_label(state: String) -> String {
  case state {
    "approved" -> "approved these changes"
    "changes_requested" -> "requested changes"
    _ -> "reviewed"
  }
}

fn latest_review_by_user(
  reviews: List(MrReview),
  user_id: String,
) -> option.Option(MrReview) {
  case list.find(reviews, fn(review) { review.user_id == user_id }) {
    Ok(review) -> option.Some(review)
    Error(_) -> option.None
  }
}

fn reviewers_status_summary(
  mr: MergeRequest,
  reviews: List(MrReview),
) -> Element(Msg) {
  case mr.reviewers {
    [] -> text("")
    reviewers -> {
      let statuses =
        list.map(reviewers, fn(reviewer) {
          case latest_review_by_user(reviews, reviewer.user_id) {
            option.Some(review) -> review.state
            option.None -> "pending"
          }
        })
      let approval_count =
        list.length(list.filter(statuses, fn(s) { s == "approved" }))
      let changes_requested =
        list.any(statuses, fn(s) { s == "changes_requested" })
      let pending_count =
        list.length(list.filter(statuses, fn(s) { s == "pending" }))
      let summary = case changes_requested {
        True -> "Changes requested"
        False ->
          case approval_count {
            0 -> ""
            1 -> "1 approval"
            n -> int.to_string(n) <> " approvals"
          }
      }
      let pending = case pending_count {
        0 -> text("")
        1 -> p([attr.class("text-xs text-gh-muted")], [text("1 pending review")])
        n ->
          p([attr.class("text-xs text-gh-muted")], [
            text(int.to_string(n) <> " pending reviews"),
          ])
      }
      case summary {
        "" ->
          case pending_count {
            0 -> text("")
            _ -> pending
          }
        _ ->
          div([attr.class("space-y-1")], [
            p(
              [
                attr.class(case changes_requested {
                  True -> "text-xs font-semibold text-amber-700"
                  False -> "text-xs font-semibold text-emerald-700"
                }),
              ],
              [text(summary)],
            ),
            pending,
          ])
      }
    }
  }
}

fn tab_bar(active: Tab, pipeline: option.Option(Pipeline)) -> Element(Msg) {
  let tab_btn = fn(t: Tab, label: String, status: option.Option(String)) {
    let classes = case active == t {
      True -> components.comic_tab_active
      False -> components.comic_tab
    }
    let status_icon = case status {
      option.Some(state) -> ci_status.status_circle(state, "h-2.5 w-2.5", False)
      option.None -> text("")
    }
    button(
      [attr.type_("button"), attr.class(classes), event.on_click(TabChanged(t))],
      [
        span([attr.class("inline-flex items-center gap-2")], [
          status_icon,
          text(label),
        ]),
      ],
    )
  }
  let checks_status = case pipeline {
    option.Some(run) -> option.Some(run.state)
    option.None -> option.None
  }
  div([attr.class(components.comic_tabs)], [
    tab_btn(Conversation, "Conversation", option.None),
    tab_btn(Checks, "Checks", checks_status),
    tab_btn(Commits, "Commits", option.None),
    tab_btn(Changes, "Changes", option.None),
  ])
}

fn tab_content(model: Model, detail: MergeRequestDetail) -> Element(Msg) {
  case model.tab {
    Conversation -> conversation_tab(model, detail)
    Checks -> checks_tab(model)
    Commits -> commits_tab(model)
    Changes -> changes_tab(model, detail)
  }
}

type ConversationEvent {
  ConversationComment(MrComment)
  ConversationReview(MrReview)
}

fn conversation_event_time(event: ConversationEvent) -> String {
  case event {
    ConversationComment(comment) -> comment.created_at
    ConversationReview(review) -> review.submitted_at
  }
}

fn conversation_events(
  comments: List(MrComment),
  reviews: List(MrReview),
) -> List(ConversationEvent) {
  let comment_events = list.map(comments, ConversationComment)
  let review_events =
    reviews_for_timeline(reviews)
    |> list.map(ConversationReview)
  list.append(comment_events, review_events)
  |> list.sort(by: fn(a, b) {
    string.compare(conversation_event_time(a), conversation_event_time(b))
  })
}

/// Every approval / changes-requested transition is its own event; drop only
/// back-to-back repeats of the same verdict from the same reviewer.
fn reviews_for_timeline(reviews: List(MrReview)) -> List(MrReview) {
  let chronological =
    list.sort(reviews, by: fn(a, b) {
      string.compare(a.submitted_at, b.submitted_at)
    })
  list.fold(chronological, [], fn(acc: List(MrReview), review) {
    case list.last(acc) {
      Ok(prev) ->
        case prev.user_id == review.user_id && prev.state == review.state {
          True -> acc
          False -> list.append(acc, [review])
        }
      Error(_) -> [review]
    }
  })
}

fn conversation_tab(model: Model, detail: MergeRequestDetail) -> Element(Msg) {
  let mr = detail.merge_request
  let events = conversation_events(model.comments, detail.reviews)
  let event_count = list.length(events)
  let items =
    list.flatten([
      [opening_post(model, mr, event_count > 0)],
      list.index_map(events, fn(event, index) {
        conversation_event_item(model, event, index < event_count - 1)
      }),
      [conversation_comment_form(model)],
    ])
  ul([attr.class(timeline_list)], items)
}

fn conversation_event_item(
  model: Model,
  event: ConversationEvent,
  show_line: Bool,
) -> Element(Msg) {
  case event {
    ConversationComment(comment) ->
      conversation_comment_item(model, comment, show_line)
    ConversationReview(review) ->
      conversation_review_item(model, review, show_line)
  }
}

fn conversation_review_item(
  model: Model,
  review: MrReview,
  show_line: Bool,
) -> Element(Msg) {
  let #(body, show_body) = case review.body {
    option.Some(review_body) ->
      case string.trim(review_body) {
        "" -> #(text(""), False)
        trimmed -> #(
          unsafe_raw_html(
            "",
            "div",
            [attr.class("markdown-body text-sm")],
            markdown_body(
              trimmed,
              [],
              model.org_slug,
              model.repo_name,
            ),
          ),
          True,
        )
      }
    option.None -> #(text(""), False)
  }
  timeline_event_with_icon(
    icon: review_timeline_icon(review.state),
    header: event_header_text(
      review.reviewer_name,
      review_state_label(review.state),
      review.submitted_at,
    ),
    actions: text(""),
    body:,
    show_body:,
    show_line:,
  )
}

fn review_timeline_icon(state: String) -> Element(Msg) {
  case state {
    "approved" ->
      span(
        [
          attr.class(
            "comic-timeline-review-icon comic-timeline-review-icon-approved",
          ),
          attr.attribute("aria-hidden", "true"),
        ],
        [span([attr.class("comic-review-checkbox")], [text("✓")])],
      )
    "changes_requested" ->
      span(
        [
          attr.class(
            "comic-timeline-review-icon comic-timeline-review-icon-changes",
          ),
          attr.attribute("aria-hidden", "true"),
        ],
        [text("🍌")],
      )
    _ ->
      span(
        [
          attr.class("comic-timeline-review-icon"),
          attr.attribute("aria-hidden", "true"),
        ],
        [text("💬")],
      )
  }
}

fn opening_post(model: Model, mr: MergeRequest, has_more: Bool) -> Element(Msg) {
  let author = mr_author_label(mr)
  timeline_event_with_actions(
    initials: author_initials(author),
    header: event_header_text(
      author,
      "opened this merge request",
      mr.created_at,
    ),
    actions: description_actions(model, mr),
    body: mr_description_body(model, mr),
    show_line: has_more,
  )
}

fn mr_author_label(mr: MergeRequest) -> String {
  api.mr_author_label(mr)
}

fn can_edit_merge_request(model: Model, mr: MergeRequest) -> Bool {
  case mr.state {
    "open" -> {
      case model.viewer_user_id {
        option.None -> False
        option.Some(viewer) ->
          viewer == mr.author_user_id
          || list.any(model.org_members, fn(m) {
            m.user_id == viewer && { m.role == "owner" || m.role == "member" }
          })
      }
    }
    _ -> False
  }
}

fn description_actions(model: Model, mr: MergeRequest) -> Element(Msg) {
  case can_edit_merge_request(model, mr) {
    False -> text("")
    True ->
      div([attr.class("mr-event-menu")], [
        button(
          [
            attr.type_("button"),
            attr.class("mr-event-menu-trigger"),
            attr.title("Show options"),
            attr.aria_expanded(model.description_menu_open),
            attr.aria_haspopup("menu"),
            event.on_click(ToggleDescriptionMenu),
          ],
          [text("⋯")],
        ),
        case model.description_menu_open {
          True ->
            div([attr.class("mr-event-menu-dropdown"), attr.role("menu")], [
              button(
                [
                  attr.type_("button"),
                  attr.class("mr-event-menu-item"),
                  attr.role("menuitem"),
                  event.on_click(StartEditDescription),
                ],
                [text("Edit")],
              ),
            ])
          False -> text("")
        },
      ])
  }
}

fn description_edit_textarea(model: Model) -> Element(Msg) {
  memo([ref(model.edit_description_seed)], fn() {
    textarea(
      [
        attr.class(components.textarea <> " min-h-32 text-sm"),
        attr.autofocus(True),
        attr.disabled(model.saving),
        event.on_input(EditDescriptionChanged),
        event.on_keydown(fn(key) { DescriptionKeyPressed(key) }),
      ],
      model.edit_description,
    )
  })
}

fn description_edit_form(model: Model) -> Element(Msg) {
  form([event.on_submit(fn(_) { SaveEdit }), attr.class("space-y-2")], [
    description_edit_textarea(model),
    div([attr.class("flex justify-end gap-2")], [
      button(
        [
          attr.type_("button"),
          attr.class(components.btn_secondary),
          attr.disabled(model.saving),
          event.on_click(CancelEdit),
        ],
        [text("Cancel")],
      ),
      button(
        [
          attr.type_("submit"),
          attr.class(components.btn_primary),
          attr.disabled(model.saving),
        ],
        [text("Save")],
      ),
    ]),
  ])
}

fn mr_description_body(model: Model, mr: MergeRequest) -> Element(Msg) {
  case model.editing_description {
    True -> description_edit_form(model)
    False ->
      case mr.description {
        option.Some(d) ->
          unsafe_raw_html(
            "",
            "div",
            [attr.class("markdown-body text-sm")],
            markdown_body(d, [], model.org_slug, model.repo_name),
          )
        option.None ->
          p([attr.class("text-sm italic text-gh-muted")], [
            text("No description provided."),
          ])
      }
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

fn can_edit_comment(model: Model, comment: MrComment) -> Bool {
  case model.viewer_user_id {
    option.Some(id) if id == comment.author_user_id -> True
    _ -> False
  }
}

fn can_delete_comment(model: Model, comment: MrComment) -> Bool {
  case model.viewer_user_id {
    option.Some(id) if id == comment.author_user_id -> True
    _ -> viewer_is_owner(model)
  }
}

fn comment_actions(model: Model, c: MrComment) -> Element(Msg) {
  case can_edit_comment(model, c), can_delete_comment(model, c) {
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
}

fn comment_edit_form(model: Model) -> Element(Msg) {
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
}

fn conversation_comment_item(
  model: Model,
  c: MrComment,
  show_line: Bool,
) -> Element(Msg) {
  let author = api.comment_author_label(c)
  let editing = model.editing_comment_id == option.Some(c.id)
  let action_label = case api.comment_is_edited(c.created_at, c.updated_at) {
    True -> "commented (edited)"
    False -> "commented"
  }
  let header = case c.file_path, c.line {
    option.Some(f), option.Some(l) ->
      span([], [
        span([attr.class("font-semibold text-gh-ink")], [text(author)]),
        text(" commented on "),
        button(
          [
            attr.type_("button"),
            attr.class("font-semibold text-gh-accent hover:underline"),
            event.on_click(GoToLineComment(f, l)),
          ],
          [text(f <> ":" <> int.to_string(l))],
        ),
        text(" · " <> time_format.format_timestamp(c.created_at)),
      ])
    _, _ -> event_header_text(author, action_label, c.created_at)
  }
  let body = case editing {
    True -> comment_edit_form(model)
    False ->
      unsafe_raw_html(
        "",
        "div",
        [attr.class("markdown-body text-sm")],
        markdown_body(
          c.body,
          c.mentioned_usernames,
          model.org_slug,
          model.repo_name,
        ),
      )
  }
  timeline_event_with_actions(
    initials: author_initials(author),
    header:,
    actions: comment_actions(model, c),
    body:,
    show_line:,
  )
}

fn conversation_comment_form(model: Model) -> Element(Msg) {
  let anchor = case model.comment_file, model.comment_line {
    option.Some(f), option.Some(l) ->
      div(
        [
          attr.class(event_header <> " flex items-center justify-between gap-3"),
        ],
        [
          text("Comment on " <> f <> " line " <> int.to_string(l)),
          button(
            [
              attr.type_("button"),
              attr.class("font-bold text-gh-accent hover:underline"),
              event.on_click(CancelInlineComment),
            ],
            [text("Cancel")],
          ),
        ],
      )
    _, _ -> text("")
  }
  li([attr.class(timeline_item <> " pt-1")], [
    span([attr.class(avatar_class <> " opacity-60")], [text("?")]),
    div([attr.class("min-w-0 flex-1")], [
      form(
        [
          event.on_submit(fn(_) { SubmitComment }),
          attr.class("comic-event-card"),
        ],
        [
          anchor,
          textarea(
            [
              attr.class("comic-comment-textarea"),
              attr.placeholder("Leave a comment…"),
              attr.value(model.comment_body),
              event.on_input(CommentBodyChanged),
            ],
            "",
          ),
          div([attr.class("comic-comment-form-footer")], [
            button(
              [attr.type_("submit"), attr.class(components.btn_primary)],
              [
                text("Comment"),
              ],
            ),
          ]),
        ],
      ),
    ]),
  ])
}

fn timeline_event_with_actions(
  initials initials: String,
  header header: Element(Msg),
  actions actions: Element(Msg),
  body body: Element(Msg),
  show_line show_line: Bool,
) -> Element(Msg) {
  timeline_event_with_icon(
    icon: span([attr.class(avatar_class)], [text(initials)]),
    header:,
    actions:,
    body:,
    show_body: True,
    show_line:,
  )
}

fn timeline_event_with_icon(
  icon icon: Element(Msg),
  header header: Element(Msg),
  actions actions: Element(Msg),
  body body: Element(Msg),
  show_body show_body: Bool,
  show_line show_line: Bool,
) -> Element(Msg) {
  let line = case show_line {
    True -> span([attr.class(timeline_line)], [])
    False -> text("")
  }
  li([attr.class(timeline_item)], [
    line,
    icon,
    div([attr.class(event_card)], [
      div(
        [attr.class(event_header <> " flex items-start justify-between gap-3")],
        [
          header,
          actions,
        ],
      ),
      case show_body {
        True -> div([attr.class(event_body)], [body])
        False -> text("")
      },
    ]),
  ])
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

fn markdown_body(
  content: String,
  mentioned_usernames: List(String),
  org: String,
  repo: String,
) -> String {
  content
  |> markdown.to_html
  |> mentions.highlight(mentioned_usernames)
  |> issue_refs.link(org, repo)
}

fn commit_count_label(count: Int) -> String {
  case count {
    1 -> "1 commit"
    n -> int.to_string(n) <> " commits"
  }
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

fn commits_chronological(commits: List(MrCommit)) -> List(MrCommit) {
  list.reverse(commits)
}

fn commit_timeline_item(
  model: Model,
  c: MrCommit,
  is_last: Bool,
  copied: Bool,
) -> Element(Msg) {
  let line_class = case is_last {
    True -> "hidden"
    False -> "comic-timeline-line !left-[1.125rem] !top-9"
  }
  li([attr.class("relative flex gap-3 pb-6 last:pb-0")], [
    span([attr.class(line_class)], []),
    span(
      [attr.class("comic-timeline-avatar comic-timeline-avatar-sm")],
      [text(author_initials(c.author))],
    ),
    div([attr.class("min-w-0 flex-1 pt-0.5")], [
      div([attr.class("flex items-start justify-between gap-3")], [
        div([attr.class("min-w-0")], [
          a(
            [
              attr.href(routes.commit_tree_path(
                model.org_slug,
                model.repo_name,
                c.sha,
              )),
              attr.class(
                "text-sm font-semibold leading-snug text-gh-ink hover:text-gh-accent",
              ),
            ],
            [text(c.subject)],
          ),
          p([attr.class("mt-1 text-sm text-gh-muted")], [
            span([attr.class("font-medium text-gh-ink")], [text(c.author)]),
            text(
              " committed " <> time_format.format_commit_time(c.committed_at),
            ),
          ]),
        ]),
        button(
          [
            attr.type_("button"),
            attr.title("Copy full SHA"),
            attr.class("comic-sha-btn"),
            event.on_click(CopyCommitSha(c.sha)),
          ],
          [
            text(case copied {
              True -> "Copied"
              False -> short_sha(c.sha)
            }),
          ],
        ),
      ]),
    ]),
  ])
}

fn commits_tab(model: Model) -> Element(Msg) {
  case model.commits_loading, model.commits {
    True, [] -> components.loading_state()
    False, [] -> components.empty_state("No commits on this branch yet.")
    _, commits -> {
      let chronological = commits_chronological(commits)
      let count = list.length(chronological)
      let last_index = count - 1
      div([attr.class(components.card <> " !p-0 overflow-hidden")], [
        div([attr.class("comic-panel-header")], [
          p([attr.class("text-sm font-black uppercase text-gh-ink")], [
            text(commit_count_label(count)),
          ]),
          p([attr.class("text-xs text-gh-muted")], [
            text("Commits on the source branch, oldest first"),
          ]),
        ]),
        ol(
          [attr.class("relative list-none px-4 py-5 sm:px-6")],
          list.index_map(chronological, fn(c, index) {
            let copied = model.copied_commit_sha == option.Some(c.sha)
            commit_timeline_item(model, c, index == last_index, copied)
          }),
        ),
      ])
    }
  }
}

fn changes_tab(model: Model, detail: MergeRequestDetail) -> Element(Msg) {
  let mr = detail.merge_request
  let files = all_change_files(model)
  let review_section =
    review_actions_section(model, mr, detail.merge_check)
  case files {
    [] ->
      div([attr.class("space-y-4")], [
        review_section,
        components.empty_state("No file changes"),
      ])
    _ ->
      div([attr.class("space-y-4")], [
        review_section,
        div([attr.class(components.card <> " !p-0 overflow-hidden")], [
          div(
            [
              attr.class(
                "flex min-h-[32rem] max-h-[calc(100vh-12rem)] flex-col lg:flex-row",
              ),
            ],
            [
              file_sidebar(model, files),
              diff_panel(model),
            ],
          ),
        ]),
      ])
  }
}

fn diff_totals(files: List(DiffFile)) -> #(Int, Int) {
  list.fold(files, #(0, 0), fn(acc, f) {
    let #(additions, deletions) = acc
    #(additions + f.additions, deletions + f.deletions)
  })
}

fn changes_summary_label(count: Int) -> String {
  case count {
    1 -> "1 file changed"
    n -> int.to_string(n) <> " files changed"
  }
}

fn file_dir_and_name(path: String) -> #(String, String) {
  case list.reverse(string.split(path, on: "/")) {
    [] -> #("", path)
    [name, ..rest] -> #(string.join(list.reverse(rest), with: "/"), name)
  }
}

fn file_sidebar(model: Model, files: List(DiffFile)) -> Element(Msg) {
  let visible_files = case model.show_commented_files_only {
    True -> files_with_comments(model, files)
    False -> files
  }
  let commented_count = list.length(files_with_comments(model, files))
  let #(total_additions, total_deletions) = diff_totals(files)
  let summary = case model.show_commented_files_only {
    True -> commented_files_summary_label(list.length(visible_files))
    False -> changes_summary_label(list.length(files))
  }
  div([attr.class("comic-file-sidebar")], [
      div([attr.class("comic-panel-header")], [
        p([attr.class("text-sm font-black uppercase text-gh-ink")], [text(summary)]),
        case model.show_commented_files_only {
          False ->
            p([attr.class("mt-1 font-mono text-xs")], [
              span([attr.class("font-medium text-emerald-700")], [
                text("+" <> int.to_string(total_additions)),
              ]),
              text(" "),
              span([attr.class("font-medium text-red-700")], [
                text("-" <> int.to_string(total_deletions)),
              ]),
            ])
          True -> text("")
        },
        label(
          [
            attr.class(
              "mt-3 flex cursor-pointer items-center gap-2 text-xs text-gh-muted",
            ),
          ],
          [
            input([
              attr.type_("checkbox"),
              attr.checked(model.show_commented_files_only),
              attr.disabled(commented_count == 0),
              event.on_check(CommentedFilesFilterChanged),
            ]),
            text("Only files with comments"),
          ],
        ),
      ]),
      case visible_files {
        [] ->
          p([attr.class("px-4 py-6 text-center text-xs text-gh-muted")], [
            text("No changed files have review comments yet."),
          ])
        items ->
          ul(
            [
              attr.class(
                "list-none overflow-y-auto p-2 lg:max-h-[calc(100vh-16rem)] lg:flex-1",
              ),
            ],
            list.map(items, fn(f) { file_list_item(model, f) }),
          )
      },
    ],
  )
}

fn comment_count_for_file(comments: List(MrComment), path: String) -> Int {
  list.length(list.filter(comments, fn(c) { c.file_path == option.Some(path) }))
}

fn comment_count_label(count: Int) -> String {
  case count {
    1 -> "1 review comment"
    n -> int.to_string(n) <> " review comments"
  }
}

fn file_comment_indicator(count: Int) -> Element(Msg) {
  case count {
    0 -> text("")
    n ->
      span(
        [
          attr.class("comic-comment-count"),
          attr.title(comment_count_label(n)),
        ],
        [text(int.to_string(n))],
      )
  }
}

fn file_row_class(selected: Bool, is_conflict: Bool) -> String {
  let base = "comic-file-row"
  case selected, is_conflict {
    True, True -> base <> " comic-file-row-active comic-file-row-conflict"
    True, False -> base <> " comic-file-row-active"
    False, True -> base <> " comic-file-row-conflict"
    False, False -> base
  }
}

fn file_list_item(model: Model, f: DiffFile) -> Element(Msg) {
  let selected = model.selected_file == option.Some(f.path)
  let is_conflict = is_conflict_file(model, f.path)
  let comment_count = comment_count_for_file(model.comments, f.path)
  let #(dir, name) = file_dir_and_name(f.path)
  let row_class = file_row_class(selected, is_conflict)
  li([], [
    button(
      [
        attr.type_("button"),
        attr.class(row_class),
        event.on_click(SelectFile(f.path)),
      ],
      [
        div([attr.class("min-w-0 flex-1")], [
          p([attr.class("flex min-w-0 items-center gap-1.5")], [
            span([attr.class("truncate text-sm font-medium text-gh-ink")], [
              text(name),
            ]),
            case is_conflict {
              True ->
                span([attr.class("comic-conflict-badge")], [text("Conflict")])
              False -> text("")
            },
            file_comment_indicator(comment_count),
          ]),
          case dir {
            "" -> text("")
            _ -> p([attr.class("truncate text-xs text-gh-muted")], [text(dir)])
          },
        ]),
        file_change_stats(f.additions, f.deletions),
      ],
    ),
  ])
}

fn file_change_stats(additions: Int, deletions: Int) -> Element(Msg) {
  div(
    [
      attr.class(
        "flex shrink-0 flex-col items-end gap-0.5 font-mono text-xs leading-none",
      ),
    ],
    [
      case additions {
        0 -> text("")
        n ->
          span([attr.class("text-emerald-700")], [text("+" <> int.to_string(n))])
      },
      case deletions {
        0 -> text("")
        n -> span([attr.class("text-red-700")], [text("-" <> int.to_string(n))])
      },
    ],
  )
}

fn diff_panel(model: Model) -> Element(Msg) {
  div([attr.class("comic-diff-panel")], [
    diff_panel_header(model),
    div([attr.class("diff-panel-scroll min-h-0 flex-1 overflow-auto")], [
      diff_panel_body(model),
    ]),
  ])
}

fn diff_panel_header(model: Model) -> Element(Msg) {
  div([attr.class("comic-panel-header")], [
    case model.selected_file {
      option.None ->
        p([attr.class("text-sm text-gh-muted")], [
          text("Select a file to view changes"),
        ])
      option.Some(path) -> {
        let comment_count = comment_count_for_file(model.comments, path)
        let conflict_label = case is_conflict_file(model, path) {
          True -> span([attr.class("comic-conflict-badge")], [text("Conflict")])
          False -> text("")
        }
        div([attr.class("flex min-w-0 items-center justify-between gap-3")], [
          div([attr.class("flex min-w-0 items-center gap-2")], [
            p(
              [attr.class("truncate font-mono text-sm font-medium text-gh-ink")],
              [
                text(path),
              ],
            ),
            conflict_label,
          ]),
          file_comment_indicator(comment_count),
        ])
      }
    },
  ])
}

fn diff_panel_body(model: Model) -> Element(Msg) {
  case model.selected_file {
    option.None ->
      div(
        [
          attr.class(
            "flex min-h-[20rem] items-center justify-center px-6 py-12 text-center",
          ),
        ],
        [
          p([attr.class("max-w-sm text-sm text-gh-muted")], [
            text(
              "Choose a file from the list to see what changed in this merge request.",
            ),
          ]),
        ],
      )
    option.Some(_path) ->
      case model.loading_patch {
        True ->
          div([attr.class("comic-loading-state flex min-h-[20rem]")], [
            components.loading_spinner(),
          ])
        False ->
          case model.conflict_file {
            option.Some(file) -> conflict_file_view(model, file)
            option.None ->
              case model.patch {
                option.None ->
                  div(
                    [
                      attr.class(
                        "flex min-h-[20rem] items-center justify-center",
                      ),
                    ],
                    [
                      p([attr.class("text-sm text-gh-muted")], [
                        text("No diff available"),
                      ]),
                    ],
                  )
                option.Some(patch) -> patch_view(model, patch)
              }
          }
      }
  }
}

fn conflict_file_view(model: Model, file: ConflictFile) -> Element(Msg) {
  let links =
    conflict.FileLinks(
      target_href: conflict_branch_file_href(
        model,
        file.path,
        file.target_branch,
        file.target.missing,
      ),
      source_href: conflict_branch_file_href(
        model,
        file.path,
        file.source_branch,
        file.source.missing,
      ),
    )
  div([attr.class("min-h-full bg-white")], [
    div(
      [
        attr.class(
          "border-b border-amber-200 bg-amber-50 px-4 py-2 text-xs text-amber-950",
        ),
      ],
      [
        text(
          "Both branches changed this file. Conflicting regions are highlighted below - use the jump links to scroll to each one.",
        ),
      ],
    ),
    conflict.side_by_side_highlighted(
      file.target_branch,
      conflict.Side(
        content: file.target.content,
        binary: file.target.binary,
        missing: file.target.missing,
      ),
      file.source_branch,
      conflict.Side(
        content: file.source.content,
        binary: file.source.binary,
        missing: file.source.missing,
      ),
      links,
    ),
  ])
}

fn conflict_branch_file_href(
  model: Model,
  path: String,
  branch: String,
  missing: Bool,
) -> option.Option(String) {
  case missing {
    True -> option.None
    False ->
      option.Some(routes.repo_blob_path(
        model.org_slug,
        model.repo_name,
        branch,
        path,
      ))
  }
}

fn comments_on_line(
  comments: List(MrComment),
  file_path: String,
  line: Int,
) -> List(MrComment) {
  list.filter(comments, fn(c) {
    c.file_path == option.Some(file_path) && c.line == option.Some(line)
  })
}

fn inline_comment_active(model: Model, file_path: String, line: Int) -> Bool {
  model.comment_file == option.Some(file_path)
  && model.comment_line == option.Some(line)
}

fn inline_comment_composer(
  _file_path: String,
  line: Int,
  model: Model,
) -> Element(Msg) {
  div([attr.class("diff-inline-composer")], [
    form([event.on_submit(fn(_) { SubmitComment }), attr.class("space-y-2")], [
      textarea(
        [
          attr.class(components.textarea <> " !min-h-[4rem]"),
          attr.placeholder(
            "Leave a comment on line " <> int.to_string(line) <> "…",
          ),
          attr.value(model.comment_body),
          event.on_input(CommentBodyChanged),
        ],
        "",
      ),
      div([attr.class("flex justify-end gap-2")], [
        button(
          [
            attr.type_("button"),
            attr.class(components.btn_secondary),
            event.on_click(CancelInlineComment),
          ],
          [text("Cancel")],
        ),
        button([attr.type_("submit"), attr.class(components.btn_primary)], [
          text("Add review comment"),
        ]),
      ]),
    ]),
  ])
}

fn inline_thread_item(model: Model, c: MrComment) -> Element(Msg) {
  let editing = model.editing_comment_id == option.Some(c.id)
  let edited_suffix = case api.comment_is_edited(c.created_at, c.updated_at) {
    True -> " (edited)"
    False -> ""
  }
  div([attr.class("diff-inline-thread")], [
    div([attr.class("flex items-start justify-between gap-2")], [
      p([attr.class("text-xs text-gh-muted")], [
        text(
          api.comment_author_label(c)
            <> edited_suffix
            <> " · "
            <> time_format.format_timestamp(c.created_at),
        ),
      ]),
      comment_actions(model, c),
    ]),
    case editing {
      True -> comment_edit_form(model)
      False ->
        p([attr.class("mt-1 text-sm text-gh-ink whitespace-pre-wrap")], [
          text(c.body),
        ])
    },
  ])
}

fn patch_line_row(
  model: Model,
  file_path: String,
  line: diff_view.DiffLine,
) -> Element(Msg) {
  case line.kind {
    diff_view.Meta ->
      li([], [div([attr.class("diff-meta")], [text(line.text)])])
    _ -> {
      let row_class = diff_view.row_class(line)
      let line_comments = case diff_view.commentable_new_line(line) {
        option.Some(n) -> comments_on_line(model.comments, file_path, n)
        option.None -> []
      }
      let has_comments = line_comments != []
      let row_extra = case has_comments {
        True -> " diff-row-has-comments"
        False -> ""
      }
      let gutter = case diff_view.commentable_new_line(line) {
        option.Some(n) -> int.to_string(n)
        option.None -> ""
      }
      let comment_btn = case diff_view.commentable_new_line(line) {
        option.Some(n) ->
          button(
            [
              attr.type_("button"),
              attr.class("diff-comment-gutter"),
              attr.title("Add comment on line " <> int.to_string(n)),
              event.on_click(CommentOnLine(file_path, n)),
            ],
            [text("+")],
          )
        option.None -> text("")
      }
      let composer = case diff_view.commentable_new_line(line) {
        option.Some(n) ->
          case inline_comment_active(model, file_path, n) {
            True -> inline_comment_composer(file_path, n, model)
            False -> text("")
          }
        option.None -> text("")
      }
      let threads = case line_comments {
        [] -> text("")
        items ->
          div([], list.map(items, fn(c) { inline_thread_item(model, c) }))
      }
      let highlight_extra = case diff_view.commentable_new_line(line) {
        option.Some(n) ->
          case
            mr_diff_line.diff_line_highlighted(
              model.pending_diff_line,
              file_path,
              n,
            )
          {
            True -> " diff-line-highlight"
            False -> ""
          }
        option.None -> ""
      }
      let gutter_cell = case diff_view.commentable_new_line(line) {
        option.Some(n) -> {
          let dom_id = mr_diff_line.diff_line_dom_id(file_path, n)
          let line_url =
            routes.mr_changes_line_path(
              model.org_slug,
              model.repo_name,
              model.number,
              file_path,
              n,
            )
          #(
            dom_id,
            a(
              [
                attr.href(line_url),
                attr.class("diff-lineno diff-lineno-link"),
                attr.title("Link to line " <> int.to_string(n)),
              ],
              [text(gutter)],
            ),
          )
        }
        option.None -> #("", span([attr.class("diff-lineno")], [text(gutter)]))
      }
      let #(row_id, lineno) = gutter_cell
      let scroll_attrs = case diff_view.commentable_new_line(line) {
        option.Some(n) ->
          case model.scroll_to_line {
            option.Some(target) if target == n -> [
              attr.attribute("tabindex", "-1"),
              attr.attribute("autofocus", "autofocus"),
            ]
            _ -> []
          }
        option.None -> []
      }
      let row_attrs = case row_id {
        "" ->
          list.append(
            [
              attr.class(
                row_class <> " diff-row group" <> row_extra <> highlight_extra,
              ),
            ],
            scroll_attrs,
          )
        id ->
          list.append(
            [
              attr.id(id),
              attr.class(
                row_class <> " diff-row group" <> row_extra <> highlight_extra,
              ),
            ],
            scroll_attrs,
          )
      }
      li([], [
        div(row_attrs, [
          lineno,
          span([attr.class("diff-code")], [text(line.text)]),
          comment_btn,
        ]),
        threads,
        composer,
      ])
    }
  }
}

fn patch_view(model: Model, patch: String) -> Element(Msg) {
  let file_path = case model.selected_file {
    option.Some(path) -> path
    option.None -> ""
  }
  let lines = diff_view.parse_patch(patch)
  let rows =
    list.map(lines, fn(line) { patch_line_row(model, file_path, line) })
  div([attr.class("bg-white")], [
    ul([attr.class("diff-patch overflow-x-auto")], rows),
  ])
}
