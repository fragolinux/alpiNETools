# syntax=docker/dockerfile:1.6
########################################
# GO BUILDER STAGE
########################################
FROM golang:1.25.6-alpine AS gobuilder

ARG DSTP_VERSION=0.4.23
ARG DSTP_XNET_VERSION=v0.38.0
ARG K9S_VERSION=v0.50.18
ARG KUBECTL_SRC_VERSION=v1.33.7
ARG YQ_VERSION=v4.50.1
ARG TARGETARCH

RUN apk add --no-cache git ca-certificates && update-ca-certificates

ENV CGO_ENABLED=0
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    git -c advice.detachedHead=false clone --depth 1 --branch v${DSTP_VERSION} https://github.com/ycd/dstp.git /src/dstp && \
    cd /src/dstp && \
    go mod edit -require=golang.org/x/net@${DSTP_XNET_VERSION} && \
    go mod tidy && \
    GOBIN=/out GOOS=linux GOARCH="${TARGETARCH}" \
      go install ./cmd/dstp && \
    BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) && \
    GOBIN=/out GOOS=linux GOARCH="${TARGETARCH}" \
      go install -ldflags "\
        -X github.com/derailed/k9s/cmd.version=${K9S_VERSION} \
        -X github.com/derailed/k9s/cmd.commit=${K9S_VERSION} \
        -X github.com/derailed/k9s/cmd.date=${BUILD_DATE}" \
      github.com/derailed/k9s@${K9S_VERSION} && \
    git -c advice.detachedHead=false clone --depth 1 --branch ${KUBECTL_SRC_VERSION} \
      https://github.com/kubernetes/kubernetes.git /src/kubernetes && \
    cd /src/kubernetes && \
    GOBIN=/out GOOS=linux GOARCH="${TARGETARCH}" \
      go build -o /out/kubectl ./cmd/kubectl && \
    cd / && \
    GOBIN=/out GOOS=linux GOARCH="${TARGETARCH}" \
      go install github.com/mikefarah/yq/v4@${YQ_VERSION}

########################################
# FINAL IMAGE
########################################
FROM alpine:3.23.3

# BuildKit provides TARGETARCH for multi-arch builds (amd64/arm64)
ARG TARGETARCH

# Core utilities + tools (including archive tools and editors)
RUN apk add --no-cache \
    bash \
    curl \
    ca-certificates \
    iperf3 \
    tcpdump \
    bind-tools \
    net-tools \
    iproute2 \
    iputils \
    traceroute \
    mtr \
    socat \
    netcat-openbsd \
    busybox-extras \
    jq \
    trurl \
    httpie \
    tar \
    gzip \
    bzip2 \
    openssl \
    file \
    nmap \
    nano \
    vim \
    bash-completion \
    sudo

 # Install hurl from Alpine edge (musl-compatible)
RUN apk add --no-cache \
    --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing/ \
    hurl

# Copy dstp and k9s built from source
COPY --from=gobuilder /out/dstp /usr/local/bin/dstp
COPY --from=gobuilder /out/k9s /usr/local/bin/k9s
COPY --from=gobuilder /out/kubectl /usr/local/bin/kubectl
COPY --from=gobuilder /out/yq /usr/local/bin/yq

# Create non-root user
RUN addgroup -S devuser && adduser -S devuser -G devuser

# Allow devuser to use sudo without password
RUN echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser && \
  chmod 0440 /etc/sudoers.d/devuser

RUN printf '%s\n' \
  '[ -f /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion' \
  > /home/devuser/.bashrc && \
  chown devuser:devuser /home/devuser/.bashrc

USER devuser
WORKDIR /home/devuser
ENV LANG=C.UTF-8

ENTRYPOINT ["bash"]
