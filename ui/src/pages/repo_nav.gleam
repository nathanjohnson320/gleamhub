import components
import gleam/list
import lustre/attribute as attr
import lustre/element.{type Element, text}
import lustre/element/html.{a, div, h1, span}
import routes

pub type Tab {
  Code
  Issues
  Milestones
  MergeRequests
  Releases
  Settings
}

pub fn tab_path(tab: Tab, org_slug: String, repo_name: String) -> String {
  case tab {
    Code -> routes.repo_home_path(org_slug, repo_name)
    Issues -> routes.issue_list_path(org_slug, repo_name)
    Milestones -> routes.milestone_list_path(org_slug, repo_name)
    MergeRequests -> routes.mr_list_path(org_slug, repo_name)
    Releases -> routes.release_list_path(org_slug, repo_name)
    Settings -> routes.repo_settings_path(org_slug, repo_name)
  }
}

pub fn tabs(org_slug: String, repo_name: String, active: Tab) -> Element(a) {
  let items = [
    #(Code, "Code"),
    #(Issues, "Issues"),
    #(Milestones, "Milestones"),
    #(MergeRequests, "Merge requests"),
    #(Releases, "Releases"),
    #(Settings, "Settings"),
  ]
  div([attr.class(components.comic_tabs)], list.map(items, fn(item) {
      let #(tab, label) = item
      let is_active = tab == active
      let classes = case is_active {
        True -> components.comic_tab_active
        False -> components.comic_tab
      }
      a([attr.class(classes), attr.href(tab_path(tab, org_slug, repo_name))], [
        text(label),
      ])
    }),
  )
}

pub fn title(org_slug: String, repo_name: String) -> Element(a) {
  h1([attr.class(components.page_title <> " comic-repo-title")], [
    a(
      [
        attr.href(routes.org_repos_path(org_slug)),
        attr.class("comic-repo-title-org"),
      ],
      [text(org_slug)],
    ),
    span([attr.class("comic-repo-title-sep")], [text("/")]),
    span([attr.class("comic-repo-title-name")], [text(repo_name)]),
  ])
}

pub fn shell(
  org_slug: String,
  repo_name: String,
  active: Tab,
  children: List(Element(a)),
) -> Element(a) {
  div([attr.class(components.page <> " max-w-5xl")], [
    components.breadcrumb_back("/orgs/" <> org_slug, "Repositories"),
    div([attr.class("mb-5")], [title(org_slug, repo_name)]),
    tabs(org_slug, repo_name, active),
    div([attr.class("mt-2")], children),
  ])
}
