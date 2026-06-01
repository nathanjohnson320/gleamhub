FROM alpine:3.21

RUN apk add --no-cache \
    bash \
    curl \
    git \
    python3 \
    docker-cli \
    coreutils

ARG DAGGER_VERSION=0.20.8
RUN curl -fsSL "https://dl.dagger.io/dagger/install.sh" | BIN_DIR=/usr/local/bin sh \
  && dagger version

WORKDIR /worker
COPY run.sh /worker/run.sh
RUN chmod +x /worker/run.sh

ENV CI_POLL_SECONDS=5
ENV CI_JOB_TIMEOUT_SECONDS=1800

ENTRYPOINT ["/worker/run.sh"]
