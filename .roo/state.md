# PROJECT STATE

Current Mode: —
Current Milestone: M9 — Backlog / parity features
Current Task: (none — baseline complete)

Status: IDLE

## Baseline

M0–M8 shipped. **71 tasks** indexed in `.roo/tasks/done.md`; full audit logs in `.roo/tasks/completed/`.

### How it was built (actual order)

1. Fork [gleam_wisp_lustre_template](https://github.com/nathanjohnson320/gleam_wisp_lustre_template) — Wisp + Lustre + Clerk (M0, M1)
2. Orgs, repos, git-ssh clone/push, code browse (M2, M3, T4.1–T4.2)
3. `20260527120000` — users, orgs, repos, ssh_keys schema
4. `20260528120000` — merge requests (after git-ssh)
5. `20260529120000` / `20260529130000` — protected branches, issues
6. `20260601120000`+ — CI, invitations, labels, reviews, notifications, releases, milestones

### Migration timeline (schema only)

1. `20260527120000` — users, orgs, repos, ssh_keys
2. `20260528120000` — merge_requests + comments
3. `20260529120000` — protected_branches
4. `20260529130000` — issues + comments
5. `20260601120000` — pipeline_runs (CI)
6. `20260603120000` — organization_invitations
7. `20260604120000` — labels + assignees
8. `20260604130000` — draft MRs
9. `20260605120000` — MR assignees
10. `20260605130000` — default-branch CI
11. `20260606120000` — MR reviews + required_approvals
12. `20260607120000` — comment @mentions
13. `20260608120000` — notifications
14. `20260608130000` — releases
15. `20260608140000` — MR reviewers
16. `20260610120000` — issue–MR links
17. `20260610140000` — milestones

## M9 next up

**T9.1** branch management UI is first in `.roo/tasks/backlog.md`. No web editor planned.

Stack reminders (Gleamhub — not Phoenix):
- Server: Wisp + Mist + pog + Squirrel → database.gleam
- UI: Lustre + Modem SPA
- Async CI: ci-worker OTP actor + internal API (not Oban)

Constraints:
- No business logic in route handlers beyond HTTP parsing
- No SQL outside src/sql/*.sql (Squirrel) and database.gleam wrappers
- No hidden side effects in Lustre view functions
- Implement only the current task scope

Next Action:
Run `.roo/scripts/next_task.sh` then `/code` to start T9.1, or `/architect` to refine the M9 queue.

Config: `.roomodes` · Rules: `.roo/rules*/` · Models: `.roo/models.md` · Tasks: `.roo/tasks/`
