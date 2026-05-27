import gleam/option
import lustre/attribute as attr
import lustre/element.{type Element, text}
import lustre/element/html.{a, button, div, h1, h2, label, p, span}
import lustre/event

pub const page =
  "mx-auto w-full max-w-3xl px-4 py-8 sm:px-6 lg:px-8"

pub const page_title =
  "mb-2 bg-gradient-to-r from-gh-accent to-gh-ink bg-clip-text text-3xl font-bold tracking-tight text-transparent sm:text-4xl"

pub const page_lead = "mb-8 text-base text-gh-muted"

pub const card =
  "rounded-xl border border-slate-200/80 bg-white p-6 shadow-sm ring-1 ring-slate-900/5"

pub const section_title =
  "mb-4 text-sm font-semibold uppercase tracking-wide text-gh-muted"

pub const input =
  "w-full rounded-lg border border-slate-200 bg-white px-4 py-2.5 text-sm text-gh-ink shadow-sm outline-none transition placeholder:text-slate-400 focus:border-gh-accent focus:ring-2 focus:ring-gh-accent/20"

pub const textarea =
  "w-full min-h-[120px] rounded-lg border border-slate-200 bg-white px-4 py-2.5 font-mono text-sm text-gh-ink shadow-sm outline-none transition placeholder:text-slate-400 focus:border-gh-accent focus:ring-2 focus:ring-gh-accent/20"

pub const btn_primary =
  "inline-flex items-center justify-center rounded-lg bg-gh-accent px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-violet-700 focus:outline-none focus:ring-2 focus:ring-gh-accent/40 disabled:cursor-not-allowed disabled:opacity-50"

pub const btn_secondary =
  "inline-flex items-center justify-center rounded-lg border border-slate-200 bg-white px-4 py-2.5 text-sm font-medium text-gh-ink shadow-sm transition hover:border-slate-300 hover:bg-slate-50"

pub const btn_danger =
  "inline-flex items-center justify-center rounded-lg border border-red-200 bg-gh-danger-soft px-3 py-1.5 text-sm font-medium text-gh-danger transition hover:bg-red-100"

pub const link_back =
  "mb-6 inline-flex items-center gap-1 text-sm font-medium text-gh-accent hover:underline"

pub const list_item =
  "flex flex-col gap-1 rounded-lg border border-slate-100 bg-slate-50/50 px-4 py-3 transition hover:border-gh-accent/30 hover:bg-gh-accent-soft/40 sm:flex-row sm:items-center sm:justify-between"

pub const code_block =
  "break-all rounded-md bg-slate-900 px-3 py-2 font-mono text-xs text-slate-100"

pub fn error_alert(message: String) -> Element(msg) {
  div(
    [
      attr.class(
        "mb-6 rounded-lg border border-red-200 bg-gh-danger-soft px-4 py-3 text-sm text-red-800",
      ),
    ],
    [text(message)],
  )
}

pub fn empty_state(message: String) -> Element(msg) {
  p(
    [attr.class("rounded-lg border border-dashed border-slate-200 px-4 py-8 text-center text-sm text-gh-muted")],
    [text(message)],
  )
}

pub fn page_header(title: String, lead: String) -> Element(msg) {
  div([], [h1([attr.class(page_title)], [text(title)]), p([attr.class(page_lead)], [text(lead)])])
}

pub fn breadcrumb_back(href: String, label: String) -> Element(a) {
  a([attr.class(link_back), attr.href(href)], [text("← " <> label)])
}

pub fn field_label(for_id: String, label_text: String) -> Element(msg) {
  label(
    [
      attr.class("mb-1.5 block text-sm font-medium text-gh-ink"),
      attr.attribute("for", for_id),
    ],
    [text(label_text)],
  )
}

pub fn list_link_card(
  href: String,
  title: String,
  subtitle: option.Option(String),
) -> Element(a) {
  a(
    [attr.class(list_item <> " no-underline"), attr.href(href)],
    [
      div([], [
        span([attr.class("font-semibold text-gh-ink")], [text(title)]),
        case subtitle {
          option.Some(s) ->
            p([attr.class("mt-0.5 text-sm text-gh-muted")], [text(s)])
          option.None -> text("")
        }
      ]),
      span([attr.class("text-sm text-gh-accent")], [text("Open →")]),
    ],
  )
}

pub fn static_list_row(title: String, detail: String) -> Element(msg) {
  div([attr.class(list_item)], [
    div([], [
      span([attr.class("font-medium text-gh-ink")], [text(title)]),
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
        "mb-6 rounded-xl border border-red-200 bg-gh-danger-soft p-5 shadow-sm",
      ),
    ],
    [
      h2([attr.class("text-lg font-semibold text-red-900")], [text(title)]),
      p([attr.class("mt-2 text-sm text-red-800")], [text(message)]),
      div([attr.class("mt-4 flex flex-wrap gap-3")], [
        button(
          [attr.class(btn_danger), attr.type_("button"), event.on_click(on_confirm)],
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

pub fn card_section(title: String, children: List(Element(msg))) -> Element(msg) {
  div(
    [attr.class(card <> " mb-6")],
    [h2([attr.class(section_title)], [text(title)]), ..children],
  )
}
