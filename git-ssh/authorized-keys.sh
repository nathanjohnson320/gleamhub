#!/bin/sh
set -eu

if [ -f /etc/gleamhub.env ]; then
  # shellcheck disable=SC1091
  . /etc/gleamhub.env
fi

KEY_BLOB="${1:-}"
if [ -z "$KEY_BLOB" ]; then
  exit 0
fi

API_URL="${GLEAMHUB_API_URL:-http://host.docker.internal:9999}"
INTERNAL_TOKEN="${INTERNAL_API_TOKEN:?missing INTERNAL_API_TOKEN}"

curl -sf --get "$API_URL/internal/ssh/authorized_keys" \
  -H "X-Gleamhub-Internal-Token: $INTERNAL_TOKEN" \
  --data-urlencode "k=$KEY_BLOB"
