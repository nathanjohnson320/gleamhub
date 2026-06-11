import components
import gleam/list
import lustre/attribute as attr
import lustre/element.{type Element, text}
import lustre/element/html.{a, div}
import routes.{type MyTab, MyNotifications, MyOverview}

pub fn tab_path(tab: MyTab) -> String {
  routes.my_tab_path(tab)
}

pub fn tabs(active: MyTab, unread_notifications: Int) -> Element(a) {
  let items = [
    #(MyOverview, "Overview"),
    #(MyNotifications, "Notifications"),
  ]
  div([attr.class(components.comic_tabs)], list.map(items, fn(item) {
      let #(tab, label) = item
      let is_active = tab == active
      let classes = case is_active {
        True -> components.comic_tab_active
        False -> components.comic_tab
      }
      let label_content = case tab {
        MyNotifications ->
          [text(label), components.unread_count_badge(unread_notifications)]
        _ -> [text(label)]
      }
      a([attr.class(classes), attr.href(tab_path(tab))], label_content)
    }),
  )
}
