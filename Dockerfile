# Dockerfile

FROM alpine:3.23.3 AS builder

RUN apk add --no-cache curl ca-certificates tar gzip

ARG KUBECTL_VERSION=v1.33.7
ARG K9S_VERSION=v0.50.18
ARG YQ_VERSION=v4.50.1

RUN curl -sSL https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    -o /tmp/kubectl && chmod +x /tmp/kubectl

RUN curl -sSL https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz \
    | tar -xz -C /tmp k9s && chmod +x /tmp/k9s

RUN curl -sSL https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 \
    -o /tmp/yq && chmod +x /tmp/yq

FROM alpine:3.23.3

LABEL org.opencontainers.image.title=alpiNETools
LABEL org.opencontainers.image.description="Alpine-based networking & Kubernetes toolbox"
LABEL org.opencontainers.image.source=https://github.com/fragolinux/alpiNETools
LABEL org.opencontainers.image.licenses=MIT
LABEL io.kubernetes.kubectl.version=1.33.7
LABEL io.kubernetes.k9s.version=0.50.18
LABEL io.kubernetes.yq.version=4.50.1

RUN apk add --no-cache \
  bash \
  iperf3 \
  tcpdump \
  bind-tools \
  net-tools \
  iputils \
  traceroute \
  socat \
  netcat-openbsd \
  jq

COPY --from=builder /tmp/kubectl /usr/local/bin/kubectl
COPY --from=builder /tmp/k9s /usr/local/bin/k9s
COPY --from=builder /tmp/yq /usr/local/bin/yq

RUN addgroup -S devuser && adduser -S devuser -G devuser && \
    mkdir /home/devuser && chown -R devuser:devuser /home/devuser

USER devuser
WORKDIR /home/devuser
ENV LANG=C.UTF-8

ENTRYPOINT ["bash"]
