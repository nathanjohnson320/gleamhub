import ci/status as ci_status
import components
import config.{type Config}
import content/highlight
import content/markdown
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/uri
import http/api.{
  type BlobView, type MrCommit, type Readme, type RepoCommits, type RepoDetail,
  type TreeEntry, type TreeListing,
}
import http/lustre_http
import lustre/attribute as attr
import lustre/effect.{type Effect, none}
import lustre/element.{type Element, text, unsafe_raw_html}
import lustre/element/html.{
  a, button, code, div, h3, option, p, select, span, table, tbody, td, th,
  thead, tr,
}
import lustre/event
import modem
import pages/blob_line_scroll
import pages/repo_nav
import repo_icons
import routes.{
  type ViewMode, Blob, Home, Tree, repo_archive_api_suffix, repo_blob_api_suffix,
  repo_raw_api_suffix, repo_raw_browser_path, repo_tree_api_suffix,
  RepoArchiveZip,
}
import util/clipboard
import util/file_download
import util/time_format

pub type Model {
  Model(
    org_slug: String,
    repo_name: String,
    mode: ViewMode,
    ref: String,
    path: String,
    detail: option.Option(RepoDetail),
    branches: List(String),
    readme: option.Option(Readme),
    tree: option.Option(TreeListing),
    blob: option.Option(BlobView),
    loading: Bool,
    empty_repo: Bool,
    clone_copied: Bool,
    commit_total: option.Option(Int),
    viewing_commit: option.Option(MrCommit),
    error: option.Option(String),
    line_range: option.Option(#(Int, Int)),
  )
}

pub type Msg {
  LoadedDetail(Result(RepoDetail, lustre_http.HttpError))
  LoadedBranches(Result(List(String), lustre_http.HttpError))
  LoadedReadme(Result(Readme, lustre_http.HttpError))
  LoadedTree(Result(TreeListing, lustre_http.HttpError))
  LoadedBlob(Result(BlobView, lustre_http.HttpError))
  CommitsSummaryLoaded(Result(RepoCommits, lustre_http.HttpError))
  CommitLoaded(Result(MrCommit, lustre_http.HttpError))
  BranchChanged(String)
  CopyCloneUrl
  DownloadFile
  DownloadZip
}

pub fn same_view(
  model: Model,
  org: String,
  repo: String,
  mode: ViewMode,
  ref: String,
  path: String,
) -> Bool {
  model.org_slug == org
  && model.repo_name == repo
  && model.mode == mode
  && model.ref == ref
  && model.path == path
}

/// Update line highlight from the URL without resetting loaded repo data.
pub fn sync_line_range(
  model: Model,
  line_range: option.Option(#(Int, Int)),
) -> Model {
  Model(..model, line_range:)
}

pub fn sync_line_range_effect(
  before: option.Option(#(Int, Int)),
  after: option.Option(#(Int, Int)),
) -> Effect(Msg) {
  case before != after {
    True -> blob_line_scroll.scroll_effect(after)
    False -> effect.none()
  }
}

pub fn init(
  org_slug: String,
  repo_name: String,
  mode: ViewMode,
  ref: String,
  path: String,
  line_range: option.Option(#(Int, Int)),
) -> Model {
  Model(
    org_slug:,
    repo_name:,
    mode:,
    ref:,
    path:,
    detail: option.None,
    branches: [],
    readme: option.None,
    tree: option.None,
    blob: option.None,
    loading: True,
    empty_repo: False,
    clone_copied: False,
    commit_total: option.None,
    viewing_commit: option.None,
    error: option.None,
    line_range:,
  )
}

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  case model.mode {
    Blob ->
      effect.batch([
        load_detail(config, model),
        load_blob(config, model),
        load_branches(config, model),
        load_commit(config, model),
        load_commits_summary(config, model),
      ])
    Tree ->
      effect.batch([
        load_detail(config, model),
        load_tree(config, model),
        load_branches(config, model),
        load_commit(config, model),
        load_commits_summary(config, model),
      ])
    Home ->
      effect.batch([
        load_detail(config, model),
        load_branches(config, model),
      ])
  }
}

fn load_commits_summary(config: Config, model: Model) -> Effect(Msg) {
  case model.ref {
    "" -> effect.none()
    ref ->
      case routes.is_commit_ref(ref) {
        True -> effect.none()
        False ->
          lustre_http.get(
            config,
            api_base(config, model)
              <> "/commits?ref="
              <> uri.percent_encode(ref),
            lustre_http.expect_json(
              api.repo_commits_decoder(),
              CommitsSummaryLoaded,
            ),
          )
      }
  }
}

fn load_commit(config: Config, model: Model) -> Effect(Msg) {
  case routes.is_commit_ref(model.ref) {
    True ->
      lustre_http.get(
        config,
        api_base(config, model)
          <> "/commit?sha="
          <> uri.percent_encode(model.ref),
        lustre_http.expect_json(api.commit_decoder(), CommitLoaded),
      )
    False -> effect.none()
  }
}

fn home_content_effects(config: Config, model: Model) -> Effect(Msg) {
  case model.mode, model.ref {
    Home, ref if ref != "" ->
      effect.batch([
        load_readme(config, model),
        load_tree(config, model),
        load_commits_summary(config, model),
      ])
    Tree, ref if ref != "" ->
      effect.batch([
        load_tree(config, model),
        load_commits_summary(config, model),
      ])
    Blob, ref if ref != "" -> load_commits_summary(config, model)
    _, _ -> effect.none()
  }
}

fn api_base(config: Config, model: Model) -> String {
  config.api_url
  <> "/api/orgs/"
  <> model.org_slug
  <> "/repos/"
  <> model.repo_name
}

fn load_detail(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model),
    lustre_http.expect_json(api.repo_detail_decoder(), LoadedDetail),
  )
}

fn load_branches(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model) <> "/branches",
    lustre_http.expect_json(api.branches_decoder(), LoadedBranches),
  )
}

fn load_readme(config: Config, model: Model) -> Effect(Msg) {
  case model.ref {
    "" -> effect.none()
    _ ->
      lustre_http.get(
        config,
        api_base(config, model)
          <> "/readme?ref="
          <> uri.percent_encode(model.ref),
        lustre_http.expect_json(api.readme_decoder(), LoadedReadme),
      )
  }
}

fn load_tree(config: Config, model: Model) -> Effect(Msg) {
  case model.ref {
    "" -> effect.none()
    ref -> {
      let url =
        api_base(config, model)
        <> "/tree"
        <> repo_tree_api_suffix(ref, model.path)
      lustre_http.get(
        config,
        url,
        lustre_http.expect_json(api.tree_decoder(), LoadedTree),
      )
    }
  }
}

fn load_blob(config: Config, model: Model) -> Effect(Msg) {
  case model.ref {
    "" -> effect.none()
    _ ->
      lustre_http.get(
        config,
        api_base(config, model) <> repo_blob_api_suffix(model.ref, model.path),
        lustre_http.expect_json(api.blob_decoder(), LoadedBlob),
      )
  }
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    LoadedDetail(Ok(detail)) -> {
      let ref = case model.ref {
        "" ->
          case detail.default_branch {
            option.Some(r) -> r
            option.None -> model.ref
          }
        _ -> model.ref
      }
      let had_ref = model.ref != ""
      let model =
        Model(
          ..model,
          detail: option.Some(detail),
          ref:,
          loading: False,
          clone_copied: False,
          error: option.None,
        )
      #(model, case model.mode, had_ref {
        Blob, False -> load_blob(config, model)
        Home, False -> home_content_effects(config, model)
        _, _ -> effect.none()
      })
    }
    LoadedDetail(Error(_)) -> #(
      Model(..model, loading: False, error: option.Some("Repository not found")),
      effect.none(),
    )
    LoadedBranches(Ok(branches)) -> {
      let ref = case model.ref {
        "" -> default_ref(branches)
        r -> r
      }
      let had_ref = model.ref != ""
      let model = Model(..model, branches:, empty_repo: branches == [], ref:)
      #(model, case model.mode, had_ref {
        Blob, False -> load_blob(config, model)
        Home, False -> home_content_effects(config, model)
        _, _ -> effect.none()
      })
    }
    LoadedBranches(Error(_)) -> #(
      Model(..model, branches: [], empty_repo: True),
      effect.none(),
    )
    LoadedReadme(Ok(readme)) -> #(
      Model(..model, readme: option.Some(readme)),
      effect.none(),
    )
    LoadedReadme(Error(lustre_http.NotFound)) -> #(
      Model(..model, readme: option.None),
      effect.none(),
    )
    LoadedReadme(Error(_)) -> #(model, effect.none())
    LoadedTree(Ok(tree)) -> #(
      Model(..model, tree: option.Some(tree), loading: False),
      effect.none(),
    )
    LoadedTree(Error(_)) -> #(
      Model(..model, tree: option.None, loading: False),
      effect.none(),
    )
    LoadedBlob(Ok(blob)) -> #(
      Model(..model, blob: option.Some(blob), loading: False),
      blob_line_scroll.scroll_effect(model.line_range),
    )
    LoadedBlob(Error(_)) -> #(
      Model(..model, error: option.Some("Could not load file"), loading: False),
      effect.none(),
    )
    CommitsSummaryLoaded(Ok(data)) -> #(
      Model(..model, commit_total: option.Some(data.total)),
      effect.none(),
    )
    CommitsSummaryLoaded(Error(_)) -> #(
      Model(..model, commit_total: option.None),
      effect.none(),
    )
    CommitLoaded(Ok(commit)) -> #(
      Model(..model, viewing_commit: option.Some(commit)),
      effect.none(),
    )
    CommitLoaded(Error(_)) -> #(
      Model(..model, viewing_commit: option.None),
      effect.none(),
    )
    CopyCloneUrl -> {
      let url = case model.detail {
        option.Some(d) -> d.clone_url
        option.None -> ""
      }
      let _ = clipboard.copy(url)
      #(Model(..model, clone_copied: True), effect.none())
    }
    BranchChanged("") -> #(model, effect.none())
    BranchChanged(new_ref) -> {
      case model.mode {
        Home -> #(
          Model(..model, ref: new_ref, loading: True, commit_total: option.None),
          on_load(config, Model(..model, ref: new_ref)),
        )
        _ -> #(
          model,
          modem.replace(
            routes.branch_href(
              model.mode,
              model.org_slug,
              model.repo_name,
              new_ref,
              model.path,
            ),
            option.None,
            option.None,
          ),
        )
      }
    }
    DownloadFile -> #(
      model,
      download_file_effect(
        config,
        api_base(config, model)
          <> repo_raw_api_suffix(model.ref, model.path, True),
        mime_filename(model.path),
      ),
    )
    DownloadZip -> #(
      model,
      download_file_effect(
        config,
        api_base(config, model)
          <> repo_archive_api_suffix(default_archive_ref(model), RepoArchiveZip),
        model.repo_name <> "-" <> default_archive_ref(model) <> ".zip",
      ),
    )
  }
}

fn mime_filename(path: String) -> String {
  case string.split(path, on: "/") |> list.last {
    Ok(name) -> name
    Error(_) -> "download"
  }
}

fn default_archive_ref(model: Model) -> String {
  case model.detail {
    option.Some(detail) ->
      case detail.default_branch {
        option.Some(branch) -> branch
        option.None -> model.ref
      }
    option.None -> model.ref
  }
}

fn download_file_effect(
  config: Config,
  url: String,
  filename: String,
) -> Effect(Msg) {
  case config.token {
    option.Some(token) ->
      effect.from(fn(_) { file_download.download(url, token, filename) })
    option.None -> none()
  }
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

fn file_row(model: Model, entry: TreeEntry) -> Element(Msg) {
  let href = case entry.entry_type {
    "tree" -> {
      let sub = case model.path {
        "" -> entry.name
        _ -> model.path <> "/" <> entry.name
      }
      routes.repo_tree_path(model.org_slug, model.repo_name, model.ref, sub)
    }
    _ -> {
      let file_path = case model.path {
        "" -> entry.name
        _ -> model.path <> "/" <> entry.name
      }
      routes.repo_blob_path(
        model.org_slug,
        model.repo_name,
        model.ref,
        file_path,
      )
    }
  }
  let commit_cell = case entry.last_commit_message {
    "" ->
      td([attr.class("repo-file-commit")], [text("-")])
    _ -> {
      let commit_sha_cell = case entry.last_commit_sha {
        "" ->
          span([attr.class("repo-file-commit-link repo-file-commit-static")], [
            text(entry.last_commit_message),
          ])
        sha ->
          a(
            [
              attr.href(routes.commit_tree_path(
                model.org_slug,
                model.repo_name,
                sha,
              )),
              attr.class("repo-file-commit-link"),
              attr.title(entry.last_commit_message),
            ],
            [text(entry.last_commit_message)],
          )
      }
      td([attr.class("repo-file-commit")], [commit_sha_cell])
    }
  }
  let sha_display = case entry.last_commit_sha {
    "" -> string.slice(entry.sha, 0, 7)
    sha -> string.slice(sha, 0, 7)
  }
  let sha_cell = case entry.last_commit_sha {
    "" ->
      td([attr.class("repo-file-meta")], [
        span([attr.class("repo-sha-pill")], [text(sha_display)]),
      ])
    sha ->
      td([attr.class("repo-file-meta")], [
        a(
          [
            attr.href(routes.commit_tree_path(
              model.org_slug,
              model.repo_name,
              sha,
            )),
            attr.class("repo-sha-pill repo-sha-pill-link"),
          ],
          [text(sha_display)],
        ),
      ])
  }
  tr([attr.class("repo-file-row")], [
    td([attr.class("repo-file-name")], [
      a(
        [
          attr.href(href),
          attr.class(repo_icons.entry_link_class(entry.entry_type)),
        ],
        [
          repo_icons.entry_icon(entry.entry_type),
          span([attr.class("repo-entry-name")], [text(entry.name)]),
        ],
      ),
    ]),
    commit_cell,
    sha_cell,
  ])
}

fn file_table(model: Model) -> Element(Msg) {
  case model.tree {
    option.None -> components.empty_state("No files to display")
    option.Some(tree) ->
      case tree.entries {
        [] -> components.empty_state("This directory is empty")
        entries ->
          table([attr.class("repo-file-table")], [
            thead([], [
              tr([], [
                th([], [text("Name")]),
                th([], [text("Last commit")]),
                th([attr.class("repo-file-meta")], [text("SHA")]),
              ]),
            ]),
            tbody([], list.map(entries, fn(e) { file_row(model, e) })),
          ])
      }
  }
}

fn readme_section(model: Model) -> Element(Msg) {
  case model.readme {
    option.None -> text("")
    option.Some(readme) ->
      div([attr.class("repo-readme-card mb-6")], [
        div([attr.class("repo-readme-header")], [
          a(
            [
              attr.href(routes.repo_blob_path(
                model.org_slug,
                model.repo_name,
                model.ref,
                readme.path,
              )),
              attr.class("repo-readme-path"),
            ],
            [text(readme.path)],
          ),
        ]),
        unsafe_raw_html(
          "",
          "div",
          [attr.class("markdown-body px-4 py-5")],
          markdown.to_html(readme.content),
        ),
      ])
  }
}

fn path_breadcrumb(model: Model) -> Element(Msg) {
  let segments = case model.path {
    "" -> []
    p -> string.split(p, on: "/")
  }
  let root =
    a(
      [
        attr.href(routes.repo_tree_path(
          model.org_slug,
          model.repo_name,
          model.ref,
          "",
        )),
        attr.class("font-semibold text-gh-ink hover:text-gh-accent"),
      ],
      [text(model.repo_name)],
    )
  let parts =
    list.index_map(segments, fn(seg, idx) {
      let subpath =
        segments
        |> list.take(idx + 1)
        |> string.join(with: "/")
      #(
        idx,
        a(
          [
            attr.href(routes.repo_tree_path(
              model.org_slug,
              model.repo_name,
              model.ref,
              subpath,
            )),
            attr.class("text-gh-ink hover:text-gh-accent"),
          ],
          [text(seg)],
        ),
      )
    })
  div(
    [
      attr.class(
        "repo-path-breadcrumb flex flex-wrap items-center gap-1 text-sm",
      ),
    ],
    [
      root,
      ..list.flat_map(parts, fn(part) {
        let #(_, link) = part
        [span([attr.class("text-gh-muted")], [text("/")]), link]
      })
    ],
  )
}

fn short_sha(sha: String) -> String {
  string.slice(sha, 0, 7)
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

fn ref_selector(model: Model) -> Element(Msg) {
  case routes.is_commit_ref(model.ref) {
    False ->
      div([attr.class("flex items-center gap-2")], [
        span([attr.class("text-xs font-black uppercase tracking-wide text-gh-ink")], [
          text("Branch"),
        ]),
        branch_select(model),
      ])
    True ->
      div([attr.class("flex flex-wrap items-center gap-2")], [
        span([attr.class("text-xs font-black uppercase tracking-wide text-gh-ink")], [
          text("Commit"),
        ]),
        code(
          [
            attr.class(
              components.code_block <> " !inline-block !px-2 !py-1 !text-xs",
            ),
          ],
          [text(short_sha(model.ref))],
        ),
        select(
          [
            attr.class(components.input <> " !w-auto !min-w-[8rem] !py-1.5"),
            event.on_change(BranchChanged),
          ],
          list.append(
            [
              option(
                [attr.value(""), attr.selected(False)],
                "Switch to branch…",
              ),
            ],
            list.map(model.branches, fn(branch) {
              option([attr.value(branch)], branch)
            }),
          ),
        ),
      ])
  }
}

fn commit_snapshot_banner(model: Model) -> Element(Msg) {
  case model.viewing_commit {
    option.None -> text("")
    option.Some(c) ->
      div([attr.class(components.card <> " mb-4")], [
        p(
          [
            attr.class(
              "text-xs font-semibold uppercase tracking-wide text-gh-muted",
            ),
          ],
          [
            text("Snapshot at this commit"),
          ],
        ),
        h3([attr.class("mt-1 text-lg font-semibold text-gh-ink")], [
          text(c.subject),
        ]),
        p([attr.class("mt-1 text-sm text-gh-muted")], [
          span([attr.class("font-medium text-gh-ink")], [text(c.author)]),
          text(" committed " <> time_format.format_commit_time(c.committed_at)),
          text(" · "),
          code([attr.class("font-mono text-xs")], [text(short_sha(c.sha))]),
        ]),
        p([attr.class("mt-2 text-sm text-gh-muted")], [
          text(
            "Browse files and folders as they were at this point in history.",
          ),
        ]),
      ])
  }
}

fn clone_url_card(model: Model, url: String, copied: Bool) -> Element(Msg) {
  let copy_label = case copied {
    True -> "Copied!"
    False -> "Copy"
  }
  div([attr.class(components.card <> " mb-6")], [
    div([attr.class("mb-3 flex flex-wrap items-center justify-between gap-2")], [
      p([attr.class(components.section_title <> " !mb-0")], [
        text("Clone via SSH"),
      ]),
      default_branch_ci_status(model),
    ]),
    div([attr.class("flex flex-col gap-2 sm:flex-row sm:items-stretch")], [
      code(
        [
          attr.class(
            components.code_block <> " min-w-0 flex-1 !text-xs sm:!text-sm",
          ),
        ],
        [text(url)],
      ),
      button(
        [
          attr.type_("button"),
          attr.class(components.btn_secondary <> " shrink-0 sm:!px-5"),
          event.on_click(CopyCloneUrl),
        ],
        [text(copy_label)],
      ),
    ]),
    download_zip_row(model),
  ])
}

fn default_branch_ci_status(model: Model) -> Element(Msg) {
  case model.detail {
    option.None -> text("")
    option.Some(detail) ->
      case detail.default_branch, detail.default_branch_pipeline {
        option.Some(branch), option.Some(pipeline) ->
          span([attr.class("ci-status-pill")], [
            span([], [text("CI · " <> branch)]),
            ci_status.status_circle(
              pipeline.state,
              "h-2.5 w-2.5",
              pipeline.state == "running" || pipeline.state == "queued",
            ),
            span([], [text(ci_status.status_label(pipeline.state))]),
          ])
        _, _ -> text("")
      }
  }
}

fn download_zip_row(model: Model) -> Element(Msg) {
  case model.detail {
    option.Some(detail) ->
      case detail.default_branch {
        option.Some(_) ->
          div([attr.class("mt-4")], [
            button(
              [
                attr.type_("button"),
                attr.class(components.btn_secondary),
                event.on_click(DownloadZip),
              ],
              [text("Download ZIP")],
            ),
          ])
        option.None -> text("")
      }
    option.None -> text("")
  }
}

fn commit_count_link(model: Model) -> Element(Msg) {
  case routes.is_commit_ref(model.ref) {
    True -> text("")
    False -> commit_count_link_for_branch(model)
  }
}

fn commit_count_link_for_branch(model: Model) -> Element(Msg) {
  case model.commit_total {
    option.None | option.Some(0) -> text("")
    option.Some(total) ->
      case model.ref {
        "" -> text("")
        branch -> {
          let label = case total {
            1 -> "1 commit"
            n -> int.to_string(n) <> " commits"
          }
          a(
            [
              attr.href(routes.commits_path(
                model.org_slug,
                model.repo_name,
                branch,
              )),
              attr.class(
                "text-sm font-bold text-gh-ink underline decoration-gh-accent decoration-2 underline-offset-2 hover:text-gh-accent",
              ),
            ],
            [text(label)],
          )
        }
      }
  }
}

fn toolbar(model: Model) -> Element(Msg) {
  div(
    [
      attr.class(
        "repo-toolbar mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between",
      ),
    ],
    [
      div([attr.class("flex flex-wrap items-center gap-3")], [
        ref_selector(model),
        commit_count_link(model),
      ]),
      path_breadcrumb(model),
    ],
  )
}

fn raw_browser_url(config: Config, model: Model) -> option.Option(String) {
  case config.token {
    option.Some(token) ->
      option.Some(
        config.api_url
        <> repo_raw_browser_path(
          model.org_slug,
          model.repo_name,
          model.ref,
          model.path,
          token,
        ),
      )
    option.None -> option.None
  }
}

fn blob_actions(model: Model, config: Config) -> Element(Msg) {
  div([attr.class("repo-blob-actions")], [
    case raw_browser_url(config, model) {
      option.Some(href) ->
        a(
          [
            attr.href(href),
            attr.target("_blank"),
            attr.rel("noopener noreferrer"),
            attr.class(components.btn_secondary),
          ],
          [text("Raw")],
        )
      option.None -> span([], [])
    },
    button(
      [
        attr.type_("button"),
        attr.class(components.btn_secondary),
        event.on_click(DownloadFile),
      ],
      [text("Download")],
    ),
  ])
}

fn blob_view(model: Model, config: Config) -> Element(Msg) {
  case model.blob {
    option.None ->
      div(
        [attr.class(components.card <> " comic-loading-state py-8")],
        [components.loading_spinner()],
      )
    option.Some(blob) ->
      div([attr.class(components.card)], [
        div([attr.class("repo-blob-header")], [
          span([attr.class("repo-blob-path")], [text(model.path)]),
          span([attr.class("repo-blob-size")], [
            text(int.to_string(blob.size) <> " bytes"),
          ]),
        ]),
        blob_actions(model, config),
        case blob.binary {
          True ->
            p([attr.class("repo-blob-binary-note")], [
              text("Binary file not shown."),
            ])
          False ->
            unsafe_raw_html(
              "",
              "div",
              [attr.class("repo-blob-panel")],
              highlight.to_html(blob.content, model.path, model.line_range),
            )
        },
      ])
  }
}

pub fn view(model: Model, config: Config) -> Element(Msg) {
  let clone_url = case model.detail {
    option.Some(d) -> d.clone_url
    option.None -> ""
  }
  let error = case model.error {
    option.Some(e) -> components.error_alert(e)
    option.None -> text("")
  }
  let body = case model.empty_repo, model.mode {
    True, _ ->
      components.empty_state(
        "This repository is empty. Push commits over SSH to add files.",
      )
    False, Blob ->
      div([], [
        commit_snapshot_banner(model),
        toolbar(model),
        blob_view(model, config),
      ])
    False, Tree ->
      div([], [
        commit_snapshot_banner(model),
        toolbar(model),
        div([attr.class(components.card)], [file_table(model)]),
      ])
    False, Home ->
      div([], [
        toolbar(model),
        div([attr.class(components.card <> " mb-6")], [file_table(model)]),
        readme_section(model),
      ])
  }

  let clone = case clone_url {
    "" -> text("")
    url -> clone_url_card(model, url, model.clone_copied)
  }
  let content = case model.loading {
    True -> components.loading_state()
    False -> div([], [clone, body])
  }
  repo_nav.shell(model.org_slug, model.repo_name, repo_nav.Code, [
    error,
    content,
  ])
}
