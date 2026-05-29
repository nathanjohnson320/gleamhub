#!/bin/sh
set -eu

# sshd does not pass container ENV to AuthorizedKeysCommand; persist for shell scripts.
cat >/etc/gleamhub.env <<EOF
GLEAMHUB_API_URL=${GLEAMHUB_API_URL:-http://host.docker.internal:9999}
GIT_REPOS_ROOT=${GIT_REPOS_ROOT:-/data/repos}
INTERNAL_API_TOKEN=${INTERNAL_API_TOKEN:?missing INTERNAL_API_TOKEN}
EOF

exec /usr/sbin/sshd -D -e
