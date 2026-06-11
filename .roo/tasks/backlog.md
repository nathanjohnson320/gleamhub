
## Milestone M9 — Backlog / parity features

T9.1 Add branch management UI (list, delete, protect from branches page) — files: `server/src/git/browse_routes.gleam`, `ui/src/pages/`
T9.7 Add visibility levels and per-repo permissions — files: `server/db/migrations/`, `server/src/access.gleam`, `ui/src/pages/`
T9.6 Add HTTPS Git remote + personal access tokens — files: `server/db/migrations/`, `server/src/http/`, `git-ssh/`
T9.5 Add outbound webhooks for push, MR, and issue events — files: `server/db/migrations/`, `server/src/webhooks/`
T9.4 Extend protected branches (tag protection, push rules) — files: `server/db/migrations/`, `server/src/http/`, `git-ssh/hooks/`
T9.3 Add blame view on blob pages — files: `server/src/git/`, `ui/src/pages/repo_view.gleam`
T9.2 Add compare branches view (ahead/behind, diff summary) — files: `server/src/git/`, `ui/src/pages/`
