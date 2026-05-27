import api.{
  type DiffFile, type MergeCheck, type MergeRequest, type MergeRequestDetail,
  type MrComment, type MrCommit,
}
import components
import config.{type Config}
import gleam/int
import gleam/list
import gleam/option
import gleam/json
import gleam/string
import gleam/uri
import lustre/attribute as attr
import lustre/effect.{type Effect, batch, none}
import lustre/element.{type Element, text, unsafe_raw_html}
import lustre/element/html.{
  button, div, form, h2, h3, li, option, p, select, span, textarea, ul,
}
import lustre/event
import lustre_http
import markdown
import routes

pub type Tab {
  Conversation
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
    loading: Bool,
    loading_patch: Bool,
    error: option.Option(String),
  )
}

pub type Msg {
  DetailLoaded(Result(MergeRequestDetail, lustre_http.HttpError))
  CommentsLoaded(Result(List(MrComment), lustre_http.HttpError))
  CommitsLoaded(Result(List(MrCommit), lustre_http.HttpError))
  DiffLoaded(Result(List(DiffFile), lustre_http.HttpError))
  PatchLoaded(Result(String, lustre_http.HttpError))
  TabChanged(Tab)
  CommentBodyChanged(String)
  CommentOnLine(String, Int)
  SubmitComment
  CommentPosted(Result(MrComment, lustre_http.HttpError))
  SelectFile(String)
  MergeMethodChanged(api.MergeMethod)
  ShowMergeConfirm
  CancelMergeConfirm
  Merge
  Merged(Result(MergeRequest, lustre_http.HttpError))
  CloseMr
  Closed(Result(MergeRequest, lustre_http.HttpError))
}

pub fn init(org_slug: String, repo_name: String, number: Int) -> Model {
  Model(
    org_slug:,
    repo_name:,
    number:,
    tab: Conversation,
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
    loading: True,
    loading_patch: False,
    error: option.None,
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

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  let base = api_base(config, model)
  batch([
    lustre_http.get(
      config,
      base,
      lustre_http.expect_json(api.merge_request_detail_decoder(), DetailLoaded),
    ),
    lustre_http.get(
      config,
      base <> "/comments",
      lustre_http.expect_json(api.mr_comments_decoder(), CommentsLoaded),
    ),
  ])
}

fn tab_load(config: Config, model: Model, tab: Tab) -> Effect(Msg) {
  let base = api_base(config, model)
  case tab {
    Conversation -> none()
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
    Changes ->
      case model.diff_files {
        [] ->
          lustre_http.get(
            config,
            base <> "/diff",
            lustre_http.expect_json(api.diff_files_decoder(), DiffLoaded),
          )
        _ -> none()
      }
  }
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    DetailLoaded(Ok(d)) -> #(
      Model(..model, detail: option.Some(d), loading: False, error: option.None),
      none(),
    )
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
      Model(..model, commits:),
      none(),
    )
    CommitsLoaded(Error(_)) -> #(
      Model(..model, error: option.Some("Failed to load commits")),
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
    TabChanged(tab) -> #(
      Model(..model, tab:),
      tab_load(config, model, tab),
    )
    CommentBodyChanged(v) -> #(Model(..model, comment_body: v), none())
    CommentOnLine(file, line) -> #(
      Model(
        ..model,
        comment_file: option.Some(file),
        comment_line: option.Some(line),
        tab: Conversation,
      ),
      none(),
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
    ShowMergeConfirm -> #(Model(..model, show_merge_confirm: True), none())
    CancelMergeConfirm -> #(Model(..model, show_merge_confirm: False), none())
    Merge -> #(
      Model(..model, show_merge_confirm: False),
      lustre_http.post(
        config,
        api_base(config, model) <> "/merge",
        api.merge_request_merge_body(model.merge_method),
        lustre_http.expect_json(api.merge_request_decoder(), Merged),
      ),
    )
    Merged(Ok(mr)) -> #(
      Model(
        ..model,
        detail: option.map(model.detail, fn(d) {
          api.MergeRequestDetail(merge_request: mr, merge_check: d.merge_check)
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
          api.MergeRequestDetail(merge_request: mr, merge_check: d.merge_check)
        }),
      ),
      none(),
    )
    Closed(Error(_)) -> #(
      Model(..model, error: option.Some("Could not close merge request")),
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
        merge_check_banner(detail.merge_check),
      ]),
      action_buttons(model, mr, detail.merge_check),
    ]),
    error,
    tab_bar(model.tab),
    tab_content(model, mr),
  ])
}

fn merge_check_banner(check: MergeCheck) -> Element(Msg) {
  case check.mergeable {
    True -> text("")
    False ->
      p([attr.class("mt-2 rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-900")], [
        text(check.message),
      ])
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
      p([attr.class("mb-4 text-sm leading-snug text-gh-ink")], [
        text(merge_confirm_message(model, mr)),
      ]),
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
) -> Element(Msg) {
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

fn tab_bar(active: Tab) -> Element(Msg) {
  let tab_btn = fn(t: Tab, label: String) {
    let classes = case active == t {
      True -> "border-b-2 border-gh-accent px-4 py-2 text-sm font-semibold text-gh-accent"
      False ->
        "border-b-2 border-transparent px-4 py-2 text-sm font-medium text-gh-muted hover:text-gh-ink"
    }
    button(
      [attr.type_("button"), attr.class(classes), event.on_click(TabChanged(t))],
      [text(label)],
    )
  }
  div([attr.class("mb-4 flex border-b border-slate-200")], [
    tab_btn(Conversation, "Conversation"),
    tab_btn(Commits, "Commits"),
    tab_btn(Changes, "Changes"),
  ])
}

fn tab_content(model: Model, mr: MergeRequest) -> Element(Msg) {
  case model.tab {
    Conversation -> conversation_tab(model, mr)
    Commits -> commits_tab(model)
    Changes -> changes_tab(model)
  }
}

fn conversation_tab(model: Model, mr: MergeRequest) -> Element(Msg) {
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
    option.Some(f), option.Some(l) -> " on " <> f <> ":" <> int.to_string(l)
    _, _ -> ""
  }
  li([], [
    p([attr.class("text-xs text-gh-muted")], [text(c.created_at <> meta)]),
    p([attr.class("mt-1 text-sm text-gh-ink whitespace-pre-wrap")], [text(c.body)]),
  ])
}

fn commits_tab(model: Model) -> Element(Msg) {
  case model.commits {
    [] ->
      components.empty_state("No commits or still loading…")
    commits ->
      div([attr.class(components.card)], [
        ul([attr.class("space-y-3")], list.map(commits, fn(c) {
          li([], [
            p([attr.class("font-mono text-xs text-gh-muted")], [
              text(string.slice(c.sha, 0, 7)),
            ]),
            p([attr.class("text-sm font-medium text-gh-ink")], [text(c.subject)]),
            p([attr.class("text-xs text-gh-muted")], [
              text(c.author <> " · " <> c.committed_at),
            ]),
          ])
        })),
      ])
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
            option.Some(patch) -> patch_view(path, patch)
          }
      }
  }
}

fn patch_view(file_path: String, patch: String) -> Element(Msg) {
  let lines = string.split(patch, on: "\n")
  let rows =
    list.index_map(lines, fn(line, idx) {
      let line_no = idx + 1
      let row_class = case string.starts_with(line, "+") {
        True ->
          case string.starts_with(line, "+++") {
            True -> "diff-line diff-meta"
            False -> "diff-line diff-add"
          }
        False ->
          case string.starts_with(line, "-") {
            True -> "diff-line diff-del"
            False -> "diff-line"
          }
      }
      let comment_btn = case string.starts_with(line, "+") {
        True ->
          case string.starts_with(line, "+++") {
            True -> text("")
            False ->
              button(
                [
                  attr.type_("button"),
                  attr.class("ml-2 text-xs text-gh-accent hover:underline"),
                  event.on_click(CommentOnLine(file_path, line_no)),
                ],
                [text("Comment")],
              )
          }
        False -> text("")
      }
      li([attr.class(row_class)], [
        span([attr.class("diff-lineno mr-2 select-none text-gh-muted")], [
          text(int.to_string(line_no)),
        ]),
        span([attr.class("font-mono text-sm")], [text(line)]),
        comment_btn,
      ])
    })
  div([attr.class(components.card)], [
    h3([attr.class("mb-2 text-sm font-semibold text-gh-ink")], [text(file_path)]),
    ul([attr.class("diff-patch overflow-x-auto")], rows),
  ])
}
