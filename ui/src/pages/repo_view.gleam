import api.{
  type BlobView, type MrCommit, type Org, type Readme, type RepoCommits,
  type RepoDetail, type TreeEntry, type TreeListing,
}
import time_format
import components
import config.{type Config}
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/uri
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element, text, unsafe_raw_html}
import lustre/element/html.{
  a, button, code, div, h2, h3, input, li, option, p, select, span, table, tbody, td,
  th, thead, tr, ul,
}
import lustre/event
import lustre_http
import blob_lines
import clipboard
import highlight
import markdown
import modem
import routes.{type ViewMode, Blob, Home, Tree}

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
    org_role: option.Option(String),
    protected_branches: List(String),
    protected_input: String,
    saving_protected: Bool,
    clone_copied: Bool,
    commit_total: option.Option(Int),
    viewing_commit: option.Option(MrCommit),
    error: option.Option(String),
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
  OrgLoaded(Result(Org, lustre_http.HttpError))
  ProtectedBranchesLoaded(Result(List(String), lustre_http.HttpError))
  ProtectedInputChanged(String)
  AddProtectedBranch
  RemoveProtectedBranch(String)
  ProtectedBranchesSaved(Result(List(String), lustre_http.HttpError))
}

pub fn init(
  org_slug: String,
  repo_name: String,
  mode: ViewMode,
  ref: String,
  path: String,
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
    org_role: option.None,
    protected_branches: [],
    protected_input: "",
    saving_protected: False,
    clone_copied: False,
    commit_total: option.None,
    viewing_commit: option.None,
    error: option.None,
  )
}

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  case model.mode {
    Blob ->
      effect.batch([
        load_blob(config, model),
        load_branches(config, model),
        load_commit(config, model),
        load_commits_summary(config, model),
      ])
    Tree ->
      effect.batch([
        load_tree(config, model),
        load_branches(config, model),
        load_commit(config, model),
        load_commits_summary(config, model),
      ])
    Home ->
      effect.batch([
        load_detail(config, model),
        load_branches(config, model),
        load_org(config, model),
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
            api_base(config, model) <> "/commits?ref=" <> uri.percent_encode(ref),
            lustre_http.expect_json(api.repo_commits_decoder(), CommitsSummaryLoaded),
          )
      }
  }
}

fn load_commit(config: Config, model: Model) -> Effect(Msg) {
  case routes.is_commit_ref(model.ref) {
    True ->
      lustre_http.get(
        config,
        api_base(config, model) <> "/commit?sha=" <> uri.percent_encode(model.ref),
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
  config.api_url <> "/api/orgs/" <> model.org_slug <> "/repos/" <> model.repo_name
}

fn load_org(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    config.api_url <> "/api/orgs/" <> model.org_slug,
    lustre_http.expect_json(api.org_decoder(), OrgLoaded),
  )
}

fn load_protected_branches(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model) <> "/protected-branches",
    lustre_http.expect_json(api.protected_branches_decoder(), ProtectedBranchesLoaded),
  )
}

fn save_protected_branches(
  config: Config,
  model: Model,
  branches: List(String),
) -> Effect(Msg) {
  lustre_http.put(
    config,
    api_base(config, model) <> "/protected-branches",
    api.protected_branches_body(branches),
    lustre_http.expect_json(api.protected_branches_decoder(), ProtectedBranchesSaved),
  )
}

fn is_owner(model: Model) -> Bool {
  model.org_role == option.Some("owner")
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
      let base = api_base(config, model) <> "/tree/" <> uri.percent_encode(ref)
      let url = case model.path {
        "" -> base
        _ -> base <> "/" <> model.path
      }
      lustre_http.get(
        config,
        url,
        lustre_http.expect_json(api.tree_decoder(), LoadedTree),
      )
    }
  }
}

fn load_blob(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model)
      <> "/blob/"
      <> model.ref
      <> "/"
      <> model.path,
    lustre_http.expect_json(api.blob_decoder(), LoadedBlob),
  )
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
      #(
        model,
        case had_ref {
          False -> home_content_effects(config, model)
          True -> effect.none()
        },
      )
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
      let model =
        Model(
          ..model,
          branches:,
          empty_repo: branches == [],
          ref:,
        )
      #(
        model,
        case had_ref {
          False -> home_content_effects(config, model)
          True -> effect.none()
        },
      )
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
      blob_lines.init_effect(),
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
    OrgLoaded(Ok(org)) -> #(
      Model(..model, org_role: org.role),
      case org.role {
        option.Some("owner") -> load_protected_branches(config, model)
        _ -> effect.none()
      },
    )
    OrgLoaded(Error(_)) -> #(model, effect.none())
    ProtectedBranchesLoaded(Ok(branches)) -> #(
      Model(..model, protected_branches: branches),
      effect.none(),
    )
    ProtectedBranchesLoaded(Error(_)) -> #(model, effect.none())
    ProtectedInputChanged(value) -> #(
      Model(..model, protected_input: value),
      effect.none(),
    )
    AddProtectedBranch -> {
      let name = string.trim(model.protected_input)
      case name {
        "" -> #(model, effect.none())
        _ ->
          case list.contains(model.protected_branches, name) {
            True -> #(
              Model(..model, error: option.Some("Branch is already protected")),
              effect.none(),
            )
            False -> {
              let branches = list.append(model.protected_branches, [name])
              #(
                Model(
                  ..model,
                  protected_branches: branches,
                  protected_input: "",
                  saving_protected: True,
                  error: option.None,
                ),
                save_protected_branches(config, model, branches),
              )
            }
          }
      }
    }
    RemoveProtectedBranch(name) -> {
      let branches =
        list.filter(model.protected_branches, fn(b) { b != name })
      #(
        Model(..model, protected_branches: branches, saving_protected: True),
        save_protected_branches(config, model, branches),
      )
    }
    ProtectedBranchesSaved(Ok(branches)) -> #(
      Model(..model, protected_branches: branches, saving_protected: False),
      effect.none(),
    )
    ProtectedBranchesSaved(Error(lustre_http.OtherError(403, _))) -> #(
      Model(
        ..model,
        saving_protected: False,
        error: option.Some("Only organization owners can change protected branches"),
      ),
      effect.none(),
    )
    ProtectedBranchesSaved(Error(_)) -> #(
      Model(
        ..model,
        saving_protected: False,
        error: option.Some("Could not save protected branches"),
      ),
      effect.none(),
    )
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

fn entry_icon(entry_type: String) -> String {
  case entry_type {
    "tree" -> "📁"
    "submodule" -> "📦"
    _ -> "📄"
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
      routes.repo_blob_path(model.org_slug, model.repo_name, model.ref, file_path)
    }
  }
  let commit_cell = case entry.last_commit_message {
    "" -> td([attr.class("repo-file-commit text-sm text-gh-muted")], [text("—")])
    _ -> {
      let commit_sha_cell = case entry.last_commit_sha {
        "" ->
          span([attr.class("text-sm text-gh-muted truncate")], [
            text(entry.last_commit_message),
          ])
        sha ->
          a(
            [
              attr.href(routes.commit_tree_path(model.org_slug, model.repo_name, sha)),
              attr.class("text-sm text-gh-muted hover:text-gh-accent"),
              attr.title(entry.last_commit_message),
            ],
            [text(entry.last_commit_message)],
          )
      }
      td([attr.class("repo-file-commit max-w-md")], [commit_sha_cell])
    }
  }
  let sha_display = case entry.last_commit_sha {
    "" -> string.slice(entry.sha, 0, 7)
    sha -> string.slice(sha, 0, 7)
  }
  let sha_cell = case entry.last_commit_sha {
    "" ->
      td([attr.class("repo-file-meta text-right font-mono text-xs text-gh-muted")], [
        text(sha_display),
      ])
    sha ->
      td([attr.class("repo-file-meta text-right font-mono text-xs")], [
        a(
          [
            attr.href(routes.commit_tree_path(model.org_slug, model.repo_name, sha)),
            attr.class("text-gh-muted hover:text-gh-accent"),
          ],
          [text(sha_display)],
        ),
      ])
  }
  tr([attr.class("repo-file-row")], [
    td([attr.class("repo-file-name")], [
      a([attr.href(href), attr.class("text-gh-accent hover:underline")], [
        text(entry_icon(entry.entry_type) <> " " <> entry.name),
      ]),
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
          table([attr.class("repo-file-table w-full")], [
            thead([], [
              tr([], [
                th([attr.class("text-left text-sm text-gh-muted")], [text("Name")]),
                th([attr.class("text-left text-sm text-gh-muted")], [
                  text("Last commit"),
                ]),
                th([attr.class("text-right text-sm text-gh-muted")], [
                  text("SHA"),
                ]),
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
        div([attr.class("repo-readme-header border-b border-slate-200 px-4 py-3")], [
          a(
            [
              attr.href(
                routes.repo_blob_path(
                  model.org_slug,
                  model.repo_name,
                  model.ref,
                  readme.path,
                ),
              ),
              attr.class("text-sm font-semibold text-gh-ink hover:text-gh-accent"),
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
  let segments =
    case model.path {
      "" -> []
      p -> string.split(p, on: "/")
    }
  let root =
    a(
      [
        attr.href(routes.repo_tree_path(model.org_slug, model.repo_name, model.ref, "")),
        attr.class("font-semibold text-gh-ink hover:text-gh-accent"),
      ],
      [text(model.repo_name)],
    )
  let parts = list.index_map(segments, fn(seg, idx) {
    let subpath =
      segments
      |> list.take(idx + 1)
      |> string.join(with: "/")
    #(
      idx,
      a(
        [
          attr.href(
            routes.repo_tree_path(model.org_slug, model.repo_name, model.ref, subpath),
          ),
          attr.class("text-gh-ink hover:text-gh-accent"),
        ],
        [text(seg)],
      ),
    )
  })
  div([attr.class("repo-path-breadcrumb flex flex-wrap items-center gap-1 text-sm")], [
    root,
    ..list.flat_map(parts, fn(part) {
      let #(_, link) = part
      [span([attr.class("text-gh-muted")], [text("/")]), link]
    }),
  ])
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
        span([attr.class("text-sm font-medium text-gh-muted")], [text("Branch")]),
        branch_select(model),
      ])
    True ->
      div([attr.class("flex flex-wrap items-center gap-2")], [
        span([attr.class("text-sm font-medium text-gh-muted")], [text("Commit")]),
        code(
          [
            attr.class(
              "rounded-md border border-slate-200 bg-slate-50 px-2 py-1 font-mono text-xs text-gh-ink",
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
            [option([attr.value(""), attr.selected(False)], "Switch to branch…")],
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
        p([attr.class("text-xs font-semibold uppercase tracking-wide text-gh-muted")], [
          text("Snapshot at this commit"),
        ]),
        h3([attr.class("mt-1 text-lg font-semibold text-gh-ink")], [text(c.subject)]),
        p([attr.class("mt-1 text-sm text-gh-muted")], [
          span([attr.class("font-medium text-gh-ink")], [text(c.author)]),
          text(" committed " <> time_format.format_commit_time(c.committed_at)),
          text(" · "),
          code([attr.class("font-mono text-xs")], [text(short_sha(c.sha))]),
        ]),
        p([attr.class("mt-2 text-sm text-gh-muted")], [
          text("Browse files and folders as they were at this point in history."),
        ]),
      ])
  }
}

fn protected_branches_card(model: Model) -> Element(Msg) {
  case is_owner(model) {
    False -> text("")
    True ->
      div([attr.class(components.card <> " mb-6")], [
        h3([attr.class("mb-2 text-sm font-semibold text-gh-ink")], [
          text("Protected branches"),
        ]),
        p([attr.class("mb-3 text-sm text-gh-muted")], [
          text(
            "Direct pushes to these branches are blocked over SSH; use merge requests to update them.",
          ),
        ]),
        case model.protected_branches {
          [] -> text("")
          branches ->
            ul(
              [attr.class("mb-3 space-y-2")],
              list.map(branches, fn(branch) {
                li(
                  [attr.class("flex items-center justify-between gap-2 text-sm")],
                  [
                    span([attr.class("font-mono text-gh-ink")], [text(branch)]),
                    button(
                      [
                        attr.type_("button"),
                        attr.class(components.btn_secondary <> " !py-1 !text-xs"),
                        attr.disabled(model.saving_protected),
                        event.on_click(RemoveProtectedBranch(branch)),
                      ],
                      [text("Remove")],
                    ),
                  ],
                )
              }),
            )
        },
        div([attr.class("flex flex-wrap gap-2")], [
          input([
            attr.type_("text"),
            attr.placeholder("Branch name"),
            attr.value(model.protected_input),
            attr.class(components.input <> " !max-w-xs"),
            event.on_input(ProtectedInputChanged),
          ]),
          button(
            [
              attr.type_("button"),
              attr.class(components.btn_primary),
              attr.disabled(model.saving_protected),
              event.on_click(AddProtectedBranch),
            ],
            [text("Add")],
          ),
        ]),
      ])
  }
}

fn repo_header(model: Model, clone_url: String) -> Element(Msg) {
  div(
    [
      attr.class(
        "repo-header mb-6 rounded-xl border border-slate-200/80 bg-white p-5 shadow-sm ring-1 ring-slate-900/5",
      ),
    ],
    [
      div(
        [attr.class("flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between")],
        [
          div([attr.class("min-w-0")], [
            p([attr.class("text-sm font-medium text-gh-muted")], [text(model.org_slug)]),
            h2(
              [attr.class("mt-0.5 text-2xl font-bold tracking-tight text-gh-ink")],
              [text(model.repo_name)],
            ),
          ]),
          a(
            [
              attr.href(routes.mr_list_path(model.org_slug, model.repo_name)),
              attr.class(components.btn_secondary <> " shrink-0"),
            ],
            [text("Merge requests")],
          ),
        ],
      ),
      case clone_url {
        "" -> text("")
        url -> clone_url_block(url, model.clone_copied)
      },
    ],
  )
}

fn clone_url_block(url: String, copied: Bool) -> Element(Msg) {
  let copy_label = case copied {
    True -> "Copied!"
    False -> "Copy"
  }
  div([attr.class("mt-1 border-t border-slate-100 pt-4")], [
    p([attr.class("mb-2 text-xs font-semibold uppercase tracking-wide text-gh-muted")], [
      text("Clone via SSH"),
    ]),
    div([attr.class("flex flex-col gap-2 sm:flex-row sm:items-stretch")], [
      code(
        [
          attr.class(
            "min-w-0 flex-1 break-all rounded-lg border border-slate-200 bg-slate-50 px-3 py-2.5 font-mono text-xs text-gh-ink sm:text-sm",
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
  ])
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
              attr.href(routes.commits_path(model.org_slug, model.repo_name, branch)),
              attr.class("text-sm font-medium text-gh-accent hover:underline"),
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
        "repo-toolbar mb-4 flex flex-col gap-3 rounded-xl border border-slate-200/80 bg-white px-4 py-3 shadow-sm ring-1 ring-slate-900/5 sm:flex-row sm:items-center sm:justify-between",
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

fn blob_view(model: Model) -> Element(Msg) {
  case model.blob {
    option.None ->
      div([attr.class(components.card)], [text("Loading file…")])
    option.Some(blob) ->
      div([attr.class(components.card)], [
        h2([attr.class("mb-3 text-sm font-semibold text-gh-muted")], [
          text(int.to_string(blob.size) <> " bytes"),
        ]),
        case blob.binary {
          True ->
            p([attr.class("text-sm text-gh-muted")], [
              text("Binary file not shown."),
            ])
          False ->
            unsafe_raw_html(
              "",
              "div",
              [attr.class("repo-blob-panel max-h-[70vh] overflow-auto rounded-lg")],
              highlight.to_html(blob.content, model.path),
            )
        },
      ])
  }
}

pub fn view(model: Model) -> Element(Msg) {
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
        blob_view(model),
      ])
    False, Tree ->
      div([], [
        commit_snapshot_banner(model),
        toolbar(model),
        div([attr.class(components.card)], [file_table(model)]),
      ])
    False, Home ->
      div([], [
        protected_branches_card(model),
        toolbar(model),
        div([attr.class(components.card <> " mb-6")], [file_table(model)]),
        readme_section(model),
      ])
  }

  div([attr.class(components.page <> " max-w-5xl")], [
    components.breadcrumb_back(
      "/orgs/" <> model.org_slug,
      "Repositories",
    ),
    repo_header(model, clone_url),
    error,
    case model.loading {
      True ->
        div([], [
          components.empty_state("Loading repository…"),
        ])
      False -> body
    },
  ])
}
