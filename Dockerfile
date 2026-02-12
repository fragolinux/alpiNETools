# syntax=docker/dockerfile:1.6
ARG GO_BUILDER_IMAGE=dhi.io/golang:1-alpine3.23-dev@sha256:b2b4bb49fde981b8077960336cb0e9e8a174ecdaa2f2562a9603911bdfbf38ee
ARG FINAL_BASE_IMAGE=dhi.io/alpine-base:3.23-alpine3.23-dev@sha256:06cc40ca62d2bdc8d4b3b46ad626498d79e005e751d423e4a0d49a3c029743b4
ARG GO_VERSION=1.25.7

########################################
# GO BUILDER STAGE (Cato CA for local builds)
########################################
FROM ${GO_BUILDER_IMAGE} AS gobuilder

ARG GO_VERSION
ARG DSTP_VERSION=0.4.23
ARG DSTP_XNET_VERSION=v0.38.0
ARG K9S_VERSION=v0.50.18
ARG KUBECTL_SRC_VERSION=v1.33.7
ARG YQ_VERSION=v4.50.1
ARG TARGETARCH

RUN apk upgrade --no-cache && \
    apk add --no-cache git ca-certificates curl tar && \
    update-ca-certificates

# Force a patched Go toolchain so Trivy doesn't flag Go stdlib CVEs in built binaries.
ENV PATH="/usr/local/go/bin:${PATH}"
RUN arch="${TARGETARCH:-amd64}" && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${arch}.tar.gz" -o /tmp/go.tgz && \
    rm -rf /usr/local/go && \
    tar -C /usr/local -xzf /tmp/go.tgz && \
    rm -f /tmp/go.tgz && \
    go version

ENV CGO_ENABLED=0
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    git -c advice.detachedHead=false clone --depth 1 --branch v${DSTP_VERSION} https://github.com/ycd/dstp.git /src/dstp && \
    cd /src/dstp && \
    go mod edit -require=golang.org/x/net@${DSTP_XNET_VERSION} && \
    go mod tidy && \
    GOBIN=/out GOOS=linux GOARCH="${TARGETARCH}" \
      go install -ldflags "-s -w" ./cmd/dstp && \
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
    KUBE_GIT_MAJOR="$(echo "${KUBECTL_SRC_VERSION#v}" | cut -d. -f1)" && \
    KUBE_GIT_MINOR="$(echo "${KUBECTL_SRC_VERSION#v}" | cut -d. -f2)" && \
    KUBE_GIT_COMMIT="$(git rev-parse --verify HEAD)" && \
    KUBE_BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" && \
    KUBE_LDFLAGS="-s -w \
      -X k8s.io/component-base/version.gitMajor=${KUBE_GIT_MAJOR} \
      -X k8s.io/component-base/version.gitMinor=${KUBE_GIT_MINOR} \
      -X k8s.io/component-base/version.gitVersion=${KUBECTL_SRC_VERSION} \
      -X k8s.io/component-base/version.gitCommit=${KUBE_GIT_COMMIT} \
      -X k8s.io/component-base/version.gitTreeState=clean \
      -X k8s.io/component-base/version.buildDate=${KUBE_BUILD_DATE}" && \
    GOBIN=/out GOOS=linux GOARCH="${TARGETARCH}" \
      go build -trimpath -ldflags "${KUBE_LDFLAGS}" -o /out/kubectl ./cmd/kubectl && \
    cd / && \
    GOBIN=/out GOOS=linux GOARCH="${TARGETARCH}" \
      go install -ldflags "-s -w" github.com/mikefarah/yq/v4@${YQ_VERSION}

########################################
# FINAL IMAGE
########################################
FROM ${FINAL_BASE_IMAGE}

ARG TARGETARCH

RUN apk upgrade --no-cache && \
    apk add --no-cache --upgrade \
    expat \
    libcrypto3 \
    libssl3 \
    && apk add --no-cache \
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
    bash-completion

# If you ever need sudo inside the container, re-add:
#   apk add --no-cache sudo

RUN apk add --no-cache \
    --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing/ \
    hurl

COPY --from=gobuilder /out/dstp /usr/local/bin/dstp
COPY --from=gobuilder /out/k9s /usr/local/bin/k9s
COPY --from=gobuilder /out/kubectl /usr/local/bin/kubectl
COPY --from=gobuilder /out/yq /usr/local/bin/yq

# Create non-root user
RUN addgroup -S devuser && adduser -S devuser -G devuser
#
# If sudo is re-enabled, allow devuser to use sudo without password:
# RUN echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser && \
#   chmod 0440 /etc/sudoers.d/devuser
#
# Enable bash completion for devuser
RUN printf '%s\n' \
  '[ -f /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion' \
  > /home/devuser/.bashrc && \
  chown devuser:devuser /home/devuser/.bashrc

USER devuser
WORKDIR /home/devuser
ENV LANG=C.UTF-8

ENTRYPOINT ["bash"]
