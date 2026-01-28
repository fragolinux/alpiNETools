# README.md

# alpiNETools

![GitHub Release](https://img.shields.io/github/v/release/fragolinux/alpiNETools?sort=semver)
![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/fragolinux/alpiNETools/ci.yaml?label=release%20build)
![License](https://img.shields.io/github/license/fragolinux/alpiNETools)
![Docker Pulls](https://img.shields.io/docker/pulls/fragolinux/alpinetools)
![Docker Image Size](https://img.shields.io/docker/image-size/fragolinux/alpinetools/latest)
![Docker Platforms](https://img.shields.io/badge/platform-amd64%20%7C%20arm64-blue)
![Alpine](https://img.shields.io/badge/base-Alpine%203.23.3-0D597F?logo=alpinelinux)
![Kubernetes](https://img.shields.io/badge/kubernetes-toolbox-326CE5?logo=kubernetes)

Minimal Alpine-based toolbox for networking analysis and Kubernetes debugging.

---

## Included tools

- kubectl v1.33.7
- k9s v0.50.18
- yq v4.50.1

Networking & diagnostics:
- iperf3
- tcpdump
- traceroute
- ping
- dig / nslookup
- netcat / socat

---

## Container images

GitHub Container Registry:
ghcr.io/fragolinux/alpinetoools:<version>

Docker Hub:
docker.io/fragolinux/alpinetoools:<version>

---

## Supported architectures

- linux/amd64
- linux/arm64
