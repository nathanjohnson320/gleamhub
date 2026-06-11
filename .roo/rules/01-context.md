# Gleamhub — agent context

Gleam-native Git hosting: Clerk auth, orgs/repos, SSH git, merge requests, optional Dagger CI.

**Origins:** Forked from [gleam_wisp_lustre_template](https://github.com/nathanjohnson320/gleam_wisp_lustre_template) (Wisp + Lustre + Clerk). Auth and UI shell predate the first Postgres migration; git-ssh was built with org/repo creation, before merge requests. See `.roo/plan.md` for actual vs migration build order.

Zoo loads rules from `.roo/rules*/`. This file loads in every mode.

## Monorepo layout

| Path | Stack | Role |
|------|-------|------|
| `server/` | Wisp + Mist + pog + Squirrel | HTTP API, Postgres, git browse/MR/issue APIs, internal SSH/CI routes |
| `ui/` | Lustre + Modem + Vite (JS target) | SPA; proxies `/api` to server in dev |
| `ci-worker/` | gleam_otp actor | Long-poll CI jobs, run Dagger, upload logs |
| `common/` | Gleam library | Shared types (minimal; path dep) |
| `git-ssh/` | OpenSSH + shell hooks | Git over SSH; calls internal API |
| `docs/` | Markdown | Operator and feature docs |

## Runtime topology

```
Browser (Lustre UI) ──JWT──► Wisp API (host, :9999)
git CLI ──SSH──► git-ssh ──internal HTTP──► Wisp API
ci-worker ──long-poll──► Wisp API ──► Dagger engine
Wisp API ──► Postgres + bare git repos on disk
```

## Key dependencies

**Server:** `wisp`, `mist`, `pog`, `squirrel` (dev, codegen), `gleam_otp`, `ywt`/`ywt_erlang` (Clerk JWT), `envie`, `cors_builder`, `simplifile`

**UI:** `lustre`, `modem` (routing), `gleam_fetch`, `gleam_javascript`, `nibble` (vendored parser)

**CI worker:** `gleam_otp` actor + supervised static supervisor

## Conventions (all crates)

- Gleam only — functional, immutable, explicit types
- `Result` for errors at boundaries; no exceptions in app logic (Wisp `rescue_crashes` is middleware only)
- IO at edges: handlers/routes, `database.gleam`, `git/exec.gleam`, Lustre `Effect`s
- Small modules; match existing naming and import style
- Do not edit generated `server/src/sql.gleam` — edit `server/src/sql/*.sql` and regenerate

## Agent workflow

**Start here:** [`.roo/workflow.md`](../workflow.md) — step-by-step Planner → Builder → Reviewer loop.

| File | Purpose |
|------|---------|
| `.roo/plan.md` | Milestones and high-level plan (Planner writes) |
| `.roo/state.md` | Current mode, task, status (all modes update) |
| `.roo/tasks/backlog.md` | Queued task descriptions |
| `.roo/tasks/current_task.md` | Active task (Builder reads) |
| `.roo/tasks/done.md` | Index of approved tasks (one line each) |
| `.roo/tasks/completed/` | Full audit log per task (`T{n}.{m}.md`) |
| `.roo/scripts/next_task.sh` | Pop next task from backlog → current |
| `.roo/scripts/complete_task.sh` | Index approved task in done.md (Reviewer) |
| `.roo/models.md` | LLM profile → mode mapping (Zoo Providers) |
| `.roo/mcp.json` | Semble MCP server config (project-level) |

### Code search (Semble MCP)

Planner, Builder, and Reviewer modes include the `mcp` group. Use Semble `search` / `find_related` with `repo` set to the workspace root before exploring or reviewing code. Prefer Semble over broad grep.

### Zoo modes (configured in `.roomodes`)

| Role | Zoo mode | Slug | Rules directory |
|------|----------|------|-----------------|
| Planner | `/architect` | `architect` | `.roo/rules-architect/` |
| Builder | `/code` | `code` | `.roo/rules-code/` |
| Reviewer | `/debug` | `debug` | `.roo/rules-debug/` |
| Orchestrator | `/orchestrator` | `orchestrator` | delegates to modes above |

### Task loop

```bash
# Planner: write tasks to .roo/tasks/backlog.md, update .roo/plan.md and .roo/state.md

# Builder:
.roo/scripts/next_task.sh    # loads .roo/tasks/current_task.md
# implement → test → write .roo/tasks/completed/T{n}.{m}.md → state REVIEW

# Reviewer: read .roo/tasks/current_task.md + diff, approve/reject
# APPROVE → finalize completed/T{n}.{m}.md → .roo/scripts/complete_task.sh → state DONE
```

## Common commands

```bash
# Server
cd server && npm install && npm run db:up && gleam run
cd server && gleam test
cd server && npm run db:gen:sql          # after editing src/sql/*.sql

# UI
cd ui && npm install && npm run dev      # :5173, proxies /api → :9999
cd ui && npm run build                   # → server/priv/static
cd ui && gleam test

# CI (optional)
docker compose --profile ci up --build -d
```

## Auth model

- **Public API:** Clerk JWT in `Authorization: Bearer …`; verified via JWKS loaded at boot (`CLERK_JWKS_URL`)
- **Internal API:** `X-Gleamhub-Internal-Token` header (git-ssh hooks, ci-worker)
- **Org access:** membership + role (`owner` / `member`); write actions need write or owner

## What this project is NOT

- Not Phoenix/Elixir — no contexts, controllers, Ecto, or Oban
- Not a generic Gleam tutorial — follow patterns in this repo
- UI is not server-rendered — Lustre SPA with JSON API
