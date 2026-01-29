# syntax=docker/dockerfile:1.6
########################################
# GO BUILDER STAGE
########################################
FROM golang:1.25-alpine AS gobuilder

ARG DSTP_VERSION=0.4.23
ARG K9S_VERSION=v0.50.18
ARG TARGETARCH

RUN apk add --no-cache git ca-certificates && update-ca-certificates

ENV CGO_ENABLED=0
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    GOBIN=/out GOOS=linux GOARCH="${TARGETARCH}" \
      go install github.com/ycd/dstp/cmd/dstp@v${DSTP_VERSION} && \
    BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) && \
    GOBIN=/out GOOS=linux GOARCH="${TARGETARCH}" \
      go install -ldflags "\
        -X github.com/derailed/k9s/cmd.version=${K9S_VERSION} \
        -X github.com/derailed/k9s/cmd.commit=${K9S_VERSION} \
        -X github.com/derailed/k9s/cmd.date=${BUILD_DATE}" \
      github.com/derailed/k9s@${K9S_VERSION}

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

# Kubernetes tools
ARG KUBECTL_VERSION=v1.33.7
ARG YQ_VERSION=v4.50.1

# Install kubectl (arch-aware)
RUN case "$TARGETARCH" in \
      amd64) KUBECTL_ARCH="amd64";; \
      arm64) KUBECTL_ARCH="arm64";; \
      *) echo "Unsupported TARGETARCH=$TARGETARCH" && exit 1;; \
    esac && \
    curl -sSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl" \
      -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

# Install yq (arch-aware)
RUN case "$TARGETARCH" in \
      amd64) YQ_ARCH="amd64";; \
      arm64) YQ_ARCH="arm64";; \
      *) echo "Unsupported TARGETARCH=$TARGETARCH" && exit 1;; \
    esac && \
    curl -sSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${YQ_ARCH}" \
      -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq

# Create non-root user
RUN addgroup -S devuser && adduser -S devuser -G devuser

# Allow devuser to use sudo without password
RUN echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser && \
  chmod 0440 /etc/sudoers.d/devuser

USER devuser
WORKDIR /home/devuser
ENV LANG=C.UTF-8

ENTRYPOINT ["bash"]
