import components
import config.{type Config}
import content/markdown
import gleam/list
import gleam/option
import gleam/string
import gleam/uri
import http/api.{type Release, type Tag}
import http/lustre_http
import lustre/attribute as attr
import lustre/effect.{type Effect, batch, from, none}
import lustre/element.{type Element, text, unsafe_raw_html}
import lustre/element/html.{
  a, button, div, form, h2, input, label, li, option as html_option, p, select,
  span, textarea, ul,
}
import lustre/event
import modem
import pages/repo_nav
import routes.{
  RepoArchiveTarGz, RepoArchiveZip, commit_tree_path,
  release_detail_path, release_list_path, release_new_path, repo_archive_api_suffix,
}
import util/file_download
import util/time_format

pub type SourceArchiveFormat {
  SourceZip
  SourceTarGz
}

pub type Mode {
  List
  New
  Detail(String)
}

pub type Model {
  Model(
    org_slug: String,
    repo_name: String,
    mode: Mode,
    releases: List(Release),
    tags: List(Tag),
    selected_tag: String,
    title: String,
    body: String,
    detail: option.Option(Release),
    editing: Bool,
    edit_title: String,
    edit_body: String,
    saving: Bool,
    loading: Bool,
    error: option.Option(String),
  )
}

pub type Msg {
  ReleasesLoaded(Result(List(Release), lustre_http.HttpError))
  TagsLoaded(Result(List(Tag), lustre_http.HttpError))
  DetailLoaded(Result(Release, lustre_http.HttpError))
  TagChanged(String)
  TitleChanged(String)
  BodyChanged(String)
  Create
  Created(Result(Release, lustre_http.HttpError))
  DownloadSourceArchive(SourceArchiveFormat)
  StartEdit
  CancelEdit
  EditTitleChanged(String)
  EditBodyChanged(String)
  SaveEdit
  Saved(Result(Release, lustre_http.HttpError))
}

pub fn init(org_slug: String, repo_name: String, mode: Mode) -> Model {
  Model(
    org_slug:,
    repo_name:,
    mode:,
    releases: [],
    tags: [],
    selected_tag: "",
    title: "",
    body: "",
    detail: option.None,
    editing: False,
    edit_title: "",
    edit_body: "",
    saving: False,
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
}

fn load_releases(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model) <> "/releases",
    lustre_http.expect_json(api.releases_decoder(), ReleasesLoaded),
  )
}

fn load_tags(config: Config, model: Model) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model) <> "/tags",
    lustre_http.expect_json(api.tags_decoder(), TagsLoaded),
  )
}

fn load_detail(config: Config, model: Model, tag: String) -> Effect(Msg) {
  lustre_http.get(
    config,
    api_base(config, model)
      <> "/releases/"
      <> encode_tag_path(tag),
    lustre_http.expect_json(api.release_decoder(), DetailLoaded),
  )
}

fn encode_tag_path(tag: String) -> String {
  tag
  |> string.split(on: "/")
  |> list.map(uri.percent_encode)
  |> string.join(with: "/")
}

pub fn on_load(config: Config, model: Model) -> Effect(Msg) {
  case model.mode {
    List -> batch([load_releases(config, model), load_tags(config, model)])
    New -> batch([load_tags(config, model), load_releases(config, model)])
    Detail(tag) -> load_detail(config, model, tag)
  }
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    ReleasesLoaded(Ok(releases)) -> #(
      Model(..model, releases:, loading: False, error: option.None),
      none(),
    )
    ReleasesLoaded(Error(_)) -> #(
      Model(
        ..model,
        loading: False,
        error: option.Some("Failed to load releases"),
      ),
      none(),
    )
    TagsLoaded(Ok(tags)) -> {
      let selected = case tags {
        [] -> ""
        [first, ..] -> first.name
      }
      let title = case selected {
        "" -> ""
        name -> name
      }
      #(
        Model(
          ..model,
          tags:,
          selected_tag: selected,
          title:,
          loading: False,
          error: option.None,
        ),
        none(),
      )
    }
    TagsLoaded(Error(_)) -> #(
      Model(
        ..model,
        loading: False,
        error: option.Some("Failed to load tags"),
      ),
      none(),
    )
    DetailLoaded(Ok(release)) -> #(
      Model(
        ..model,
        detail: option.Some(release),
        edit_title: release.title,
        edit_body: release.body,
        loading: False,
        error: option.None,
      ),
      none(),
    )
    DetailLoaded(Error(_)) -> #(
      Model(
        ..model,
        loading: False,
        error: option.Some("Release not found"),
      ),
      none(),
    )
    TagChanged(tag) -> #(
      Model(..model, selected_tag: tag, title: tag),
      none(),
    )
    TitleChanged(title) -> #(Model(..model, title:), none())
    BodyChanged(body) -> #(Model(..model, body:), none())
    Create -> #(
      model,
      lustre_http.post(
        config,
        api_base(config, model) <> "/releases",
        api.create_release_body(
          model.selected_tag,
          model.title,
          case model.body {
            "" -> option.None
            text -> option.Some(text)
          },
        ),
        lustre_http.expect_json(api.release_decoder(), Created),
      ),
    )
    Created(Ok(release)) -> #(
      model,
      modem.replace(
        release_detail_path(
          model.org_slug,
          model.repo_name,
          release.tag_name,
        ),
        option.None,
        option.None,
      ),
    )
    Created(Error(_)) -> #(
      Model(..model, error: option.Some("Could not create release")),
      none(),
    )
    DownloadSourceArchive(format) ->
      case model.detail {
        option.Some(release) -> #(
          model,
          download_source_archive(config, model, release.tag_name, format),
        )
        option.None -> #(model, none())
      }
    StartEdit -> #(
      Model(..model, editing: True, error: option.None),
      none(),
    )
    CancelEdit ->
      case model.detail {
        option.Some(release) -> #(
          Model(
            ..model,
            editing: False,
            edit_title: release.title,
            edit_body: release.body,
            error: option.None,
          ),
          none(),
        )
        option.None -> #(Model(..model, editing: False), none())
      }
    EditTitleChanged(title) -> #(Model(..model, edit_title: title), none())
    EditBodyChanged(body) -> #(Model(..model, edit_body: body), none())
    SaveEdit ->
      case model.detail {
        option.Some(release) -> #(
          Model(..model, saving: True, error: option.None),
          lustre_http.patch(
            config,
            api_base(config, model)
              <> "/releases/"
              <> encode_tag_path(release.tag_name),
            api.update_release_body(
              string.trim(model.edit_title),
              case string.trim(model.edit_body) {
                "" -> option.None
                text -> option.Some(text)
              },
            ),
            lustre_http.expect_json(api.release_decoder(), Saved),
          ),
        )
        option.None -> #(model, none())
      }
    Saved(Ok(release)) -> #(
      Model(
        ..model,
        detail: option.Some(release),
        editing: False,
        edit_title: release.title,
        edit_body: release.body,
        saving: False,
        error: option.None,
      ),
      none(),
    )
    Saved(Error(_)) -> #(
      Model(
        ..model,
        saving: False,
        error: option.Some("Could not save release"),
      ),
      none(),
    )
  }
}

fn download_source_archive(
  config: Config,
  model: Model,
  tag: String,
  format: SourceArchiveFormat,
) -> Effect(Msg) {
  let archive_format = case format {
    SourceZip -> RepoArchiveZip
    SourceTarGz -> RepoArchiveTarGz
  }
  let ext = case format {
    SourceZip -> ".zip"
    SourceTarGz -> ".tar.gz"
  }
  let url =
    api_base(config, model)
    <> repo_archive_api_suffix(tag, archive_format)
  let filename = model.repo_name <> "-" <> tag <> ext
  case config.token {
    option.Some(token) ->
      from(fn(_) { file_download.download(url, token, filename) })
    option.None -> none()
  }
}

fn tags_without_releases(tags: List(Tag), releases: List(Release)) -> List(Tag) {
  list.filter(tags, fn(tag) {
    list.all(releases, fn(release) { release.tag_name != tag.name })
  })
}

fn short_sha(sha: String) -> String {
  string.slice(sha, 0, 7)
}

fn markdown_body(content: String) -> Element(Msg) {
  unsafe_raw_html(
    "",
    "div",
    [attr.class("markdown-body text-sm")],
    markdown.to_html(content),
  )
}

pub fn view(model: Model) -> Element(Msg) {
  let error = case model.error {
    option.Some(e) -> components.error_alert(e)
    option.None -> text("")
  }
  let body = case model.mode {
    List -> list_view(model)
    New -> new_view(model)
    Detail(_) -> detail_view(model)
  }
  repo_nav.shell(model.org_slug, model.repo_name, repo_nav.Releases, [
    error,
    body,
  ])
}

fn tag_row(model: Model, tag: Tag) -> Element(Msg) {
  div([attr.class(components.card <> " p-3 flex items-center justify-between gap-4")], [
    div([], [
      span([attr.class("font-mono font-semibold")], [text(tag.name)]),
      p([attr.class("text-sm text-gray-600 mt-1")], [
        text(time_format.format_timestamp(tag.created_at)),
        text(" · "),
        a(
          [
            attr.class("font-mono hover:underline"),
            attr.href(commit_tree_path(
              model.org_slug,
              model.repo_name,
              tag.target_commit_sha,
            )),
          ],
          [text(short_sha(tag.target_commit_sha))],
        ),
        case tag.message {
          "" -> text("")
          message -> text(" · " <> message)
        },
      ]),
    ]),
    a(
      [
        attr.class(components.btn_primary <> " text-sm"),
        attr.href(release_new_path(model.org_slug, model.repo_name)),
      ],
      [text("Create release")],
    ),
  ])
}

fn list_view(model: Model) -> Element(Msg) {
  let actions =
    div([attr.class("mb-4 flex justify-end")], [
      a(
        [
          attr.class(components.btn_primary),
          attr.href(release_new_path(model.org_slug, model.repo_name)),
        ],
        [text("Create release")],
      ),
    ])
  let content = case model.loading {
    True -> components.loading_state()
    False ->
      case model.releases, model.tags {
        [], [] ->
          p([attr.class("text-sm text-gray-600")], [
            text(
              "No tags yet. Create and push a tag, then add release notes here:",
            ),
            span([attr.class("block font-mono mt-2 text-xs")], [
              text("git tag v1.0.0 && git push origin v1.0.0"),
            ]),
          ])
        releases, tags -> {
          let unreleased_tags = tags_without_releases(tags, releases)
          div([attr.class("space-y-6")], [
            case releases {
              [] -> text("")
              _ ->
                div([], [
                  h2([attr.class("text-sm font-semibold uppercase mb-3")], [
                    text("Releases"),
                  ]),
                  div([attr.class("space-y-3")], list.map(releases, fn(release) {
                    release_card(model, release)
                  })),
                ])
            },
            case unreleased_tags {
              [] -> text("")
              _ ->
                div([], [
                  h2([attr.class("text-sm font-semibold uppercase mb-3")], [
                    text("Tags without releases"),
                  ]),
                  div([attr.class("space-y-2")], list.map(unreleased_tags, fn(tag) {
                    tag_row(model, tag)
                  })),
                ])
            },
          ])
        }
      }
  }
  div([], [actions, content])
}

fn release_card(model: Model, release: Release) -> Element(Msg) {
  div([attr.class(components.card <> " p-4")], [
    div([attr.class("flex items-start justify-between gap-4")], [
      div([], [
        h2([attr.class("text-lg font-semibold")], [
          a(
            [
              attr.href(release_detail_path(
                model.org_slug,
                model.repo_name,
                release.tag_name,
              )),
              attr.class("hover:underline"),
            ],
            [text(release.title)],
          ),
        ]),
        p([attr.class("text-sm text-gray-600 mt-1")], [
          span([attr.class("font-mono")], [text(release.tag_name)]),
          text(" · "),
          text(time_format.format_timestamp(release.created_at)),
          text(" · "),
          text(release.author_name),
        ]),
      ]),
      a(
        [
          attr.class("text-sm font-mono text-blue-600 hover:underline shrink-0"),
          attr.href(commit_tree_path(
            model.org_slug,
            model.repo_name,
            release.target_commit_sha,
          )),
        ],
        [text(short_sha(release.target_commit_sha))],
      ),
    ]),
  ])
}

fn new_view(model: Model) -> Element(Msg) {
  let available = tags_without_releases(model.tags, model.releases)
  div([], [
    p([attr.class("mb-4 text-sm")], [
      a(
        [
          attr.href(release_list_path(model.org_slug, model.repo_name)),
          attr.class("hover:underline"),
        ],
        [text("← Back to releases")],
      ),
    ]),
    case model.loading {
      True -> components.loading_state()
      False ->
        case available {
          [] ->
            p([attr.class("text-sm text-gray-600")], [
              text(
                "No tags available for a new release. Create and push a git tag first:",
              ),
              span([attr.class("block font-mono mt-2 text-xs")], [
                text("git tag v1.0.0 && git push origin v1.0.0"),
              ]),
            ])
          tags ->
            form([event.on_submit(fn(_) { Create })], [
              div([attr.class("space-y-4 max-w-xl")], [
                div([], [
                  label([attr.for("tag")], [text("Tag")]),
                  select(
                    [
                      attr.id("tag"),
                      attr.class(components.input <> " mt-1"),
                      event.on_change(TagChanged),
                    ],
                    list.map(tags, fn(tag) {
                      html_option(
                        [
                          attr.value(tag.name),
                          attr.selected(model.selected_tag == tag.name),
                        ],
                        tag.name,
                      )
                    }),
                  ),
                ]),
                div([], [
                  label([attr.for("title")], [text("Release title")]),
                  input([
                    attr.id("title"),
                    attr.type_("text"),
                    attr.class(components.input <> " mt-1 w-full"),
                    attr.value(model.title),
                    event.on_input(TitleChanged),
                  ]),
                ]),
                div([], [
                  label([attr.for("body")], [text("Release notes")]),
                  textarea(
                    [
                      attr.id("body"),
                      attr.class(components.textarea <> " mt-1 w-full min-h-40"),
                      event.on_input(BodyChanged),
                    ],
                    model.body,
                  ),
                ]),
                button([attr.type_("submit"), attr.class(components.btn_primary)], [
                  text("Create release"),
                ]),
              ]),
            ])
        }
    },
  ])
}

fn detail_view(model: Model) -> Element(Msg) {
  case model.loading {
    True -> components.loading_state()
    False ->
      case model.detail {
        option.None -> text("")
        option.Some(release) ->
          div([attr.class("space-y-4")], [
            detail_header(model, release),
            detail_body(model, release),
            source_assets(model, release),
          ])
      }
  }
}

fn detail_header(model: Model, release: Release) -> Element(Msg) {
  div([], [
    div([attr.class("flex items-start justify-between gap-4")], [
      case model.editing {
        True ->
          input([
            attr.type_("text"),
            attr.class(components.input <> " text-2xl font-semibold w-full"),
            attr.value(model.edit_title),
            event.on_input(EditTitleChanged),
          ])
        False ->
          h2([attr.class("text-2xl font-semibold")], [text(release.title)])
      },
      detail_toolbar(model),
    ]),
    p([attr.class("text-sm text-gray-600 mt-2")], [
      span([attr.class("font-mono")], [text(release.tag_name)]),
      text(" · "),
      text(time_format.format_timestamp(release.created_at)),
      text(" · "),
      text(release.author_name),
      text(" · "),
      a(
        [
          attr.class("font-mono hover:underline"),
          attr.href(commit_tree_path(
            model.org_slug,
            model.repo_name,
            release.target_commit_sha,
          )),
        ],
        [text(short_sha(release.target_commit_sha))],
      ),
    ]),
  ])
}

fn detail_toolbar(model: Model) -> Element(Msg) {
  case model.editing {
    True ->
      div([attr.class("flex gap-2 shrink-0")], [
        button(
          [
            attr.type_("button"),
            attr.class(components.btn_secondary <> " text-sm"),
            attr.disabled(model.saving),
            event.on_click(CancelEdit),
          ],
          [text("Cancel")],
        ),
        button(
          [
            attr.type_("button"),
            attr.class(components.btn_primary <> " text-sm"),
            attr.disabled(model.saving),
            event.on_click(SaveEdit),
          ],
          [text("Save")],
        ),
      ])
    False ->
      button(
        [
          attr.type_("button"),
          attr.class(components.btn_secondary <> " text-sm shrink-0"),
          event.on_click(StartEdit),
        ],
        [text("Edit")],
      )
  }
}

fn detail_body(model: Model, release: Release) -> Element(Msg) {
  case model.editing {
    True ->
      div([attr.class(components.card <> " p-4")], [
        label([attr.for("release-body")], [text("Release notes")]),
        textarea(
          [
            attr.id("release-body"),
            attr.class(components.textarea <> " mt-2 w-full min-h-48"),
            event.on_input(EditBodyChanged),
          ],
          model.edit_body,
        ),
      ])
    False ->
      case release.body {
        "" ->
          p([attr.class("text-sm italic text-gray-600")], [
            text("No release notes."),
          ])
        body -> div([attr.class(components.card <> " p-4")], [markdown_body(body)])
      }
  }
}

fn source_assets(_model: Model, release: Release) -> Element(Msg) {
  div([attr.class(components.card <> " p-4")], [
    h2([attr.class("text-sm font-semibold uppercase mb-3")], [text("Source code")]),
    ul([attr.class("space-y-2 text-sm")], [
      li([], [
        button(
          [
            attr.type_("button"),
            attr.class("font-mono hover:underline text-left"),
            event.on_click(DownloadSourceArchive(SourceZip)),
          ],
          [text("Source code (zip)")],
        ),
      ]),
      li([], [
        button(
          [
            attr.type_("button"),
            attr.class("font-mono hover:underline text-left"),
            event.on_click(DownloadSourceArchive(SourceTarGz)),
          ],
          [text("Source code (tar.gz)")],
        ),
      ]),
    ]),
    p([attr.class("text-xs text-gray-600 mt-3")], [
      text("Snapshot of the repository at tag "),
      span([attr.class("font-mono")], [text(release.tag_name)]),
      text("."),
    ]),
  ])
}
