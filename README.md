# alpiNETools

![GitHub Release](https://img.shields.io/github/v/release/fragolinux/alpiNETools?display_name=tag)
![GitHub Release Date](https://img.shields.io/github/release-date/fragolinux/alpiNETools)
![Release Build](https://img.shields.io/github/actions/workflow/status/fragolinux/alpiNETools/ci.yaml?label=release%20build)
![License](https://img.shields.io/github/license/fragolinux/alpiNETools?branch=main)
![Docker Pulls](https://img.shields.io/docker/pulls/fragolinux/alpinetools)
![Docker Image Size](https://img.shields.io/docker/image-size/fragolinux/alpinetools/latest)
![Platform](https://img.shields.io/badge/platform-amd64%20%7C%20arm64-blue)
![Base](https://img.shields.io/badge/base-Alpine%203.23.3-0D597F?logo=alpinelinux)
![Kubernetes](https://img.shields.io/badge/kubernetes-toolbox-326CE5?logo=kubernetes)
![Security Alerts](https://img.shields.io/github/dependabot/alerts/fragolinux/alpiNETools)
![Security Enforced](https://img.shields.io/github/actions/workflow/status/fragolinux/alpiNETools/ci.yaml?label=security%20enforced)

Minimal Alpine-based toolbox for networking analysis and Kubernetes debugging.
Multi-arch, lightweight, and designed for on-demand troubleshooting.

---

## Pull & Run

### Supported architectures

- linux/amd64
- linux/arm64

### GitHub Container Registry (GHCR)

Pull the image:

```bash
docker pull ghcr.io/fragolinux/alpinetools:latest
```

Run an interactive shell:

```bash
docker run --rm -it ghcr.io/fragolinux/alpinetools:latest
```

---

### Docker Hub

Pull the image:

```bash
docker pull fragolinux/alpinetools:latest
```

Run an interactive shell:

```bash
docker run --rm -it fragolinux/alpinetools:latest
```

---

### Using local kubeconfig (optional)

To use kubectl and k9s against your local Kubernetes cluster,
mount your kubeconfig inside the container (read-only):

```bash
docker run --rm -it \
  -v ~/.kube:/home/devuser/.kube:ro \
  ghcr.io/fragolinux/alpinetools:latest
```

---

## Included tools

### Kubernetes tools
- kubectl v1.33.7
- k9s v0.50.18
- yq v4.50.1

### Networking & diagnostics
- iperf3
- tcpdump
- traceroute
- ping
- dig / nslookup
- netcat / socat

### Additional tools
- hurl: CLI for HTTP requests and API testing — https://github.com/Orange-OpenSource/hurl
- httpie: Human-friendly HTTP client — https://github.com/httpie/cli
- trurl: URL parsing and manipulation tool — https://github.com/curl/trurl
- dstp: File transfer over stdin/stdout (useful with SSH) — https://github.com/ycd/dstp

---
