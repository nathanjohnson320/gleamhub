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

curl -sf --get "$API_URL/internal/ssh/authorized_keys" \
  --data-urlencode "k=$KEY_BLOB"
