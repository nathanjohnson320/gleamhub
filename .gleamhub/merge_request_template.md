## Summary

<!-- What changed and why? One or two sentences. -->

## Changes

<!-- Check areas touched; delete lines that don't apply. -->

- [ ] Server (`server/`)
- [ ] UI (`ui/`)
- [ ] CI / Dagger (`ci/`, `ci-worker/`)
- [ ] Database schema / migrations (`server/db/`)
- [ ] Docs only

## Test plan

- [ ] `cd server && gleam test` (requires Postgres on port 5433)
- [ ] `cd ui && gleam check`
- [ ] Manual: exercised the change in the local UI (`npm run dev`)
- [ ] N/A - docs / config only
