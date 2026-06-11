import gleam/int
import gleam/option
import lustre/attribute as attr
import lustre/element.{type Element, text}
import lustre/element/html.{a, button, div, h1, h2, label, p, span}
import lustre/event

pub const page = "mx-auto w-full max-w-3xl px-4 py-8 sm:px-6 lg:px-8"

pub const page_title = "comic-page-title"

pub const page_title_sm = "comic-page-title comic-page-title-sm"

pub const detail_title = "comic-page-title comic-page-title-sm comic-detail-title"

pub const page_eyebrow = "comic-page-eyebrow"

pub const page_lead = "comic-page-lead"

pub const card = "comic-panel p-6"

pub const section_title = "mb-4 text-sm font-black uppercase tracking-widest text-gh-ink"

pub const input = "comic-input w-full px-4 py-2.5 text-sm text-gh-ink outline-none transition placeholder:text-gh-muted focus:border-gh-accent"

pub const textarea = "comic-input w-full min-h-[120px] px-4 py-2.5 font-mono text-sm text-gh-ink outline-none transition placeholder:text-gh-muted focus:border-gh-accent"

pub const btn_primary = "comic-pop inline-flex items-center justify-center bg-gh-accent px-4 py-2.5 text-sm font-black uppercase tracking-wide text-gh-ink transition hover:bg-gh-accent-hover focus:outline-none disabled:cursor-not-allowed disabled:opacity-50"

pub const btn_secondary = "comic-pop inline-flex items-center justify-center bg-white px-4 py-2.5 text-sm font-bold uppercase tracking-wide text-gh-ink transition hover:bg-gh-banana-soft"

pub const btn_danger = "comic-pop inline-flex items-center justify-center border-red-700 bg-gh-danger-soft px-3 py-1.5 text-sm font-bold text-gh-danger transition hover:bg-red-100"

pub const link_back = "comic-back"

pub const comic_tabs = "comic-tabs mb-5"

pub const comic_tab = "comic-tab"

pub const comic_tab_active = "comic-tab comic-tab-active"

pub const comic_list_toolbar = "comic-list-toolbar"

pub const comic_list_count = "comic-list-count"

pub const comic_list_search = "comic-list-search"

pub const comic_filter_tabs = "comic-filter-tabs"

pub const comic_filter_tab = "comic-filter-tab"

pub const comic_filter_tab_active = "comic-filter-tab comic-filter-tab-active"

pub const comic_list_table = "comic-list-table"

pub const list_item = "comic-panel-inset flex flex-col gap-1 px-4 py-3 transition hover:border-gh-accent hover:bg-gh-accent-soft/50 sm:flex-row sm:items-center sm:justify-between"

pub const code_block = "break-all border-[3px] border-gh-ink bg-gh-navy-deep px-3 py-2 font-mono text-xs text-gh-banana-soft"

pub fn error_alert(message: String) -> Element(msg) {
  div(
    [
      attr.class(
        "comic-panel mb-6 border-red-700 bg-gh-danger-soft px-4 py-3 text-sm font-medium text-red-800",
      ),
    ],
    [text(message)],
  )
}

pub fn empty_state(message: String) -> Element(msg) {
  p(
    [
      attr.class(
        "comic-panel-inset border-dashed px-4 py-8 text-center text-sm font-medium text-gh-muted",
      ),
    ],
    [text(message)],
  )
}

pub fn loading_state() -> Element(msg) {
  div(
    [
      attr.class(
        "comic-panel-inset comic-loading-state border-dashed px-4 py-8",
      ),
    ],
    [loading_spinner()],
  )
}

pub fn loading_spinner() -> Element(msg) {
  div(
    [
      attr.class("comic-loading-spinner"),
      attr.attribute("role", "status"),
      attr.attribute("aria-label", "Loading"),
    ],
    [
      span([attr.class("comic-loading-spinner-dot"), attr.attribute("aria-hidden", "true")], []),
      span([attr.class("comic-loading-spinner-dot"), attr.attribute("aria-hidden", "true")], []),
      span([attr.class("comic-loading-spinner-dot"), attr.attribute("aria-hidden", "true")], []),
    ],
  )
}

pub fn unread_count_badge(count: Int) -> Element(msg) {
  case count {
    0 -> text("")
    _ ->
      span(
        [
          attr.class(
            "comic-badge inline-flex min-w-[1.25rem] items-center justify-center bg-gh-accent px-1.5 py-0.5 text-xs font-black leading-none text-gh-ink",
          ),
          attr.attribute("aria-label", int.to_string(count) <> " unread"),
        ],
        [text(int.to_string(count))],
      )
  }
}

pub fn page_header(title: String, lead: String) -> Element(msg) {
  div([attr.class("comic-page-header")], [
    h1([attr.class(page_title)], [text(title)]),
    p([attr.class(page_lead)], [text(lead)]),
  ])
}

pub fn breadcrumb_back(href: String, label: String) -> Element(a) {
  a([attr.class(link_back), attr.href(href)], [
    span(
      [attr.class("comic-back-arrow"), attr.attribute("aria-hidden", "true")],
      [],
    ),
    span([attr.class("comic-back-label")], [text(label)]),
  ])
}

pub fn field_label(for_id: String, label_text: String) -> Element(msg) {
  label(
    [
      attr.class("mb-1.5 block text-sm font-bold uppercase tracking-wide text-gh-ink"),
      attr.attribute("for", for_id),
    ],
    [text(label_text)],
  )
}

pub fn field_hint(hint_text: String) -> Element(msg) {
  p([attr.class("mt-1.5 text-xs font-medium text-gh-muted")], [text(hint_text)])
}

pub fn list_link_card(
  href: String,
  title: String,
  subtitle: option.Option(String),
) -> Element(a) {
  a([attr.class(list_item <> " no-underline"), attr.href(href)], [
    div([], [
      span([attr.class("font-black text-gh-ink")], [text(title)]),
      case subtitle {
        option.Some(s) ->
          p([attr.class("mt-0.5 text-sm font-medium text-gh-muted")], [text(s)])
        option.None -> text("")
      },
    ]),
    span([attr.class("text-sm font-black uppercase text-gh-accent")], [text("Open →")]),
  ])
}

pub fn static_list_row(title: String, detail: String) -> Element(msg) {
  div([attr.class(list_item)], [
    div([], [
      span([attr.class("font-bold text-gh-ink")], [text(title)]),
      p([attr.class("mt-1 font-mono text-xs text-gh-muted")], [text(detail)]),
    ]),
  ])
}

pub fn form_actions(children: List(Element(msg))) -> Element(msg) {
  div([attr.class("mt-4 flex flex-wrap items-center gap-3")], children)
}

pub fn confirm_banner(
  title: String,
  message: String,
  on_confirm: msg,
  on_cancel: msg,
) -> Element(msg) {
  div(
    [
      attr.class(
        "comic-panel mb-6 border-red-700 bg-gh-danger-soft p-5",
      ),
    ],
    [
      h2([attr.class("text-lg font-black uppercase text-red-900")], [text(title)]),
      p([attr.class("mt-2 text-sm font-medium text-red-800")], [text(message)]),
      div([attr.class("mt-4 flex flex-wrap gap-3")], [
        button(
          [
            attr.class(btn_danger),
            attr.type_("button"),
            event.on_click(on_confirm),
          ],
          [text("Delete")],
        ),
        button(
          [
            attr.class(btn_secondary),
            attr.type_("button"),
            event.on_click(on_cancel),
          ],
          [text("Cancel")],
        ),
      ]),
    ],
  )
}

pub fn card_section(
  title: String,
  children: List(Element(msg)),
) -> Element(msg) {
  div([attr.class(card <> " mb-6")], [
    h2([attr.class(section_title)], [text(title)]),
    ..children
  ])
}
