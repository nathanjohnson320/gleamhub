FROM ghcr.io/gleam-lang/gleam:v1.17.0-erlang-alpine AS build

RUN apk add --no-cache build-base

WORKDIR /build
COPY . .
RUN gleam deps download && gleam export erlang-shipment

FROM ghcr.io/gleam-lang/gleam:v1.17.0-erlang-alpine

RUN apk add --no-cache \
    git \
    curl \
    ca-certificates \
    docker-cli \
    coreutils

ARG DAGGER_VERSION=0.21.4
RUN curl -fsSL "https://dl.dagger.io/dagger/install.sh" \
  | DAGGER_VERSION="${DAGGER_VERSION}" BIN_DIR=/usr/local/bin sh \
  && dagger version

WORKDIR /app

COPY --from=build /build/build/erlang-shipment /app

ENV CI_POLL_SECONDS=5
ENV CI_JOB_TIMEOUT_SECONDS=1800

ENTRYPOINT ["/app/entrypoint.sh", "run"]
