import components
import lustre/attribute as attr
import lustre/element.{type Element}
import lustre/element/html.{div}

pub const profile_element_id = "clerk-user-profile"

pub fn view() -> Element(msg) {
  div([attr.class(components.page)], [
    components.page_header(
      "Account",
      "Manage your profile, security, and connected accounts.",
    ),
    div(
      [
        attr.id(profile_element_id),
        attr.class("clerk-user-profile-shell w-full"),
      ],
      [],
    ),
  ])
}
