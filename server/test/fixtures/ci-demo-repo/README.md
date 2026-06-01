# CI demo repository fixture

This directory holds an example hosted-repo Dagger module used in documentation and manual testing.

Gleamhub discovers modules at:

1. `.dagger/dagger.json`
2. `ci/dagger.json`
3. `dagger/dagger.json`

## Local test (requires Dagger CLI)

From the repository root after copying this fixture into a git repo:

```bash
dagger call -m ./ci ci --source=.
```

## What gleamhub runs

When an open merge request's source branch is pushed, gleamhub enqueues a pipeline run and the CI worker executes:

```bash
dagger call -m <worktree>/<module_path> ci --source=<worktree>
```

See [docs/ci-platform.md](../../../docs/ci-platform.md) for the full platform contract.
