########################################
# BUILDER STAGE
########################################
FROM alpine:3.23.3 AS builder

# Install prerequisites for downloading binaries
RUN apk add --no-cache curl ca-certificates tar gzip

# Versions for external tools
ARG DSTP_VERSION=0.4.23
ARG HURL_VERSION=7.1.0

# BuildKit provides TARGETARCH for multi-arch builds (amd64/arm64)
ARG TARGETARCH

# Download hurl binaries
RUN case "$TARGETARCH" in \
      amd64) HURL_ARCH="x86_64";; \
      arm64) HURL_ARCH="aarch64";; \
      *) echo "Unsupported TARGETARCH=$TARGETARCH" && exit 1;; \
    esac && \
    HURL_DIR="hurl-${HURL_VERSION}-${HURL_ARCH}-unknown-linux-gnu" && \
    curl -sSL \
      "https://github.com/Orange-OpenSource/hurl/releases/download/${HURL_VERSION}/${HURL_DIR}.tar.gz" \
      | tar -xz -C /tmp --strip-components=2 "${HURL_DIR}/bin/hurl" && \
    chmod +x /tmp/hurl

########################################
# GO BUILDER STAGE
########################################
FROM golang:1.25-alpine AS gobuilder

ARG DSTP_VERSION=0.4.23
ARG K9S_VERSION=v0.50.18
ARG TARGETARCH

RUN apk add --no-cache git ca-certificates && update-ca-certificates

ENV CGO_ENABLED=0
RUN GOBIN=/out GOOS=linux GOARCH="${TARGETARCH}" \
      go install github.com/ycd/dstp/cmd/dstp@v${DSTP_VERSION} && \
    GOBIN=/out GOOS=linux GOARCH="${TARGETARCH}" \
      go install github.com/derailed/k9s@${K9S_VERSION}

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
    iputils \
    traceroute \
    socat \
    netcat-openbsd \
    jq \
    trurl \
    httpie \
    tar \
    gzip \
    bzip2 \
    nano \
    vim

# Copy dstp and k9s built from source, plus hurl from builder
COPY --from=gobuilder /out/dstp /usr/local/bin/dstp
COPY --from=gobuilder /out/k9s /usr/local/bin/k9s
COPY --from=builder /tmp/hurl /usr/local/bin/hurl

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

USER devuser
WORKDIR /home/devuser
ENV LANG=C.UTF-8

ENTRYPOINT ["bash"]
