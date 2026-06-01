# Gleamhub CI platform

Gleamhub runs **hosted-repo CI** on your infrastructure using [Dagger](https://dagger.io/). Each repository opt-in by committing a Dagger module; gleamhub executes it on merge-request events and reports status on the MR page.

## Repo author contract

### Module location (first match wins)

1. `.dagger/dagger.json`
2. `ci/dagger.json`
3. `dagger/dagger.json`

### Entry function

Gleamhub invokes the function named **`ci`**.

### Local development

From your repository root:

```bash
dagger call -m ./ci ci --source=.
```

Use the same command gleamhub's worker runs in CI. Pin the Gleam container image in your module to the version in the repo’s `.tool-versions` or `gleam.toml` — using a newer compiler than the project expects produces version-constraint errors during `gleam deps download` / `gleam test`.

### Example fixture

See [server/test/fixtures/ci-demo-repo](../server/test/fixtures/ci-demo-repo/) for a minimal module.

## When CI runs (v1)

MR pipelines only:

- Opening a merge request enqueues a run for the source branch HEAD
- Pushing to an open MR's source branch enqueues a run for the new commit
- Writers can **Re-run checks** from the MR page

Pushes to branches that are not the source branch of an open MR do not enqueue runs.

## Merge gating

| Git state | Pipeline | Merge allowed |
|-----------|----------|---------------|
| Conflicts | any | No |
| Clean | No module (`skipped`) | Yes |
| Clean | `queued` / `running` | No |
| Clean | `failure` | No |
| Clean | `success` at current HEAD | Yes |

## Operator setup

### 1. Run gleamhub API + repos

Follow the main [README](../README.md). Repos live under `server/data/repos` by default (`GIT_REPOS_ROOT`).

### 2. Start the CI stack

```bash
docker compose -f docker-compose.ci.yml up --build -d
```

Services:

- **`dagger-engine`** — persistent Dagger engine (`container_name: gleamhub-dagger-engine`; the worker uses `container://gleamhub-dagger-engine`, not the compose service name)
- **`ci-worker`** — polls gleamhub, clones the bare repo into `/tmp`, runs `dagger call`, and PATCHes `log` every few seconds while the job runs (shown on the MR **Checks** tab)

**Dagger version:** CLI and engine are pinned together (currently **v0.21.3**) in `ci-worker/Dockerfile` (`DAGGER_VERSION`), `docker-compose.ci.yml` (`registry.dagger.io/engine:…`), and the demo fixture’s `ci/dagger.json` (`engineVersion`). After bumping, rebuild both services: `docker compose -f docker-compose.ci.yml up --build -d`. Each hosted repo should set `engineVersion` in its `dagger.json` to the same tag.

Environment (via `.env` or shell):

| Variable | Purpose |
|----------|---------|
| `GLEAMHUB_API_URL` | gleamhub API base URL (default `http://host.docker.internal:9999`) |
| `INTERNAL_API_TOKEN` | Must match gleamhub server token |
| `GIT_REPOS_ROOT` | Mounted read-only into worker (default `./server/data/repos`) |
| `CI_POLL_SECONDS` | Worker poll interval (default `5`) |
| `CI_LOG_PATCH_SECONDS` | How often the worker uploads partial logs while a job runs (default `3`) |
| `CI_JOB_TIMEOUT_SECONDS` | Max job duration (default `1800`) |

### 3. Git hooks

New repos receive **`post-receive`** hooks automatically (alongside `pre-receive`). Existing repos get hooks reinstalled when protected branches are updated. Hooks call `POST /internal/ci/enqueue` after successful pushes.

## Internal API

| Endpoint | Method | Role |
|----------|--------|------|
| `/internal/ci/enqueue` | POST | Enqueue runs for open MRs matching branch + commit |
| `/internal/ci/jobs/next` | GET | Worker claims next queued job (204 if empty) |
| `/internal/ci/jobs/:id` | PATCH | Worker updates state + log (`{"state":"success","log":"..."}`) |

Authenticated with header `X-Gleamhub-Internal-Token`.

## Public API

MR detail includes:

```json
{
  "merge_request": { ... },
  "merge_check": { "mergeable": true, "message": "" },
  "pipeline": {
    "state": "success",
    "commit_sha": "...",
    "module_path": "ci",
    "log": "..."
  }
}
```

`pipeline` is `null` when no run exists yet.

## Security note

Hosted-repo pipelines execute arbitrary code in containers (same trust model as shared CI runners). Run workers on isolated infrastructure and keep Docker socket access limited to the CI stack.
