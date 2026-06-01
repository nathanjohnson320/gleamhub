#!/bin/sh
set -eu

API_URL="${GLEAMHUB_API_URL:-http://host.docker.internal:9999}"
INTERNAL_TOKEN="${INTERNAL_API_TOKEN:?missing INTERNAL_API_TOKEN}"
REPOS_ROOT="${GIT_REPOS_ROOT:-/data/repos}"
LONG_POLL_TIMEOUT="${CI_LONG_POLL_TIMEOUT:-55}"
POLL_SECONDS="${CI_POLL_SECONDS:-5}"
LOG_PATCH_SECONDS="${CI_LOG_PATCH_SECONDS:-3}"
DAGGER_ENGINE_HOST="${_EXPERIMENTAL_DAGGER_RUNNER_HOST:-container://gleamhub-dagger-engine}"
JOB_TIMEOUT_SECONDS="${CI_JOB_TIMEOUT_SECONDS:-1800}"

export _EXPERIMENTAL_DAGGER_RUNNER_HOST="$DAGGER_ENGINE_HOST"

log() {
  printf '[ci-worker] %s\n' "$1"
}

append_log() {
  log_file="$1"
  message="$2"
  printf '%s\n' "$message" >>"$log_file"
}

patch_job() {
  job_id="$1"
  state="$2"
  log_path="$3"
  body_file=$(mktemp /tmp/gleamhub-patch-body-XXXXXX)

  if ! python3 -c '
import json
import sys

log_path, body_path, state = sys.argv[1], sys.argv[2], sys.argv[3]
with open(log_path, "rb") as f:
    data = f.read()
max_bytes = 262144
if len(data) > max_bytes:
    data = data[-max_bytes:]
    text = data.decode("utf-8", errors="replace")
    text = "[log truncated to last 256KB]\n" + text
else:
    text = data.decode("utf-8", errors="replace")
with open(body_path, "w", encoding="utf-8") as out:
    json.dump({"state": state, "log": text}, out)
' "$log_path" "$body_file" "$state"
  then
    log "failed to build patch body for job $job_id"
    rm -f "$body_file"
    return
  fi

  if ! curl -s -f -X PATCH \
    -H "X-Gleamhub-Internal-Token: $INTERNAL_TOKEN" \
    -H "Content-Type: application/json" \
    -d @"$body_file" \
    "$API_URL/internal/ci/jobs/$job_id" >/dev/null
  then
    log "failed to update job $job_id (state=$state)"
  fi
  rm -f "$body_file"
}

patch_running_log() {
  patch_job "$1" running "$2"
}

run_job() {
  job_done=0
  dagger_pid=""

  finish_job() {
    state="$1"
    job_done=1
    patch_job "$job_id" "$state" "$log_file"
  }

  fail_job() {
    if [ "$job_done" = 0 ]; then
      append_log "$log_file" "CI worker exited unexpectedly"
      finish_job failure
    fi
  }

  cleanup() {
    if [ -n "$dagger_pid" ] && kill -0 "$dagger_pid" 2>/dev/null; then
      kill "$dagger_pid" 2>/dev/null || true
      wait "$dagger_pid" 2>/dev/null || true
    fi
    fail_job
    rm -rf "$checkout" "$log_file"
  }
  trap cleanup EXIT INT TERM

  job_json="$1"
  job_id=$(printf '%s' "$job_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
  org=$(printf '%s' "$job_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["org_slug"])')
  repo=$(printf '%s' "$job_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["repo_name"])')
  disk_path=$(printf '%s' "$job_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["disk_path"])')
  commit_sha=$(printf '%s' "$job_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["commit_sha"])')
  module_path=$(printf '%s' "$job_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["module_path"])')
  entry_fn=$(printf '%s' "$job_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["entry_function"])')

  bare_repo="$REPOS_ROOT/$disk_path"
  checkout=$(mktemp -d /tmp/gleamhub-ci-XXXXXX)
  log_file=$(mktemp /tmp/gleamhub-ci-log-XXXXXX)

  append_log "$log_file" "=== Gleamhub CI ==="
  append_log "$log_file" "Repository: $org/$repo @ ${commit_sha%???????}"
  patch_running_log "$job_id" "$log_file"

  append_log "$log_file" "Cloning bare repository..."
  patch_running_log "$job_id" "$log_file"
  if ! git clone --quiet "$bare_repo" "$checkout" >>"$log_file" 2>&1; then
    finish_job failure
    return
  fi

  append_log "$log_file" "Checking out $commit_sha..."
  patch_running_log "$job_id" "$log_file"
  if ! git -C "$checkout" checkout --quiet "$commit_sha" >>"$log_file" 2>&1; then
    finish_job failure
    return
  fi

  if [ -z "$module_path" ]; then
    append_log "$log_file" "No Dagger module at commit"
    finish_job skipped
    return
  fi

  module_dir="$checkout/$module_path"
  if [ ! -f "$module_dir/dagger.json" ]; then
    append_log "$log_file" "Module path $module_path missing dagger.json"
    finish_job failure
    return
  fi

  append_log "$log_file" ""
  append_log "$log_file" "Running: dagger call -m $module_dir $entry_fn --source=$checkout"
  patch_running_log "$job_id" "$log_file"

  set +e
  timeout "$JOB_TIMEOUT_SECONDS" dagger call --progress=plain -m "$module_dir" "$entry_fn" --source="$checkout" >>"$log_file" 2>&1 &
  dagger_pid=$!
  set -e

  while kill -0 "$dagger_pid" 2>/dev/null; do
    patch_running_log "$job_id" "$log_file"
    sleep "$LOG_PATCH_SECONDS"
  done

  set +e
  wait "$dagger_pid"
  exit_code=$?
  set -e
  dagger_pid=""

  case "$exit_code" in
    0) finish_job success ;;
    124)
      append_log "$log_file" ""
      append_log "$log_file" "[job timed out after ${JOB_TIMEOUT_SECONDS}s]"
      finish_job failure
      ;;
    *) finish_job failure ;;
  esac

  log "finished job $job_id for $org/$repo@$commit_sha ($exit_code)"
}

log "long-polling $API_URL/internal/ci/jobs/next (timeout ${LONG_POLL_TIMEOUT}s, log patch every ${LOG_PATCH_SECONDS}s)"

while true; do
  status=$(curl -s -o /tmp/gleamhub-ci-job.json -w '%{http_code}' \
    --max-time "$((LONG_POLL_TIMEOUT + 10))" \
    -H "X-Gleamhub-Internal-Token: $INTERNAL_TOKEN" \
    "$API_URL/internal/ci/jobs/next?timeout=$LONG_POLL_TIMEOUT")

  if [ "$status" = "200" ]; then
    run_job "$(cat /tmp/gleamhub-ci-job.json)"
  elif [ "$status" = "204" ]; then
    :
  else
    log "jobs/next returned HTTP $status"
    sleep "$POLL_SECONDS"
  fi
done
