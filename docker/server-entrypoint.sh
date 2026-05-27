#!/bin/sh
set -eu

export DBMATE_MIGRATIONS_DIR="${DBMATE_MIGRATIONS_DIR:-/app/db/migrations}"

if [ -n "${DATABASE_URL:-}" ]; then
  host=$(printf '%s' "$DATABASE_URL" | sed -n 's#.*@\([^:/]*\).*#\1#p')
  if [ -n "$host" ]; then
    until pg_isready -h "$host" -U postgres >/dev/null 2>&1; do
      echo "waiting for postgres at $host..."
      sleep 1
    done
  fi
  echo "running migrations..."
  dbmate up
fi

exec /app/entrypoint.sh run
