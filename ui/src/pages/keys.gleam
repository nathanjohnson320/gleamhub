import api.{type SshKey}
import components
import config.{type Config}
import gleam/list
import gleam/option
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, form, input, p, textarea}
import lustre/event
import lustre_http

pub type Model {
  Model(keys: List(SshKey), title: String, public_key: String, error: option.Option(String))
}

pub type Msg {
  Loaded(Result(List(SshKey), lustre_http.HttpError))
  TitleChanged(String)
  KeyChanged(String)
  Add
  Added(Result(SshKey, lustre_http.HttpError))
  Delete(String)
  Deleted(Result(Nil, lustre_http.HttpError))
}

pub fn init() -> Model {
  Model(keys: [], title: "", public_key: "", error: option.None)
}

pub fn on_load(config: Config) -> Effect(Msg) {
  lustre_http.get(
    config,
    config.api_url <> "/api/ssh-keys",
    lustre_http.expect_json(api.keys_decoder(), Loaded),
  )
}

pub fn update(msg: Msg, model: Model, config: Config) -> #(Model, Effect(Msg)) {
  case msg {
    Loaded(Ok(keys)) -> #(Model(..model, keys:, error: option.None), effect.none())
    Loaded(Error(_)) -> #(
      Model(..model, error: option.Some("Failed to load keys")),
      effect.none(),
    )
    TitleChanged(t) -> #(Model(..model, title: t), effect.none())
    KeyChanged(k) -> #(Model(..model, public_key: k), effect.none())
    Add -> #(
      model,
      lustre_http.post(
        config,
        config.api_url <> "/api/ssh-keys",
        api.create_key_body(model.title, model.public_key),
        lustre_http.expect_json(api.key_decoder(), Added),
      ),
    )
    Added(Ok(key)) -> #(
      Model(..model, keys: [key, ..model.keys], title: "", public_key: ""),
      effect.none(),
    )
    Added(Error(_)) -> #(
      Model(..model, error: option.Some("Could not add key")),
      effect.none(),
    )
    Delete(id) -> #(
      model,
      lustre_http.delete(
        config,
        config.api_url <> "/api/ssh-keys/" <> id,
        lustre_http.expect_anything(Deleted),
      ),
    )
    Deleted(Ok(_)) -> #(model, on_load(config))
    Deleted(Error(_)) -> #(
      Model(..model, error: option.Some("Could not delete key")),
      effect.none(),
    )
  }
}

pub fn view(model: Model) -> Element(Msg) {
  let key_list = case model.keys {
    [] ->
      [components.empty_state("No SSH keys yet — paste your public key below.")]
    keys ->
      list.map(keys, fn(key: SshKey) {
        div([attr.class(components.list_item)], [
          div([], [
            p([attr.class("font-semibold text-gh-ink")], [text(key.title)]),
            p([attr.class("mt-1 font-mono text-xs text-gh-muted")], [
              text(key.fingerprint),
            ]),
          ]),
          button(
            [
              attr.class(components.btn_danger),
              attr.type_("button"),
              event.on_click(Delete(key.id)),
            ],
            [text("Remove")],
          ),
        ])
      })
  }

  div([attr.class(components.page)], [
    components.page_header(
      "SSH keys",
      "Account settings — add keys to authenticate git push and pull over SSH.",
    ),
    case model.error {
      option.Some(e) -> components.error_alert(e)
      option.None -> text("")
    },
    div([attr.class(components.card <> " mb-6")], key_list),
    components.card_section("Add public key", [
      form(
        [attr.class("space-y-4"), event.on_submit(fn(_) { Add })],
        [
          div([], [
            components.field_label("key-title", "Label"),
            input([
              attr.id("key-title"),
              attr.class(components.input),
              attr.value(model.title),
              attr.placeholder("MacBook Pro"),
              event.on_input(TitleChanged),
            ]),
          ]),
          div([], [
            components.field_label("key-body", "Public key"),
            textarea([
              attr.id("key-body"),
              attr.class(components.textarea),
              attr.value(model.public_key),
              attr.placeholder("ssh-ed25519 AAAA... user@host"),
              event.on_input(KeyChanged),
            ], ""),
          ]),
          components.form_actions([
            button(
              [attr.class(components.btn_primary), attr.type_("submit")],
              [text("Add key")],
            ),
          ]),
        ],
      ),
    ]),
  ])
}
