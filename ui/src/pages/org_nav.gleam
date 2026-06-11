import components
import gleam/list
import lustre/attribute as attr
import lustre/element.{type Element, text}
import lustre/element/html.{a, div}
import routes

pub type Tab {
  Repositories
  Members
}

pub fn tab_path(tab: Tab, org_slug: String) -> String {
  case tab {
    Repositories -> routes.org_repos_path(org_slug)
    Members -> routes.org_members_path(org_slug)
  }
}

pub fn tabs(org_slug: String, active: Tab) -> Element(a) {
  let items = [
    #(Repositories, "Repositories"),
    #(Members, "Members"),
  ]
  div([attr.class(components.comic_tabs)], list.map(items, fn(item) {
      let #(tab, label) = item
      let is_active = tab == active
      let classes = case is_active {
        True -> components.comic_tab_active
        False -> components.comic_tab
      }
      a([attr.class(classes), attr.href(tab_path(tab, org_slug))], [text(label)])
    }),
  )
}
