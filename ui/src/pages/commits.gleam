import api.{type MrCommit, type RepoCommits}
import components
import config.{type Config}
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/uri
import lustre/attribute as attr
import lustre/effect.{type Effect, batch, none}
import lustre/element.{type Element, text}
import lustre/element/html.{
  a, button, div, h2, li, ol, option, p, select, span,
}
import lustre/event
import lustre_http
import clipboard
import modem
import routes
import time_format

pub type Model {
  Model(
    org_slug: String,
    repo_name: String,
    ref: String,
    branches: List(String),
    total: Int,
    commits: List(MrCommit),
    loading: Bool,
    copied_commit_sha: option.Option(String),
    error: option.Option(String),
  )
}

pub type Msg {
  BranchesLoaded(Result(List(String), lustre_http.HttpError))
  CommitsLoaded(Result(RepoCommits, lustre_http.HttpError))
  BranchChanged(String)
  CopyCommitSha(String)
}

pub fn init(org_slug: String, repo_name: String, ref: String) -> Model {
  Model(
    org_slug:,
    repo_name:,
    ref:,
    branches: [],
    total: 0,
    commits: [],
    loading: True,
    copied_commit_sha: option.None,
    error: option.None,
  )
}

fn api_base(config: Config, model: Model) -> String {
  config.api_url <> "/api/orgs/" <> model.org_slug <> "/repos/" <> model.repo_name
}

fn load_branches(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model) <> "/branches",
    lustre_http.expect_json(api.branches_decoder(), BranchesLoaded),
  )
}

fn load_commits(config: Config, model: Model) -> Effect(Msg) {
  case model.ref {
    "" -> none()
    ref ->
      lustre_http.get(
        config,
        api_base(config, model) <> "/commits?ref=" <> uri.percent_encode(ref),
        lustre_http.expect_json(api.repo_commits_decoder(), CommitsLoaded),
      )
  }
}

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  batch([load_branches(config, model), load_commits(config, model)])
}

fn default_ref(branches: List(String)) -> String {
  case list.contains(branches, "main") {
    True -> "main"
    False ->
      case list.contains(branches, "master") {
        True -> "master"
        False ->
          case branches {
            [first, ..] -> first
            [] -> "main"
          }
      }
  }
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    BranchesLoaded(Ok(branches)) -> {
      let ref = case model.ref {
        "" -> default_ref(branches)
        r -> r
      }
      let had_ref = model.ref != ""
      let model = Model(..model, branches:, ref:)
      #(
        model,
        case had_ref {
          False -> load_commits(config, model)
          True -> none()
        },
      )
    }
    BranchesLoaded(Error(_)) -> #(
      Model(..model, loading: False, error: option.Some("Failed to load branches")),
      none(),
    )
    CommitsLoaded(Ok(data)) -> #(
      Model(
        ..model,
        total: data.total,
        commits: data.commits,
        loading: False,
        error: option.None,
      ),
      none(),
    )
    CommitsLoaded(Error(_)) -> #(
      Model(..model, loading: False, error: option.Some("Failed to load commits")),
      none(),
    )
    BranchChanged(new_ref) -> #(
      model,
      modem.replace(
        routes.commits_path(model.org_slug, model.repo_name, new_ref),
        option.None,
        option.None,
      ),
    )
    CopyCommitSha(sha) -> {
      let _ = clipboard.copy(sha)
      #(Model(..model, copied_commit_sha: option.Some(sha)), none())
    }
  }
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

fn short_sha(sha: String) -> String {
  string.slice(sha, 0, 7)
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
              "shrink-0 rounded-md border border-slate-200 bg-white px-2 py-1 font-mono text-xs text-gh-muted transition hover:border-slate-300 hover:text-gh-ink",
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

fn branch_select(model: Model) -> Element(Msg) {
  select(
    [
      attr.class(components.input <> " !w-auto !min-w-[8rem] !py-1.5"),
      event.on_change(BranchChanged),
    ],
    list.map(model.branches, fn(branch) {
      option(
        [
          attr.value(branch),
          attr.selected(model.ref == branch),
        ],
        branch,
      )
    }),
  )
}

fn commits_body(model: Model) -> Element(Msg) {
  case model.loading, model.commits {
    True, [] -> components.empty_state("Loading commits…")
    False, [] -> components.empty_state("No commits on this branch yet.")
    _, commits -> {
      let chronological = commits_chronological(commits)
      let count = list.length(chronological)
      let last_index = count - 1
      let limited_note = case model.total > count {
        True ->
          p([attr.class("text-xs text-gh-muted")], [
            text(
              "Showing the "
                <> int.to_string(count)
                <> " most recent of "
                <> int.to_string(model.total)
                <> " commits",
            ),
          ])
        False -> text("")
      }
      div([attr.class(components.card <> " !p-0 overflow-hidden")], [
        div(
          [
            attr.class(
              "border-b border-slate-200 bg-slate-50/80 px-4 py-3 sm:px-6",
            ),
          ],
          [
            p([attr.class("text-sm font-semibold text-gh-ink")], [
              text(commit_count_label(model.total)),
            ]),
            p([attr.class("text-xs text-gh-muted")], [
              text("Commits on " <> model.ref <> ", oldest first"),
            ]),
            limited_note,
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

pub fn view(model: Model) -> Element(Msg) {
  let error = case model.error {
    option.Some(e) -> components.error_alert(e)
    option.None -> text("")
  }
  let repo_home = routes.repo_home_path(model.org_slug, model.repo_name)

  div([attr.class(components.page <> " max-w-5xl")], [
    components.breadcrumb_back(repo_home, model.repo_name),
    div([attr.class("mb-6")], [
      h2([attr.class("text-2xl font-bold tracking-tight text-gh-ink")], [
        text("Commits"),
      ]),
      p([attr.class("mt-1 text-sm text-gh-muted")], [
        text(model.org_slug <> " / " <> model.repo_name),
      ]),
    ]),
    error,
    div(
      [
        attr.class(
          "repo-toolbar mb-4 flex flex-col gap-3 rounded-xl border border-slate-200/80 bg-white px-4 py-3 shadow-sm ring-1 ring-slate-900/5 sm:flex-row sm:items-center",
        ),
      ],
      [
        div([attr.class("flex items-center gap-2")], [
          span([attr.class("text-sm font-medium text-gh-muted")], [text("Branch")]),
          branch_select(model),
        ]),
        a(
          [
            attr.href(repo_home),
            attr.class("text-sm font-semibold text-gh-ink hover:text-gh-accent"),
          ],
          [text("Browse files")],
        ),
      ],
    ),
    commits_body(model),
  ])
}
