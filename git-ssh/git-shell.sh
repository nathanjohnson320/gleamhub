#!/bin/sh
set -eu

if [ -f /etc/gleamhub.env ]; then
  # shellcheck disable=SC1091
  . /etc/gleamhub.env
fi

KEY_BLOB="${GLEAMHUB_KEY_BLOB:?missing GLEAMHUB_KEY_BLOB}"
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

access_body=$(mktemp)
trap 'rm -f "$access_body"' EXIT INT TERM

status=$(curl -sf -o "$access_body" -w '%{http_code}' --get \
  -H "X-Gleamhub-Internal-Token: $INTERNAL_TOKEN" \
  "$API_URL/internal/ssh/access" \
  --data-urlencode "org=$org" \
  --data-urlencode "repo=$repo" \
  --data-urlencode "k=$KEY_BLOB" \
  --data-urlencode "op=$op" || printf '%s' "000")

if [ "$status" != "200" ]; then
  echo "fatal: access denied" >&2
  exit 1
fi

USER_ID=$(sed -n 's/.*"user_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$access_body" | head -n 1)
if [ -z "$USER_ID" ]; then
  echo "fatal: access denied" >&2
  exit 1
fi

git_dir="$ROOT/$org/${repo}.git"
if [ ! -d "$git_dir" ]; then
  echo "fatal: repository not found" >&2
  exit 1
fi

export GLEAMHUB_API_URL
export GLEAMHUB_KEY_BLOB="$KEY_BLOB"
export GLEAMHUB_USER_ID="$USER_ID"
export GLEAMHUB_ORG="$org"
export GLEAMHUB_REPO="$repo"
export INTERNAL_API_TOKEN="$INTERNAL_TOKEN"

case "$op" in
  upload-pack) exec git upload-pack "$git_dir" ;;
  receive-pack) exec git receive-pack "$git_dir" ;;
  *)
    echo "fatal: unsupported git operation" >&2
    exit 1
    ;;
esac
