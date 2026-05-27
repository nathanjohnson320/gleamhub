#!/bin/sh
set -eu

KEY_BLOB="${1:-}"
if [ -z "$KEY_BLOB" ]; then
  exit 0
fi

API_URL="${GLEAMHUB_API_URL:-http://server:9999}"

curl -sf --get "$API_URL/internal/ssh/authorized_keys" \
  --data-urlencode "k=$KEY_BLOB"
