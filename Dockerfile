########################################
# BUILDER STAGE
########################################
FROM alpine:3.23.3 AS builder

# Install prerequisites for downloading binaries
RUN apk add --no-cache curl ca-certificates tar gzip

# Versions for external tools
ARG DSTP_VERSION=0.4.23
ARG HURL_VERSION=7.2.1

# Download dstp binaries
RUN curl -sSL \
    https://github.com/ycd/dstp/releases/download/v${DSTP_VERSION}/dstp_${DSTP_VERSION}_linux_x86_64.tar.gz \
    | tar -xz -C /tmp dstp && \
    chmod +x /tmp/dstp

# Download hurl binaries
RUN curl -sSL \
    https://github.com/Orange-OpenSource/hurl/releases/download/v${HURL_VERSION}/hurl_${HURL_VERSION}_linux_x86_64.tar.gz \
    | tar -xz -C /tmp hurl && \
    chmod +x /tmp/hurl

########################################
# FINAL IMAGE
########################################
FROM alpine:3.23.3

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
    httpie \
    tar \
    gzip \
    bzip2 \
    nano \
    vim

# Copy dstp and hurl from builder
COPY --from=builder /tmp/dstp /usr/local/bin/dstp
COPY --from=builder /tmp/hurl /usr/local/bin/hurl

# Kubernetes tools
ARG KUBECTL_VERSION=v1.33.7
ARG K9S_VERSION=v0.50.18
ARG YQ_VERSION=v4.50.1

# Install kubectl
RUN curl -sSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl

# Install k9s
RUN curl -sSL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" \
    | tar -xz -C /usr/local/bin k9s && chmod +x /usr/local/bin/k9s

# Install yq
RUN curl -sSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
    -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq

# Create non-root user
RUN addgroup -S devuser && adduser -S devuser -G devuser

USER devuser
WORKDIR /home/devuser
ENV LANG=C.UTF-8

ENTRYPOINT ["bash"]