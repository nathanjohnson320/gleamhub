# Gleamhub — Lustre UI patterns

You are implementing frontend code in the Gleamhub `ui/` crate (Gleam **JavaScript** target).

## Stack

- **Lustre** — Elm-style `Model`, `Msg`, `update`, `view`, `Effect`
- **Modem** — client-side routing (`modem.init`, `OnRouteChange`)
- **lustre_http** — project wrapper around fetch → `Effect` (see `ui/src/http/lustre_http.gleam`)
- **Clerk** — auth via `main.js` FFI; JWT passed as Bearer token to API
- **Vite** — dev server :5173, proxies `/api` → server :9999

## Architecture

This is **not** a nested Lustre app per page. One app in `ui/src/ui.gleam`:

```
ui.gleam (shell)
  ├── routes.gleam     — Route ADT + URL parsing
  ├── config.gleam     — api_url + optional JWT token
  ├── pages/*.gleam    — feature Model/Msg/update/view
  └── components.gleam — shared UI
```

### Page module contract

Each page exports:

| Export | Purpose |
|--------|---------|
| `Model` | Page state |
| `Msg` | Page messages |
| `init()` | `#(Model, Effect(Msg))` — often empty effect |
| `on_load(config)` | Fetch data when route becomes active |
| `update(msg, model, config)` | `#(Model, Effect(Msg))` |
| `view(model, config)` | `Element(Msg)` |

Shell wraps page messages: `OrgsMsg(orgs.Msg)`, `MrDetailMsg(merge_request_detail.Msg)`, etc.

### Routing

- `routes.Route` — exhaustive ADT for all pages
- `from_uri(Uri) -> Route` — parse path + query + fragment
- Path helpers: `org_repos_path`, `mr_detail_path`, etc.
- **Always** add new screens to: `Route`, `from_uri`, `ui.gleam` Model/Msg/update/view dispatch

MR tabs use path segments: `/merge-requests/:num/checks`, `/commits`, `/changes`, `/changes/:file?line=N`.

## HTTP / API client

**Never** call `fetch` directly from pages — use `lustre_http`:

```gleam
lustre_http.get(
  config,
  config.api_url <> "/api/orgs",
  lustre_http.expect_json(api.orgs_decoder(), OrgsLoaded),
)
```

- `config.token` — Clerk JWT; `lustre_http` adds `Authorization: Bearer`
- Result messages wrap `Result(T, lustre_http.HttpError)`
- Handle `Unauthorized`, `BadUrl`, `NetworkError` explicitly (see `pages/orgs.gleam`)

**Types and decoders** live in `http/api.gleam`:
- Mirror server `json/api.gleam` response shapes
- Use `gleam/dynamic/decode` — not manual parsing

**URL builders** — add functions alongside decoders in `api.gleam`.

## Effects and side effects

- All async IO returns `Effect(Msg)` from `update` or `on_load`
- Batch with `effect.batch([...])`
- No side effects in `view` — pure function of model
- Clipboard, markdown render, Clerk session — existing FFI patterns in `auth/`, `content/`, `util/`

## App shell responsibilities (`ui.gleam`)

- Holds `option.Option(page.Model)` for each area — `None` when route inactive
- `route_effect` — calls page `on_load` when navigating
- `mr_detail_for_route`, `repo_view_for_route` — sync sub-state on navigation
- Global nav, user menu, sign out

When adding a page, follow how `releases` or `milestones` are wired (Model slot + Msg variant + route_effect branch).

## Styling

- Inline Lustre attributes — no CSS-in-Gleam framework
- Reuse `components.gleam` for layout, buttons, errors, loading states
- Match existing class names and structure

## Markdown and syntax highlighting

Rendered via FFI to `main.js` (`marked` + `highlight.js`). Use `content/markdown.gleam` — do not add new JS libraries without reason.

## Diff / CI UI

- MR diffs: `diff/view.gleam`, `diff/mr_line.gleam`
- CI logs: `ci/log.gleam`, `ci/log_ansi.gleam`, `ci/status.gleam`
- Pipeline SSE client patterns in `merge_request_detail.gleam` Checks tab

## Build and config

- `ui/.env` — `VITE_CLERK_PUBLISHABLE_KEY`
- `npm run build` → `../server/priv/static` for production bundle
- `config.api_url` — empty string in dev (same-origin via Vite proxy); set for prod

## Testing

- `gleam test` in `ui/` — no Docker required
- Test route parsing (`routes_test.gleam`), decoders, pure helpers
- Do not integration-test HTTP from UI tests — server has integration tests

## Checklist for new UI feature

- [ ] API types + decoders in `http/api.gleam`
- [ ] `Route` variant + `from_uri` + path helper in `routes.gleam`
- [ ] Page module with init/on_load/update/view
- [ ] Wire into `ui.gleam` (Model, Msg, update, view, route_effect)
- [ ] Tests for non-trivial parsing/decoding
- [ ] Run `cd ui && gleam test`

## Anti-patterns

- Do not create a second Lustre application root
- Do not store JWT in page models — use `config.token`
- Do not duplicate server business rules in UI (validation yes; authorization no)
- Do not use Erlang-target packages in `ui/gleam.toml`
