# ui

Gleamhub web app: [Lustre](https://github.com/lustre-labs/lustre) SPA + Vite + Clerk sign-in.

## Development

From the repo root, start the API first (see [README.md](../README.md)), then:

```bash
cd ui
npm install
npm run dev
```

Open **http://localhost:5173**. Vite proxies `/api` to the Gleam server on port 9999.

Environment: copy `ui/.env.example` to `ui/.env` and set `VITE_CLERK_PUBLISHABLE_KEY` (must match the Clerk app used by the server’s `CLERK_JWKS_URL`).

## Production build

```bash
npm run build
```

Output goes to `../server/priv/static` for the Wisp server to serve.

## Tests

```bash
gleam test
```

Route helpers and decoders are covered in `test/`.

## Features (UI routes)

| Area | Path pattern |
|------|----------------|
| Orgs / repos | `/orgs/:org`, `/orgs/:org/repos/:repo` |
| File browse / blob | `/orgs/.../tree/...`, `/orgs/.../blob/...` |
| Commits | `/orgs/.../commits`, `/orgs/.../commit/:sha` |
| Issues | `/orgs/.../issues`, `/orgs/.../issues/:num` |
| Merge requests | `/orgs/.../merge-requests`, `/orgs/.../merge-requests/:num` |
| SSH keys | `/keys` |

Merge request tabs use path segments: `/merge-requests/:num`, `/checks`, `/commits`, `/changes`, and `/changes/:file?line=N` for diff line links. Blob line permalinks use `?line=` (and `&end=` for ranges) on the blob URL.

## Layout

| Path | Role |
|------|------|
| `src/ui.gleam` | App shell, page dispatch |
| `src/routes.gleam` | Path ↔ route type + URL helpers |
| `src/config.gleam` | Runtime config |
| `src/components.gleam` | Shared UI components |
| `src/http/` | API client (`api.gleam`) and authenticated fetch (`lustre_http.gleam`) |
| `src/auth/` | JWT / Clerk auth helpers |
| `src/pages/` | Page modules; colocated helpers (`org_slug`, `repo_nav`, `blob_line_scroll`) |
| `src/ci/` | CI log rendering, status badges, pipeline SSE |
| `src/diff/` | MR diff parsing and line anchors |
| `src/content/` | Markdown + syntax highlight (FFI to `main.js`) |
| `src/util/` | Small shared helpers (`time_format`, `clipboard`) |
| `main.js` | Vite entry, Clerk bootstrap |

Markdown rendering still uses `marked` + `highlight.js` in `main.js` (a pure-Gleam `mork` swap remains possible later).

See [README.md](../README.md) for end-user workflows.
