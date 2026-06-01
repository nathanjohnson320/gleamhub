import api.{
  type DiffFile, type MergeCheck, type MergeRequest, type MergeRequestDetail,
  type MrComment, type MrCommit, type Pipeline,
}
import ci_log
import ci_status
import components
import config.{type Config}
import gleam/int
import gleam/list
import gleam/option
import gleam/json
import gleam/string
import gleam/uri
import lustre/attribute as attr
import lustre/effect.{type Effect, batch, from, none}
import lustre/element.{type Element, text, unsafe_raw_html}
import lustre/element/html.{
  a, button, div, form, h2, h3, input, label, li, ol, option, p, select, span,
  textarea, ul,
}
import lustre/event
import lustre_http
import clipboard
import markdown
import diff_view
import pipeline_stream
import poll
import routes
import time_format

const pipeline_poll_ms = 5000

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
    comment_body: String,
    comment_file: option.Option(String),
    comment_line: option.Option(Int),
    show_merge_confirm: Bool,
    merge_method: api.MergeMethod,
    delete_source_branch: Bool,
    loading: Bool,
    commits_loading: Bool,
    copied_commit_sha: option.Option(String),
    loading_patch: Bool,
    error: option.Option(String),
    pipeline_stream_stop: option.Option(fn() -> Nil),
  )
}

pub type Msg {
  DetailLoaded(Result(MergeRequestDetail, lustre_http.HttpError))
  DetailPolled(Result(MergeRequestDetail, lustre_http.HttpError))
  CommentsLoaded(Result(List(MrComment), lustre_http.HttpError))
  CommitsLoaded(Result(List(MrCommit), lustre_http.HttpError))
  DiffLoaded(Result(List(DiffFile), lustre_http.HttpError))
  PatchLoaded(Result(String, lustre_http.HttpError))
  TabChanged(Tab)
  CommentBodyChanged(String)
  CommentOnLine(String, Int)
  CancelInlineComment
  GoToLineComment(String, Int)
  SubmitComment
  CommentPosted(Result(MrComment, lustre_http.HttpError))
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
  RerunChecks
  ChecksRerun(Result(api.Pipeline, lustre_http.HttpError))
  PipelineStreamStarted(fn() -> Nil)
  PipelineStreamUpdate(String)
  PipelineStreamError
  RefreshDetail
  HashTabChanged(String)
}

@external(javascript, "../mr_tab_ffi.js", "read_mr_tab_hash")
fn read_mr_tab_hash() -> String

@external(javascript, "../mr_tab_ffi.js", "set_mr_tab_hash")
fn set_mr_tab_hash(segment: String) -> Nil

@external(javascript, "../mr_tab_ffi.js", "subscribe_mr_tab_hash")
fn subscribe_mr_tab_hash(on_change: fn(String) -> Nil) -> Nil

fn tab_hash_name(tab: Tab) -> String {
  case tab {
    Conversation -> "conversation"
    Checks -> "checks"
    Commits -> "commits"
    Changes -> "changes"
  }
}

fn tab_from_hash_name(name: String) -> Tab {
  case string.lowercase(name) {
    "checks" -> Checks
    "commits" -> Commits
    "changes" -> Changes
    _ -> Conversation
  }
}

pub fn init(org_slug: String, repo_name: String, number: Int) -> Model {
  let tab = tab_from_hash_name(read_mr_tab_hash())
  Model(
    org_slug:,
    repo_name:,
    number:,
    tab:,
    detail: option.None,
    comments: [],
    commits: [],
    diff_files: [],
    selected_file: option.None,
    patch: option.None,
    comment_body: "",
    comment_file: option.None,
    comment_line: option.None,
    show_merge_confirm: False,
    merge_method: api.MergeCommit,
    delete_source_branch: True,
    loading: True,
    commits_loading: False,
    copied_commit_sha: option.None,
    loading_patch: False,
    error: option.None,
    pipeline_stream_stop: option.None,
  )
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

fn pipeline_poll_effect(model: Model) -> Effect(Msg) {
  case model.tab, pipeline_is_in_progress(detail_pipeline(model)) {
    Checks, True -> poll.after_ms(RefreshDetail, pipeline_poll_ms)
    _, _ -> none()
  }
}

fn pipeline_live_effect(model: Model, config: Config) -> Effect(Msg) {
  batch([
    pipeline_stream_effect(model, config),
    pipeline_poll_effect(model),
  ])
}

fn pipeline_stream_effect(model: Model, config: Config) -> Effect(Msg) {
  case model.tab, model.detail, config.token {
    Checks, option.Some(_), option.Some(token) ->
      case pipeline_is_in_progress(detail_pipeline(model)) {
        True ->
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
        False -> none()
      }
    _, _, _ -> none()
  }
}

fn apply_pipeline_update(model: Model, json: String) -> Model {
  case json.parse(json, api.pipeline_decoder()) {
    Ok(pipeline) -> {
      let model =
        Model(
          ..model,
          detail: option.map(model.detail, fn(d) {
            api.MergeRequestDetail(..d, pipeline: option.Some(pipeline))
          }),
        )
      case pipeline_is_in_progress(option.Some(pipeline)) {
        True -> model
        False -> stop_pipeline_stream(model)
      }
    }
    Error(_) -> model
  }
}

fn pipeline_is_in_progress(pipeline: option.Option(Pipeline)) -> Bool {
  case pipeline {
    option.Some(run) -> run.state == "running" || run.state == "queued"
    option.None -> False
  }
}

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  let base = api_base(config, model)
  batch([
    from(fn(dispatch) {
      subscribe_mr_tab_hash(fn(name) { dispatch(HashTabChanged(name)) })
    }),
    load_detail(config, model),
    lustre_http.get(
      config,
      base <> "/comments",
      lustre_http.expect_json(api.mr_comments_decoder(), CommentsLoaded),
    ),
    tab_load(config, model, model.tab),
  ])
}

fn tab_change(config: Config, model: Model, tab: Tab, sync_hash: Bool) -> #(
  Model,
  Effect(Msg),
) {
  let _ = case sync_hash {
    True -> set_mr_tab_hash(tab_hash_name(tab))
    False -> Nil
  }
  let commits_loading = tab == Commits && model.commits == []
  let clear_inline = case tab {
    Conversation | Checks | Commits -> True
    Changes -> False
  }
  let model =
    stop_pipeline_stream(model)
    |> fn(m) {
      Model(
        ..m,
        tab:,
        commits_loading:,
        comment_file: case clear_inline {
          True -> option.None
          False -> m.comment_file
        },
        comment_line: case clear_inline {
          True -> option.None
          False -> m.comment_line
        },
        comment_body: case clear_inline {
          True -> ""
          False -> m.comment_body
        },
      )
    }
  let live_effect = case tab {
    Checks -> pipeline_live_effect(model, config)
    _ -> none()
  }
  #(model, batch([tab_load(config, model, tab), live_effect]))
}

fn tab_load(config: Config, model: Model, tab: Tab) -> Effect(Msg) {
  let base = api_base(config, model)
  case tab {
    Conversation | Checks -> none()
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
      let model =
        stop_pipeline_stream(model)
        |> fn(m) {
          Model(
            ..m,
            detail: option.Some(d),
            loading: False,
            error: option.None,
          )
        }
      #(model, pipeline_live_effect(model, config))
    }
    RefreshDetail -> #(
      model,
      lustre_http.get(
        config,
        api_base(config, model),
        lustre_http.expect_json(
          api.merge_request_detail_decoder(),
          DetailPolled,
        ),
      ),
    )
    DetailPolled(Ok(d)) -> #(
      Model(
        ..model,
        detail: option.Some(d),
        error: option.None,
      ),
      pipeline_poll_effect(Model(..model, detail: option.Some(d))),
    )
    DetailPolled(Error(_)) -> #(model, none())
    DetailLoaded(Error(_)) -> #(
      Model(..model, loading: False, error: option.Some("Failed to load merge request")),
      none(),
    )
    CommentsLoaded(Ok(comments)) -> #(
      Model(..model, comments:),
      none(),
    )
    CommentsLoaded(Error(_)) -> #(model, none())
    CommitsLoaded(Ok(commits)) -> #(
      Model(..model, commits:, commits_loading: False),
      none(),
    )
    CommitsLoaded(Error(_)) -> #(
      Model(..model, commits_loading: False, error: option.Some("Failed to load commits")),
      none(),
    )
    DiffLoaded(Ok(files)) -> #(
      Model(..model, diff_files: files),
      none(),
    )
    DiffLoaded(Error(_)) -> #(
      Model(..model, error: option.Some("Failed to load diff")),
      none(),
    )
    PatchLoaded(Ok(patch)) -> #(
      Model(..model, patch: option.Some(patch), loading_patch: False),
      none(),
    )
    PatchLoaded(Error(_)) -> #(
      Model(..model, loading_patch: False, error: option.Some("Failed to load patch")),
      none(),
    )
    TabChanged(tab) -> tab_change(config, model, tab, True)
    HashTabChanged(name) -> {
      let tab = tab_from_hash_name(name)
      case tab == model.tab {
        True -> #(model, none())
        False -> tab_change(config, model, tab, False)
      }
    }
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
      Model(..model, comment_file: option.None, comment_line: option.None, comment_body: ""),
      none(),
    )
    GoToLineComment(file, line) -> #(
      Model(
        ..model,
        tab: Changes,
        selected_file: option.Some(file),
        comment_file: option.Some(file),
        comment_line: option.Some(line),
        patch: option.None,
        loading_patch: True,
      ),
      lustre_http.get(
        config,
        api_base(config, model)
          <> "/diff?path="
          <> uri_encode(file),
        lustre_http.expect_json(api.diff_patch_decoder(), PatchLoaded),
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
    SelectFile(path) -> #(
      Model(..model, selected_file: option.Some(path), patch: option.None, loading_patch: True),
      lustre_http.get(
        config,
        api_base(config, model)
          <> "/diff?path="
          <> uri_encode(path),
        lustre_http.expect_json(api.diff_patch_decoder(), PatchLoaded),
      ),
    )
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
          api.MergeRequestDetail(
            merge_request: mr,
            merge_check: d.merge_check,
            pipeline: d.pipeline,
          )
        }),
        error: option.None,
      ),
      lustre_http.get(
        config,
        api_base(config, model),
        lustre_http.expect_json(api.merge_request_detail_decoder(), DetailLoaded),
      ),
    )
    Merged(Error(lustre_http.OtherError(409, _))) -> #(
      Model(..model, error: option.Some("Merge failed: conflicts. Resolve on the branch and try again.")),
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
          api.MergeRequestDetail(
            merge_request: mr,
            merge_check: d.merge_check,
            pipeline: d.pipeline,
          )
        }),
      ),
      none(),
    )
    Closed(Error(_)) -> #(
      Model(..model, error: option.Some("Could not close merge request")),
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
      #(updated, pipeline_live_effect(updated, config))
    }
    PipelineStreamStarted(stop) -> #(
      Model(..model, pipeline_stream_stop: option.Some(stop)),
      pipeline_poll_effect(Model(..model, pipeline_stream_stop: option.Some(stop))),
    )
    PipelineStreamUpdate(json) -> #(
      apply_pipeline_update(model, json),
      none(),
    )
    PipelineStreamError -> #(
      stop_pipeline_stream(model),
      pipeline_poll_effect(model),
    )
    ChecksRerun(Error(_)) -> #(
      Model(..model, error: option.Some("Could not re-run checks")),
      none(),
    )
  }
}

fn uri_encode(s: String) -> String {
  uri.percent_encode(s)
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
          True -> components.empty_state("Loading…")
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
  let title =
    "#"
    <> int.to_string(mr.number)
    <> " "
    <> mr.title
  div([attr.class(components.page <> " max-w-5xl")], [
    components.breadcrumb_back(
      routes.mr_list_path(model.org_slug, model.repo_name),
      "Merge requests",
    ),
    div([attr.class("mb-4 flex flex-wrap items-start justify-between gap-3")], [
      div([], [
        h2([attr.class("text-2xl font-bold text-gh-ink")], [text(title)]),
        p([attr.class("mt-1 text-sm text-gh-muted")], [
          text(mr.source_branch <> " → " <> mr.target_branch <> " · " <> mr.state),
        ]),
        merge_status_banner(model, mr, detail.merge_check, detail.pipeline),
      ]),
      action_buttons(model, mr, detail.merge_check, detail.pipeline),
    ]),
    error,
    tab_bar(model.tab, detail.pipeline),
    tab_content(model, detail),
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
    "closed" ->
      p([attr.class("mt-2 rounded-lg bg-slate-100 px-3 py-2 text-sm text-slate-700")], [
        text("Closed without merging."),
      ])
    _ -> merge_check_banner(check, pipeline)
  }
}

fn merged_banner(model: Model, mr: MergeRequest) -> Element(Msg) {
  let merge_ref = case mr.merge_commit_sha {
    option.Some(sha) ->
      a(
        [
          attr.href(routes.commit_tree_path(model.org_slug, model.repo_name, sha)),
          attr.class("font-mono font-semibold text-violet-800 hover:underline"),
        ],
        [text(short_sha(sha))],
      )
    option.None -> text("")
  }
  let merged_time = case mr.merged_at {
    option.Some(at) -> " · " <> time_format.format_commit_time(at)
    option.None -> ""
  }
  p([attr.class("mt-2 rounded-lg bg-violet-50 px-3 py-2 text-sm text-violet-950")], [
    text("Merged " <> mr.source_branch <> " into " <> mr.target_branch),
    text(merged_time <> " · "),
    merge_ref,
  ])
}

fn merge_check_banner(
  check: MergeCheck,
  pipeline: option.Option(Pipeline),
) -> Element(Msg) {
  case check.mergeable, pipeline {
    True, _ -> text("")
    False, option.Some(_) ->
      case is_ci_merge_message(check.message) {
        True -> text("")
        False ->
          p([attr.class("mt-2 rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-900")], [
            text(check.message),
          ])
      }
    False, option.None ->
      p([attr.class("mt-2 rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-900")], [
        text(check.message),
      ])
  }
}

fn is_ci_merge_message(message: String) -> Bool {
  case message {
    "Checks running"
    | "Checks failed"
    | "Checks stale — push to re-run"
    | "Checks incomplete"
    | "CI not configured" -> True
    _ -> False
  }
}

fn pipeline_status_detail(pipeline: Pipeline) -> String {
  case pipeline.state {
    "running" -> "In progress — running Dagger pipeline…"
    "queued" -> "Waiting for CI worker…"
    "success" -> "Completed successfully"
    "failure" -> "Failed"
    "skipped" -> "No CI module configured"
    _ -> pipeline.state
  }
}

fn checks_status_circle(state: String, size: String, animated: Bool) -> Element(Msg) {
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

fn checks_tab(detail: MergeRequestDetail) -> Element(Msg) {
  case detail.pipeline {
    option.None ->
      div([attr.class(components.card)], [
        p([attr.class("text-sm text-gh-muted")], [
          text(checks_summary(option.None)),
        ]),
        p([attr.class("mt-2 text-sm text-gh-muted")], [
          text("Use Re-run checks above after pushing a Dagger module (e.g. ci/dagger.json)."),
        ]),
      ])
    option.Some(run) -> {
      let module_name = case run.module_path {
        option.Some(path) -> path
        option.None -> "ci"
      }
      div([attr.class(components.card)], [
        p([attr.class("mb-4 text-sm font-medium text-gh-ink")], [
          text(checks_summary(option.Some(run))),
        ]),
        div(
          [
            attr.class(
              "flex items-start gap-4 rounded-lg border border-slate-100 bg-slate-50/60 px-4 py-3",
            ),
          ],
          [
            checks_status_circle(run.state, "mt-0.5 h-4 w-4", True),
            div([attr.class("min-w-0 flex-1")], [
              p([attr.class("text-sm font-semibold text-gh-ink")], [text(module_name)]),
              p([attr.class("mt-0.5 text-sm text-gh-muted")], [
                text(pipeline_status_detail(run)),
              ]),
              p([attr.class("mt-1 font-mono text-xs text-gh-muted")], [
                text(short_sha(run.commit_sha)),
                case run.module_path {
                  option.Some(path) -> text(" · " <> path)
                  option.None -> text("")
                },
              ]),
              pipeline_log_panel(run),
            ]),
          ],
        ),
        case pipeline_is_in_progress(option.Some(run)) {
          True ->
            p([attr.class("mt-3 text-xs text-gh-muted")], [
              text("Live updates while checks are in progress."),
            ])
          False -> text("")
        },
      ])
    }
  }
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
    content ->
      unsafe_raw_html(
        "",
        "pre",
        [
          attr.class(
            "mt-3 max-h-96 overflow-auto whitespace-pre-wrap rounded-lg bg-slate-950 p-3 font-mono text-xs leading-relaxed text-slate-100",
          ),
        ],
        ci_log.ansi_to_html(content),
      )
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
  }
}

const action_size = "!h-10 shrink-0"

const action_select =
  action_size
  <> " rounded-lg border border-slate-200 bg-white text-sm text-gh-ink shadow-sm"

fn merge_method_select(model: Model) -> Element(Msg) {
  select(
    [
      attr.class(
        components.input
        <> " "
        <> action_select
        <> " !w-auto !min-w-[11rem] !py-0",
      ),
      event.on_change(fn(value) {
        case value {
          "squash" -> MergeMethodChanged(api.Squash)
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
      attr.class(
        "absolute right-0 top-full z-40 mt-2 w-[min(18rem,calc(100vw-2rem))] rounded-xl border border-slate-200 bg-white p-4 shadow-xl ring-1 ring-slate-900/10",
      ),
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
          input(
            [
              attr.type_("checkbox"),
              attr.checked(model.delete_source_branch),
              event.on_check(DeleteSourceBranchChanged),
            ],
          ),
          text("Delete branch " <> mr.source_branch),
        ],
      ),
      div([attr.class("flex gap-2")], [
        button(
          [
            attr.type_("button"),
            attr.class(
              components.btn_secondary <> " " <> action_size <> " min-w-0 flex-1 !px-3",
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
              <> " min-w-0 flex-1 !border-transparent !bg-gh-accent !px-3 !text-white hover:!bg-violet-700",
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

fn action_buttons(
  model: Model,
  mr: MergeRequest,
  check: MergeCheck,
  pipeline: option.Option(Pipeline),
) -> Element(Msg) {
  let checks_busy = pipeline_is_in_progress(pipeline)
  case mr.state {
    "open" ->
      div([attr.class("relative w-full shrink-0 sm:w-auto")], [
        div(
          [
            attr.class(
              "inline-flex w-full flex-wrap items-center justify-end gap-2 rounded-xl border border-slate-200/80 bg-slate-50/80 p-2 sm:w-auto",
            ),
          ],
          [
            span([attr.class("hidden pl-1 text-xs font-medium text-gh-muted sm:inline")], [
              text("Merge as"),
            ]),
            merge_method_select(model),
            button(
              [
                attr.type_("button"),
                attr.class(components.btn_secondary <> " " <> action_size <> " !px-4"),
                attr.disabled(checks_busy),
                attr.title(case checks_busy {
                  True -> "Wait for the current check run to finish"
                  False -> ""
                }),
                event.on_click(RerunChecks),
              ],
              [text("Re-run checks")],
            ),
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
                      <> " !border-transparent !bg-gh-accent !px-5 !text-white hover:!bg-violet-700",
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
                    attr.class(components.btn_secondary <> " " <> action_size <> " !px-4"),
                    event.on_click(CancelMergeConfirm),
                  ],
                  [text("Cancel")],
                )
            },
          ],
        ),
        case model.show_merge_confirm {
          False -> text("")
          True -> merge_confirm_popover(model, mr, check)
        },
      ])
    _ -> text("")
  }
}

fn tab_bar(active: Tab, pipeline: option.Option(Pipeline)) -> Element(Msg) {
  let tab_btn = fn(t: Tab, label: String, status: option.Option(String)) {
    let classes = case active == t {
      True -> "border-b-2 border-gh-accent px-4 py-2 text-sm font-semibold text-gh-accent"
      False ->
        "border-b-2 border-transparent px-4 py-2 text-sm font-medium text-gh-muted hover:text-gh-ink"
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
  div([attr.class("mb-4 flex border-b border-slate-200")], [
    tab_btn(Conversation, "Conversation", option.None),
    tab_btn(Checks, "Checks", checks_status),
    tab_btn(Commits, "Commits", option.None),
    tab_btn(Changes, "Changes", option.None),
  ])
}

fn tab_content(model: Model, detail: MergeRequestDetail) -> Element(Msg) {
  case model.tab {
    Conversation -> conversation_tab(model, detail)
    Checks -> checks_tab(detail)
    Commits -> commits_tab(model)
    Changes -> changes_tab(model)
  }
}

fn conversation_tab(model: Model, detail: MergeRequestDetail) -> Element(Msg) {
  let mr = detail.merge_request
  let desc = case mr.description {
    option.Some(d) -> div([attr.class(components.card <> " mb-4")], [
      unsafe_raw_html("", "div", [attr.class("markdown-body text-sm")], markdown_body(d)),
    ])
    option.None -> text("")
  }
  let anchor = case model.comment_file, model.comment_line {
    option.Some(f), option.Some(l) ->
      p([attr.class("mb-2 text-sm text-gh-muted")], [
        text("Comment on " <> f <> " line " <> int.to_string(l)),
      ])
    _, _ -> text("")
  }
  div([], [
    desc,
    comments_list(model.comments),
    div([attr.class(components.card <> " mt-4")], [
      anchor,
      form(
        [event.on_submit(fn(_) { SubmitComment }), attr.class("space-y-3")],
        [
          textarea(
            [
              attr.class(components.textarea),
              attr.placeholder("Leave a comment…"),
              attr.value(model.comment_body),
              event.on_input(CommentBodyChanged),
            ],
            "",
          ),
          button([attr.type_("submit"), attr.class(components.btn_primary)], [
            text("Comment"),
          ]),
        ],
      ),
    ]),
  ])
}

fn markdown_body(content: String) -> String {
  markdown.to_html(content)
}

fn comments_list(comments: List(MrComment)) -> Element(Msg) {
  case comments {
    [] -> div([attr.class(components.card)], [text("No comments yet.")])
    items ->
      div([attr.class(components.card)], [
        ul([attr.class("space-y-4")], list.map(items, comment_item)),
      ])
  }
}

fn comment_item(c: MrComment) -> Element(Msg) {
  let meta = case c.file_path, c.line {
    option.Some(f), option.Some(l) ->
      button(
        [
          attr.type_("button"),
          attr.class("text-gh-accent hover:underline"),
          event.on_click(GoToLineComment(f, l)),
        ],
        [text(" on " <> f <> ":" <> int.to_string(l))],
      )
    _, _ -> text("")
  }
  li([], [
    p([attr.class("text-xs text-gh-muted")], [
      span([attr.class("font-medium text-gh-ink")], [
        text(api.comment_author_label(c)),
      ]),
      text(" · " <> c.created_at),
      meta,
    ]),
    unsafe_raw_html(
      "",
      "div",
      [attr.class("markdown-body mt-1 text-sm")],
      markdown_body(c.body),
    ),
  ])
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
    False -> "absolute left-[1.125rem] top-9 bottom-0 w-px -translate-x-1/2 bg-slate-200"
  }
  li([attr.class("relative flex gap-3 pb-6 last:pb-0")], [
    span([attr.class(line_class)], []),
    span(
      [
        attr.class(
          "relative z-10 flex h-9 w-9 shrink-0 items-center justify-center rounded-full border-2 border-white bg-slate-200 text-xs font-semibold text-slate-600 ring-1 ring-slate-200",
        ),
      ],
      [text(author_initials(c.author))],
    ),
    div([attr.class("min-w-0 flex-1 pt-0.5")], [
      div([attr.class("flex items-start justify-between gap-3")], [
        div([attr.class("min-w-0")], [
          a(
            [
              attr.href(routes.commit_tree_path(model.org_slug, model.repo_name, c.sha)),
              attr.class(
                "text-sm font-semibold leading-snug text-gh-ink hover:text-gh-accent",
              ),
            ],
            [text(c.subject)],
          ),
          p([attr.class("mt-1 text-sm text-gh-muted")], [
            span([attr.class("font-medium text-gh-ink")], [text(c.author)]),
            text(" committed " <> time_format.format_commit_time(c.committed_at)),
          ]),
        ]),
        button(
          [
            attr.type_("button"),
            attr.title("Copy full SHA"),
            attr.class(
              "shrink-0 rounded-md border border-slate-200 bg-slate-50 px-2 py-1 font-mono text-xs text-gh-muted transition hover:border-slate-300 hover:bg-white hover:text-gh-ink",
            ),
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
    True, [] -> components.empty_state("Loading commits…")
    False, [] -> components.empty_state("No commits on this branch yet.")
    _, commits -> {
      let chronological = commits_chronological(commits)
      let count = list.length(chronological)
      let last_index = count - 1
      div([attr.class(components.card <> " !p-0 overflow-hidden")], [
        div(
          [
            attr.class(
              "border-b border-slate-200 bg-slate-50/80 px-4 py-3 sm:px-6",
            ),
          ],
          [
            p([attr.class("text-sm font-semibold text-gh-ink")], [
              text(commit_count_label(count)),
            ]),
            p([attr.class("text-xs text-gh-muted")], [
              text("Commits on the source branch, oldest first"),
            ]),
          ],
        ),
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

fn changes_tab(model: Model) -> Element(Msg) {
  div([attr.class("flex flex-col gap-4 lg:flex-row")], [
    div([attr.class("lg:w-1/3")], [file_list(model)]),
    div([attr.class("lg:w-2/3")], [patch_panel(model)]),
  ])
}

fn file_list(model: Model) -> Element(Msg) {
  case model.diff_files {
    [] -> components.empty_state("No file changes")
    files ->
      div([attr.class(components.card)], [
        ul([attr.class("text-sm")], list.map(files, fn(f) {
          let selected = model.selected_file == option.Some(f.path)
          let classes = case selected {
            True -> "block w-full text-left rounded px-2 py-1 bg-gh-accent-soft text-gh-accent font-medium"
            False -> "block w-full text-left rounded px-2 py-1 hover:bg-slate-50"
          }
          li([], [
            button(
              [attr.type_("button"), attr.class(classes), event.on_click(SelectFile(f.path))],
              [
                text(
                  f.path
                    <> " (+"
                    <> int.to_string(f.additions)
                    <> " -"
                    <> int.to_string(f.deletions)
                    <> ")",
                ),
              ],
            ),
          ])
        })),
      ])
  }
}

fn patch_panel(model: Model) -> Element(Msg) {
  case model.selected_file {
    option.None -> components.empty_state("Select a file to view its diff")
    option.Some(path) ->
      case model.loading_patch {
        True -> components.empty_state("Loading diff…")
        False ->
          case model.patch {
            option.None -> components.empty_state("No patch")
            option.Some(patch) -> patch_view(model, path, patch)
          }
      }
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

fn inline_comment_composer(_file_path: String, line: Int, model: Model) -> Element(Msg) {
  div([attr.class("diff-inline-composer")], [
    form(
      [event.on_submit(fn(_) { SubmitComment }), attr.class("space-y-2")],
      [
        textarea(
          [
            attr.class(components.textarea <> " !min-h-[4rem]"),
            attr.placeholder("Leave a comment on line " <> int.to_string(line) <> "…"),
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
            text("Add review comment")],
          ),
        ]),
      ],
    ),
  ])
}

fn inline_thread_item(c: MrComment) -> Element(Msg) {
  div([attr.class("diff-inline-thread")], [
    p([attr.class("text-xs text-gh-muted")], [
      text(api.comment_author_label(c) <> " · " <> c.created_at),
    ]),
    p([attr.class("mt-1 text-sm text-gh-ink whitespace-pre-wrap")], [text(c.body)]),
  ])
}

fn patch_line_row(model: Model, file_path: String, line: diff_view.DiffLine) -> Element(Msg) {
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
          div([], list.map(items, fn(c) { inline_thread_item(c) }))
      }
      li([], [
        div([attr.class(row_class <> " diff-row group" <> row_extra)], [
          span([attr.class("diff-lineno")], [text(gutter)]),
          span([attr.class("diff-code")], [text(line.text)]),
          comment_btn,
        ]),
        threads,
        composer,
      ])
    }
  }
}

fn patch_view(model: Model, file_path: String, patch: String) -> Element(Msg) {
  let lines = diff_view.parse_patch(patch)
  let rows = list.map(lines, fn(line) { patch_line_row(model, file_path, line) })
  div([attr.class(components.card)], [
    h3([attr.class("mb-2 text-sm font-semibold text-gh-ink")], [text(file_path)]),
    ul([attr.class("diff-patch overflow-x-auto")], rows),
  ])
}
