#!/bin/sh
set -eu

if [ -f /etc/gleamhub.env ]; then
  # shellcheck disable=SC1091
  . /etc/gleamhub.env
fi

USER_ID="${GLEAMHUB_USER_ID:?missing GLEAMHUB_USER_ID}"
API_URL="${GLEAMHUB_API_URL:-http://host.docker.internal:9999}"
INTERNAL_TOKEN="${INTERNAL_API_TOKEN:?missing INTERNAL_API_TOKEN}"
ROOT="${GIT_REPOS_ROOT:-/data/repos}"

cmd="${SSH_ORIGINAL_COMMAND:-}"
case "$cmd" in
  git-upload-pack\ \'*|git-receive-pack\ \'*) ;;
  *)
    echo "fatal: unauthorized command" >&2
    exit 1
    ;;
esac

path=$(printf '%s' "$cmd" | sed -n "s/^git-[a-z-]* '\/\{0,1\}\([^']*\)'$/\1/p")
if [ -z "$path" ]; then
  echo "fatal: could not parse repository path" >&2
  exit 1
fi

org=$(printf '%s' "$path" | cut -d/ -f1)
repo_file=$(printf '%s' "$path" | cut -d/ -f2-)
repo=${repo_file%.git}

if [ -z "$org" ] || [ -z "$repo" ]; then
  echo "fatal: invalid repository path" >&2
  exit 1
fi

op=$(printf '%s' "$cmd" | sed 's/ .*//')
op=${op#git-}

status=$(curl -sf -o /dev/null -w '%{http_code}' --get \
  -H "X-Gleamhub-Internal-Token: $INTERNAL_TOKEN" \
  "$API_URL/internal/ssh/access" \
  --data-urlencode "org=$org" \
  --data-urlencode "repo=$repo" \
  --data-urlencode "user_id=$USER_ID" \
  --data-urlencode "op=$op" || printf '%s' "000")

if [ "$status" != "200" ]; then
  echo "fatal: access denied" >&2
  exit 1
fi

git_dir="$ROOT/$org/${repo}.git"
if [ ! -d "$git_dir" ]; then
  echo "fatal: repository not found" >&2
  exit 1
fi

export GLEAMHUB_API_URL
export GLEAMHUB_USER_ID
export GLEAMHUB_ORG="$org"
export GLEAMHUB_REPO="$repo"

case "$op" in
  upload-pack) exec git upload-pack "$git_dir" ;;
  receive-pack) exec git receive-pack "$git_dir" ;;
  *)
    echo "fatal: unsupported git operation" >&2
    exit 1
    ;;
esac
