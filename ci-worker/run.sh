#!/bin/sh
set -eu

API_URL="${GLEAMHUB_API_URL:-http://host.docker.internal:9999}"
INTERNAL_TOKEN="${INTERNAL_API_TOKEN:?missing INTERNAL_API_TOKEN}"
REPOS_ROOT="${GIT_REPOS_ROOT:-/data/repos}"
POLL_SECONDS="${CI_POLL_SECONDS:-5}"
DAGGER_ENGINE_HOST="${_EXPERIMENTAL_DAGGER_RUNNER_HOST:-container://dagger-engine}"
JOB_TIMEOUT_SECONDS="${CI_JOB_TIMEOUT_SECONDS:-1800}"

export _EXPERIMENTAL_DAGGER_RUNNER_HOST="$DAGGER_ENGINE_HOST"

log() {
  printf '[ci-worker] %s\n' "$1"
}

patch_job() {
  job_id="$1"
  state="$2"
  log_text="$3"
  curl -sf -X PATCH \
    -H "X-Gleamhub-Internal-Token: $INTERNAL_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"state\":\"$state\",\"log\":$(printf '%s' "$log_text" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}" \
    "$API_URL/internal/ci/jobs/$job_id" >/dev/null
}

run_job() {
  job_json="$1"
  job_id=$(printf '%s' "$job_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
  org=$(printf '%s' "$job_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["org_slug"])')
  repo=$(printf '%s' "$job_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["repo_name"])')
  disk_path=$(printf '%s' "$job_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["disk_path"])')
  commit_sha=$(printf '%s' "$job_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["commit_sha"])')
  module_path=$(printf '%s' "$job_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["module_path"])')
  entry_fn=$(printf '%s' "$job_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["entry_function"])')

  bare_repo="$REPOS_ROOT/$disk_path"
  worktree=$(mktemp -d /tmp/gleamhub-ci-XXXXXX)
  log_file=$(mktemp /tmp/gleamhub-ci-log-XXXXXX)

  cleanup() {
    git -C "$bare_repo" worktree remove --force "$worktree" >/dev/null 2>&1 || true
    rm -rf "$worktree" "$log_file"
  }
  trap cleanup EXIT INT TERM

  if ! git -C "$bare_repo" worktree add --detach "$worktree" "$commit_sha" >>"$log_file" 2>&1; then
    patch_job "$job_id" failure "$(cat "$log_file")"
    return
  fi

  if [ -z "$module_path" ]; then
    patch_job "$job_id" skipped "No Dagger module at commit"
    return
  fi

  module_dir="$worktree/$module_path"
  if [ ! -f "$module_dir/dagger.json" ]; then
    patch_job "$job_id" failure "Module path $module_path missing dagger.json"
    return
  fi

  set +e
  timeout "$JOB_TIMEOUT_SECONDS" dagger call -m "$module_dir" "$entry_fn" --source="$worktree" >>"$log_file" 2>&1
  exit_code=$?
  set -e

  log_text=$(cat "$log_file")
  case "$exit_code" in
    0) patch_job "$job_id" success "$log_text" ;;
    124) patch_job "$job_id" failure "${log_text}\n[job timed out after ${JOB_TIMEOUT_SECONDS}s]" ;;
    *) patch_job "$job_id" failure "$log_text" ;;
  esac

  log "finished job $job_id for $org/$repo@$commit_sha ($exit_code)"
}

log "polling $API_URL every ${POLL_SECONDS}s"

while true; do
  status=$(curl -sf -o /tmp/gleamhub-ci-job.json -w '%{http_code}' \
    -H "X-Gleamhub-Internal-Token: $INTERNAL_TOKEN" \
    "$API_URL/internal/ci/jobs/next" || printf '%s' "000")

  if [ "$status" = "200" ]; then
    run_job "$(cat /tmp/gleamhub-ci-job.json)"
  elif [ "$status" = "204" ]; then
    :
  else
    log "jobs/next returned HTTP $status"
  fi

  sleep "$POLL_SECONDS"
done
