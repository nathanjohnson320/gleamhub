# Gleamhub — Master Plan

**Baseline status:** M0–M8 **shipped** (2026-05-27 → 2026-06-10). See `.roo/tasks/done.md` and `.roo/tasks/completed/`.

**Next phase:** M9 — backlog features (`.roo/tasks/backlog.md`).

---

## Project origins

Gleamhub started as a fork of [gleam_wisp_lustre_template](https://github.com/nathanjohnson320/gleam_wisp_lustre_template) (Wisp API + Lustre/Vite UI + Clerk). That template provided **M0 shell** and **M1 auth** before any Gleamhub Postgres migrations.

**Actual build order** (how it was developed):

1. Clone/fork template → Clerk auth + Wisp/Lustre boot (M0, M1)
2. Organizations, repos, **git-ssh** clone/push, code browse (M2, M3, T4.1–T4.2)
3. First migration `20260527120000` — formalize users/orgs/repos/ssh_keys schema
4. Merge requests (M5) — `20260528120000`
5. Protected branches + issues (M4 hooks/schema, M6) — `20260529120000` / `20260529130000`
6. CI, invitations, labels, reviews, notifications, releases, milestones (M7–M8)

Migration timestamps do not always match milestone IDs — e.g. MR migration predates protected-branches migration, but **git-ssh predates MRs**.

---

## Milestones

| # | Milestone | Status | Notes |
|---|-----------|--------|-------|
| M0 | Monorepo scaffolding | ✅ Shipped | Forked from gleam_wisp_lustre_template |
| M1 | Authentication (Clerk) | ✅ Shipped | From template; predates `20260527120000` |
| M2 | Organizations & membership | ✅ Shipped | `20260527120000` → `20260603120000` |
| M3 | Repositories & code browse | ✅ Shipped | Built with git-ssh (T4.1–T4.2) |
| M4 | Git over SSH & protected branches | ✅ Shipped | T4.1–T4.2 early; T4.3–T4.6 `20260529120000`+ |
| M5 | Merge requests | ✅ Shipped | After git-ssh; `20260528120000` → `20260608140000` |
| M6 | Issues & collaboration | ✅ Shipped | `20260529130000` → `20260610140000` |
| M7 | Optional Dagger CI | ✅ Shipped | `20260601120000` → `20260605130000` |
| M8 | Releases & notifications | ✅ Shipped | `20260608120000` → `20260608130000` |
| M9 | Backlog / parity features | 🔲 Queued | See `.roo/tasks/backlog.md` |

---

## M0 — Monorepo scaffolding ✅

Forked from [gleam_wisp_lustre_template](https://github.com/nathanjohnson320/gleam_wisp_lustre_template); extended with `git-ssh/`, `ci-worker/`, `common/`, docker-compose.

| Task | Description |
|------|-------------|
| T0.1 | Scaffold monorepo layout — fork template → `server/`, `ui/`, then `git-ssh/`, `ci-worker/`, `common/` |
| T0.2 | docker-compose Postgres + git-ssh — `docker-compose.yml` |
| T0.3 | Env example files — `.env.example`, `server/.env.example`, `ui/.env.example` |
| T0.4 | Tool version pins — `.tool-versions` |
| T0.5 | Test Postgres compose — `docker-compose.test.yml` |

## M1 — Authentication (Clerk) ✅

Shipped with the template fork **before** the first Gleamhub migration. Later wired to `users` in `20260527120000`.

| Task | Description |
|------|-------------|
| T1.1 | Configure Clerk env vars |
| T1.2 | JWKS fetch + key cache at boot |
| T1.3 | Upsert user from JWT |
| T1.4 | Attach `user_id` to Wisp Context |
| T1.5 | `GET /api/me` |
| T1.6 | Guard all routes (401) |
| T1.7 | Clerk SDK in UI |
| T1.8 | Account page |
| T1.9 | Server auth integration tests |
| T1.10 | UI auth tests |

## M2 — Organizations & membership ✅

| Task | Description |
|------|-------------|
| T2.1 | Core schema (users, orgs, members, repos, ssh_keys) — `20260527120000` |
| T2.2 | Org CRUD API |
| T2.3 | Org access middleware (owner/member) |
| T2.4 | Orgs UI page |
| T2.5 | Org repo list + search |
| T2.6 | Organization invitations — `20260603120000` |
| T2.7 | Member invite/promote/demote UI |
| T2.8 | Accept/decline invitations |

## M3 — Repositories & code browse ✅

Built in the same phase as orgs. **T4.1–T4.2** (git-ssh service + internal SSH API) shipped here — see M4 for protected-branch hooks added later.

| Task | Description |
|------|-------------|
| T3.1 | Repo CRUD + bare git init |
| T3.2 | SSH key CRUD API |
| T3.3 | SSH keys UI |
| T3.4 | Browse API (tree, blob, raw, archive) |
| T3.5 | Commits list + detail |
| T3.6 | README preview |
| T3.7 | Blob permalinks + syntax highlighting |
| T3.8 | Repo settings (rename, delete, description) |

## M4 — Git over SSH & protected branches ✅

T4.1–T4.2 were built with org/repo (M2/M3). T4.3–T4.6 (protected branches, hooks) came after git-ssh was working and around/after MRs.

| Task | Description |
|------|-------------|
| T4.1 | git-ssh + authorized_keys API — *built with M2/M3* |
| T4.2 | Internal SSH access check — *built with M2/M3* |
| T4.3 | Protected branches schema + API — `20260529120000` |
| T4.4 | pre-receive hook |
| T4.5 | post-receive CI enqueue |
| T4.6 | Protected branches settings UI |

## M5 — Merge requests ✅

| Task | Description |
|------|-------------|
| T5.1 | MR schema + CRUD API — `20260528120000` |
| T5.2 | MR commits + diff API |
| T5.3 | MR + inline comments |
| T5.4 | Merge (merge/squash/rebase), close, update branch |
| T5.5 | MR UI (conversation, checks, commits, changes) |
| T5.6 | MR templates from git |
| T5.7 | Draft MRs — `20260604130000` |
| T5.8 | MR assignees — `20260605120000` |
| T5.9 | MR reviews + required approvals — `20260606120000` |
| T5.10 | MR requested reviewers — `20260608140000` |
| T5.11 | Duplicate MR prevention + conflict display |

## M6 — Issues & collaboration ✅

| Task | Description |
|------|-------------|
| T6.1 | Issues schema + CRUD — `20260529130000` |
| T6.2 | Issue comments |
| T6.3 | Issue templates from git |
| T6.4 | Issue list + detail UI |
| T6.5 | Labels + assignees — `20260604120000` |
| T6.6 | Issue–MR linking — `20260610120000` |
| T6.7 | Milestones — `20260610140000` |
| T6.8 | @mentions — `20260607120000` |
| T6.9 | Issue/MR list filtering UI |
| T6.10 | Comment edit & delete |
| T6.11 | Label edit & delete |

## M7 — Optional Dagger CI ✅

| Task | Description |
|------|-------------|
| T7.1 | pipeline_runs + enqueue — `20260601120000` |
| T7.2 | ci-worker long-poll actor |
| T7.3 | Dagger discovery + log upload |
| T7.4 | SSE pipeline stream + Checks tab |
| T7.5 | Merge gating on CI state |
| T7.6 | Default-branch CI — `20260605130000` |
| T7.7 | Manual re-run checks |

## M8 — Releases & notifications ✅

| Task | Description |
|------|-------------|
| T8.1 | Releases schema + API — `20260608130000` |
| T8.2 | Tags browse + release UI |
| T8.3 | Notifications + event creation — `20260608120000` |
| T8.4 | Notifications API + bell UI |
| T8.5 | Default branch setting in repo settings |

## M9 — Backlog (not started)

Queued in `.roo/tasks/backlog.md`. **Priority confirmed:** branch management UI first.

| Priority | Task | Feature |
|----------|------|---------|
| 1 | T9.1 | Branch management UI |
| 2 | T9.2 | Compare branches |
| 3 | T9.3 | Blame view |
| 4 | T9.4 | Richer protected branches (tag protection) |
| 5 | T9.5 | Webhooks |
| 6 | T9.6 | HTTPS Git + PATs |
| 7 | T9.7 | Visibility & per-repo permissions |

**Out of scope:** web editor, in-browser file editing, Gleamhub CLI.

See `README.md` for shipped baseline vs gaps.
