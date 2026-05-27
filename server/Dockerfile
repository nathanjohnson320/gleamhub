FROM ghcr.io/gleam-lang/gleam:v1.14.0-erlang-alpine AS build

RUN apk add --no-cache build-base nodejs npm

WORKDIR /build
COPY common common
COPY server server
COPY ui ui

WORKDIR /build/ui
RUN npm install && npm run build

WORKDIR /build/server
RUN gleam export erlang-shipment

FROM ghcr.io/gleam-lang/gleam:v1.14.0-erlang-alpine

RUN apk add --no-cache \
    git \
    curl \
    ca-certificates \
    nodejs \
    npm \
    postgresql-client \
  && npm install -g dbmate@2.15.0

WORKDIR /app

COPY --from=build /build/server/build/erlang-shipment /app
COPY server/db /app/db
COPY docker/server-entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /docker-entrypoint.sh /app/entrypoint.sh

ENV PORT=9999
ENV GIT_REPOS_ROOT=/data/repos

EXPOSE 9999

ENTRYPOINT ["/docker-entrypoint.sh"]
