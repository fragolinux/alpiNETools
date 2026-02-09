.PHONY: help test build sec run-local run-gh run-dh clean prerelease release x86 arm

IMAGE ?= alpinetools:local
DOCKERFILE ?= Dockerfile.cato
CATO_BUNDLE ?= $(HOME)/.cato/ca-bundle.crt
GO_BUILDER_IMAGE ?= dhi.io/golang:1-alpine3.23-dev@sha256:b2b4bb49fde981b8077960336cb0e9e8a174ecdaa2f2562a9603911bdfbf38ee
FINAL_BASE_IMAGE ?= dhi.io/alpine-base:3.23-alpine3.23-dev@sha256:06cc40ca62d2bdc8d4b3b46ad626498d79e005e751d423e4a0d49a3c029743b4
GO_VERSION ?= 1.25.7
DSTP_VERSION ?= 0.4.23
K9S_VERSION ?= v0.50.18
KUBECTL_SRC_VERSION ?= v1.33.7
YQ_VERSION ?= v4.50.1
ARCH ?= $(shell uname -m)
PLATFORM ?= $(if $(filter arm64 aarch64,$(ARCH)),linux/arm64,linux/amd64)

help:
	@echo "Available targets:"
	@echo "  make test  - verify Cato certs and (re)build bundle"
	@echo "  make build - local Docker build using Cato bundle"
	@echo "  make sec   - run Trivy on the locally built image"
	@echo "  make run-local - start an interactive shell in the local image"
	@echo "  make run-gh - start an interactive shell in latest GHCR image"
	@echo "  make run-dh - start an interactive shell in latest Docker Hub image"
	@echo "  make clean - prune buildx cache (local)"
	@echo "  make prerelease - capture versions to ../VERSIONS.txt"
	@echo "  make x86   - build for linux/amd64"
	@echo "  make arm   - build for linux/arm64"
	@echo "  make release - bump patch tag and push branch + tag"
	@echo ""
	@echo "Variables:"
	@echo "  IMAGE=$(IMAGE)"
	@echo "  DOCKERFILE=$(DOCKERFILE)"
	@echo "  CATO_BUNDLE=$(CATO_BUNDLE)"
	@echo "  PLATFORM=$(PLATFORM)"
	@echo "  GO_BUILDER_IMAGE=$(GO_BUILDER_IMAGE)"
	@echo "  FINAL_BASE_IMAGE=$(FINAL_BASE_IMAGE)"
	@echo "  GO_VERSION=$(GO_VERSION)"
	@echo "  DSTP_VERSION=$(DSTP_VERSION)"
	@echo "  K9S_VERSION=$(K9S_VERSION)"
	@echo "  KUBECTL_SRC_VERSION=$(KUBECTL_SRC_VERSION)"
	@echo "  YQ_VERSION=$(YQ_VERSION)"

default: help

test:
	./cato-bundle.sh

build:
	@set -e; \
	secret_args=""; \
	need_cato=0; \
	if command -v curl >/dev/null 2>&1; then \
		if curl -fsS --max-time 5 https://proxy.golang.org/ >/dev/null 2>&1; then \
			need_cato=0; \
		else \
			need_cato=1; \
		fi; \
	else \
		need_cato=1; \
	fi; \
	if [ "$$need_cato" -eq 1 ]; then \
		if [ ! -f "$(CATO_BUNDLE)" ]; then \
			echo "proxy.golang.org not reachable, attempting Cato bundle generation..."; \
			./cato-bundle.sh; \
		fi; \
		if [ -f "$(CATO_BUNDLE)" ]; then \
			secret_args="--secret id=cato_ca,src=$(CATO_BUNDLE)"; \
		else \
			echo "WARNING: Cato bundle not available; building without it."; \
		fi; \
	fi; \
	docker buildx build --load -t $(IMAGE) \
		-f $(DOCKERFILE) \
		--platform $(PLATFORM) \
		--build-arg GO_BUILDER_IMAGE=$(GO_BUILDER_IMAGE) \
		--build-arg FINAL_BASE_IMAGE=$(FINAL_BASE_IMAGE) \
		--build-arg GO_VERSION=$(GO_VERSION) \
		$$secret_args \
		.

sec:
	@missing=0; \
	for cmd in docker trivy grype; do \
		if ! command -v $$cmd >/dev/null 2>&1; then \
			echo "ERROR: $$cmd not found."; \
			missing=1; \
		fi; \
	done; \
	if ! docker scout version >/dev/null 2>&1; then \
		echo "ERROR: docker scout not available (install Docker Scout CLI or enable Docker Desktop Scout)."; \
		missing=1; \
	fi; \
	if [ $$missing -ne 0 ]; then exit 1; fi
	@if ! docker image inspect $(IMAGE) >/dev/null 2>&1; then \
		echo "ERROR: image $(IMAGE) not found. Run 'make build' first."; \
		exit 1; \
	fi
	@secfile="../SECURITY.txt"; \
	: > $$secfile; \
	{ echo "== TRIVY ($$(date -u +%Y-%m-%dT%H:%M:%SZ)) =="; \
	  trivy image $(IMAGE) --pkg-types os,library --format table; \
	  echo; } | tee -a $$secfile; \
	{ echo "== DOCKER SCOUT ($$(date -u +%Y-%m-%dT%H:%M:%SZ)) =="; \
	  docker scout cves $(IMAGE) --format only-packages --only-vuln-packages; \
	  echo; } | tee -a $$secfile; \
	{ echo "== GRYPE ($$(date -u +%Y-%m-%dT%H:%M:%SZ)) =="; \
	  grype $(IMAGE); \
	  echo; } | tee -a $$secfile

run-local:
	@if ! docker image inspect $(IMAGE) >/dev/null 2>&1; then \
		echo "ERROR: image $(IMAGE) not found. Run 'make build' first."; \
		exit 1; \
	fi
	@img_arch=$$(docker image inspect -f '{{.Architecture}}' $(IMAGE) 2>/dev/null); \
	if [ -z "$$img_arch" ]; then \
		echo "ERROR: unable to detect image architecture for $(IMAGE)."; \
		exit 1; \
	fi; \
	platform="linux/$$img_arch"; \
	docker run --rm -it \
		--platform $$platform \
		-e DSTP_VERSION=$(DSTP_VERSION) \
		-e K9S_VERSION=$(K9S_VERSION) \
		-e KUBECTL_SRC_VERSION=$(KUBECTL_SRC_VERSION) \
		-e YQ_VERSION=$(YQ_VERSION) \
		-v "$(PWD)/versions.sh":/usr/local/bin/versions.sh:ro \
		-w /home/devuser \
		$(IMAGE) -lc 'echo "Check all tool versions running: versions.sh"; exec bash'

run-gh:
	@docker run --rm -it \
		-e DSTP_VERSION=$(DSTP_VERSION) \
		-e K9S_VERSION=$(K9S_VERSION) \
		-e KUBECTL_SRC_VERSION=$(KUBECTL_SRC_VERSION) \
		-e YQ_VERSION=$(YQ_VERSION) \
		-v "$(PWD)/versions.sh":/usr/local/bin/versions.sh:ro \
		-w /home/devuser \
		ghcr.io/fragolinux/alpinetools:latest -lc 'echo "Check all tool versions running: versions.sh"; exec bash'

run-dh:
	@docker run --rm -it \
		-e DSTP_VERSION=$(DSTP_VERSION) \
		-e K9S_VERSION=$(K9S_VERSION) \
		-e KUBECTL_SRC_VERSION=$(KUBECTL_SRC_VERSION) \
		-e YQ_VERSION=$(YQ_VERSION) \
		-v "$(PWD)/versions.sh":/usr/local/bin/versions.sh:ro \
		-w /home/devuser \
		fragolinux/alpinetools:latest -lc 'echo "Check all tool versions running: versions.sh"; exec bash'

prerelease:
	@if ! docker image inspect $(IMAGE) >/dev/null 2>&1; then \
		echo "ERROR: image $(IMAGE) not found. Run 'make build' first."; \
		exit 1; \
	fi
	@img_arch=$$(docker image inspect -f '{{.Architecture}}' $(IMAGE) 2>/dev/null); \
	if [ -z "$$img_arch" ]; then \
		echo "ERROR: unable to detect image architecture for $(IMAGE)."; \
		exit 1; \
	fi; \
	platform="linux/$$img_arch"; \
	docker run --rm \
		--platform $$platform \
		-e DSTP_VERSION=$(DSTP_VERSION) \
		-e K9S_VERSION=$(K9S_VERSION) \
		-e KUBECTL_SRC_VERSION=$(KUBECTL_SRC_VERSION) \
		-e YQ_VERSION=$(YQ_VERSION) \
		-v "$(PWD)/versions.sh":/usr/local/bin/versions.sh:ro \
		$(IMAGE) /usr/local/bin/versions.sh > ../VERSIONS.txt

x86:
	$(MAKE) build PLATFORM=linux/amd64

arm:
	$(MAKE) build PLATFORM=linux/arm64

clean:
	docker buildx prune -f

release:
	@if ! command -v git >/dev/null 2>&1; then \
		echo "ERROR: git not found."; \
		exit 1; \
	fi
	@if ! git diff --quiet || ! git diff --cached --quiet; then \
		echo "ERROR: working tree is dirty. Commit or stash changes first."; \
		exit 1; \
	fi
	@set -e; \
	last_tag=$$(git tag --list | sort -V | tail -n1); \
	if [ -z "$$last_tag" ]; then last_tag="0.0.0"; fi; \
	base_tag="$${last_tag#v}"; \
	major=$$(echo "$$base_tag" | awk -F. '{print $$1}'); \
	minor=$$(echo "$$base_tag" | awk -F. '{print $$2}'); \
	patch=$$(echo "$$base_tag" | awk -F. '{print $$3}'); \
	patch=$$((patch+1)); \
	new_tag="$$major.$$minor.$$patch"; \
	echo "Tagging $$new_tag (previous: $$last_tag)"; \
	git push origin; \
	git tag "$$new_tag"; \
	git push origin "$$new_tag";
