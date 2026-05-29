import api.{type Issue, type IssueComment, type IssueDetail}
import components
import config.{type Config}
import gleam/int
import gleam/list
import gleam/option
import gleam/json
import gleam/string
import lustre/attribute as attr
import lustre/effect.{type Effect, batch, none}
import lustre/element.{type Element, text, unsafe_raw_html}
import lustre/element/html.{button, div, form, h2, li, p, span, textarea, ul}
import lustre/event
import lustre_http
import markdown
import routes
import time_format

const timeline_list = "space-y-4"
const timeline_item = "relative flex gap-3"
const timeline_line =
  "absolute left-5 top-10 bottom-0 w-px -translate-x-1/2 bg-slate-200"

const avatar_class =
  "relative z-10 flex h-10 w-10 shrink-0 items-center justify-center rounded-full border-2 border-white bg-slate-200 text-sm font-semibold text-slate-600 ring-1 ring-slate-200"

const event_card =
  "min-w-0 flex-1 overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm"

const event_header =
  "border-b border-slate-200 bg-slate-50 px-4 py-2.5 text-sm text-gh-muted"

const event_body = "px-4 py-4"

pub type Model {
  Model(
    org_slug: String,
    repo_name: String,
    number: Int,
    detail: option.Option(IssueDetail),
    comments: List(IssueComment),
    comment_body: String,
    loading: Bool,
    error: option.Option(String),
  )
}

pub type Msg {
  DetailLoaded(Result(IssueDetail, lustre_http.HttpError))
  CommentsLoaded(Result(List(IssueComment), lustre_http.HttpError))
  CommentBodyChanged(String)
  SubmitComment
  CommentPosted(Result(IssueComment, lustre_http.HttpError))
  CloseIssue
  Closed(Result(Issue, lustre_http.HttpError))
}

pub fn init(org_slug: String, repo_name: String, number: Int) -> Model {
  Model(
    org_slug:,
    repo_name:,
    number:,
    detail: option.None,
    comments: [],
    comment_body: "",
    loading: True,
    error: option.None,
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
  ])
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    DetailLoaded(Ok(d)) -> #(
      Model(..model, detail: option.Some(d), loading: False, error: option.None),
      none(),
    )
    DetailLoaded(Error(_)) -> #(
      Model(..model, loading: False, error: option.Some("Failed to load issue")),
      none(),
    )
    CommentsLoaded(Ok(comments)) -> #(
      Model(..model, comments:),
      none(),
    )
    CommentsLoaded(Error(_)) -> #(model, none())
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
        detail: case model.detail {
          option.Some(_d) ->
            option.Some(api.IssueDetail(issue:))
          option.None -> option.None
        },
        error: option.None,
      ),
      none(),
    )
    Closed(Error(_)) -> #(
      Model(..model, error: option.Some("Could not close issue")),
      none(),
    )
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
          True -> components.empty_state("Loading…")
          False -> components.empty_state("Issue not found")
        },
      ])
    option.Some(detail) -> detail_view(model, detail, error)
  }
}

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
    div([attr.class("mb-6 flex flex-wrap items-start justify-between gap-3")], [
      h2([attr.class("min-w-0 text-2xl font-bold text-gh-ink")], [
        text(issue.title <> " #" <> int.to_string(issue.number)),
      ]),
      div([attr.class("flex shrink-0 flex-wrap items-center gap-2")], [
        state_badge(issue.state),
        case issue.state {
          "open" ->
            button(
              [
                attr.type_("button"),
                attr.class(components.btn_secondary <> " !h-9 !px-3 !py-0"),
                event.on_click(CloseIssue),
              ],
              [text("Close issue")],
            )
          _ -> text("")
        },
      ]),
    ]),
    error,
    conversation_timeline(model, issue),
  ])
}

fn state_badge(state: String) -> Element(Msg) {
  let classes = case state {
    "open" -> "bg-emerald-50 text-emerald-800 ring-emerald-600/20"
    "closed" -> "bg-violet-50 text-violet-800 ring-violet-600/20"
    _ -> "bg-slate-100 text-slate-600 ring-slate-500/20"
  }
  span(
    [
      attr.class(
        "inline-flex rounded-full px-3 py-1 text-xs font-semibold capitalize ring-1 ring-inset "
        <> classes,
      ),
    ],
    [text(state)],
  )
}

fn conversation_timeline(model: Model, issue: Issue) -> Element(Msg) {
  let comment_count = list.length(model.comments)
  let items =
    list.flatten([
      [opening_post(issue, comment_count > 0)],
      list.index_map(model.comments, fn(c, index) {
        comment_item(c, index < comment_count - 1)
      }),
      [comment_form(model)],
    ])
  ul([attr.class(timeline_list)], items)
}

fn opening_post(issue: Issue, has_more: Bool) -> Element(Msg) {
  let author = author_label(issue.author_user_id)
  timeline_event(
    initials: author_initials(author),
    header: event_header_text(author, "opened this issue", issue.created_at),
    body: issue_body(issue.description),
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
        markdown_body(d),
      )
    option.None ->
      p([attr.class("text-sm italic text-gh-muted")], [
        text("No description provided."),
      ])
  }
}

fn comment_item(c: IssueComment, show_line: Bool) -> Element(Msg) {
  let author = api.issue_comment_author_label(c)
  timeline_event(
    initials: author_initials(author),
    header: event_header_text(author, "commented", c.created_at),
    body:
      unsafe_raw_html(
        "",
        "div",
        [attr.class("markdown-body text-sm")],
        markdown_body(c.body),
      ),
    show_line:,
  )
}

fn timeline_event(
  initials initials: String,
  header header: Element(Msg),
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
      div([attr.class(event_header)], [header]),
      div([attr.class(event_body)], [body]),
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
              button([attr.type_("submit"), attr.class(components.btn_primary)], [
                text("Comment"),
              ]),
            ],
          ),
        ],
      ),
    ]),
  ])
}

fn author_label(user_id: String) -> String {
  case string.split(user_id, on: "_") {
    [prefix, ..] ->
      case string.trim(prefix) {
        "" -> user_id
        trimmed -> trimmed
      }
    _ -> user_id
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

fn markdown_body(content: String) -> String {
  markdown.to_html(content)
}
