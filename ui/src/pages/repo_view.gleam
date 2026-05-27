import api.{
  type BlobView, type Readme, type RepoDetail, type TreeEntry, type TreeListing,
}
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
  a, div, h2, option, p, select, span, table, tbody, td, th, thead, tr,
}
import lustre/event
import lustre_http
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
    error: option.Option(String),
  )
}

pub type Msg {
  LoadedDetail(Result(RepoDetail, lustre_http.HttpError))
  LoadedBranches(Result(List(String), lustre_http.HttpError))
  LoadedReadme(Result(Readme, lustre_http.HttpError))
  LoadedTree(Result(TreeListing, lustre_http.HttpError))
  LoadedBlob(Result(BlobView, lustre_http.HttpError))
  BranchChanged(String)
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
    error: option.None,
  )
}

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  case model.mode {
    Blob -> effect.batch([load_blob(config, model), load_branches(config, model)])
    Tree -> effect.batch([load_tree(config, model), load_branches(config, model)])
    Home ->
      effect.batch([
        load_detail(config, model),
        load_branches(config, model),
      ])
  }
}

fn home_content_effects(config: Config, model: Model) -> Effect(Msg) {
  case model.mode, model.ref {
    Home, ref if ref != "" ->
      effect.batch([
        load_readme(config, model),
        load_tree(config, model),
      ])
    _, _ -> effect.none()
  }
}

fn api_base(config: Config, model: Model) -> String {
  config.api_url <> "/api/orgs/" <> model.org_slug <> "/repos/" <> model.repo_name
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
      effect.none(),
    )
    LoadedBlob(Error(_)) -> #(
      Model(..model, error: option.Some("Could not load file"), loading: False),
      effect.none(),
    )
    BranchChanged(new_ref) -> {
      case model.mode {
        Home -> #(
          Model(..model, ref: new_ref, loading: True),
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
  tr([attr.class("repo-file-row")], [
    td([attr.class("repo-file-name")], [
      a([attr.href(href), attr.class("text-gh-accent hover:underline")], [
        text(entry_icon(entry.entry_type) <> " " <> entry.name),
      ]),
    ]),
    td([attr.class("repo-file-meta text-right font-mono text-xs text-gh-muted")], [
      text(string.slice(entry.sha, 0, 7)),
    ]),
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

fn toolbar(model: Model) -> Element(Msg) {
  div(
    [attr.class("repo-toolbar mb-4 flex flex-col gap-3 sm:flex-row sm:items-center")],
    [
      div([attr.class("flex items-center gap-2")], [
        span([attr.class("text-sm text-gh-muted")], [text("Branch:")]),
        branch_select(model),
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
  let title = model.org_slug <> " / " <> model.repo_name
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
      div([], [toolbar(model), blob_view(model)])
    False, Tree ->
      div([], [toolbar(model), div([attr.class(components.card)], [file_table(model)])])
    False, Home ->
      div([], [
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
    div([attr.class("repo-header mb-4")], [
      h2([attr.class("text-2xl font-bold text-gh-ink")], [text(title)]),
      case clone_url {
        "" -> text("")
        url ->
          p([attr.class("mt-2 " <> components.code_block)], [text(url)])
      },
    ]),
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
