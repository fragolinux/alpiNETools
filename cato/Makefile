.PHONY: help test build sec release

IMAGE ?= alpinetools:local
DOCKERFILE ?= Dockerfile.cato
CATO_BUNDLE ?= $(HOME)/.cato/ca-bundle.crt

help:
	@echo "Available targets:"
	@echo "  make test  - verify Cato certs and (re)build bundle"
	@echo "  make build - local Docker build using Cato bundle"
	@echo "  make sec   - run Trivy on the locally built image"
	@echo "  make release - bump patch tag and push branch + tag"
	@echo ""
	@echo "Variables:"
	@echo "  IMAGE=$(IMAGE)"
	@echo "  DOCKERFILE=$(DOCKERFILE)"
	@echo "  CATO_BUNDLE=$(CATO_BUNDLE)"

default: help

test:
	./cato-bundle.sh

build:
	docker buildx build --load -t $(IMAGE) \
		-f $(DOCKERFILE) \
		--secret id=cato_ca,src=$(CATO_BUNDLE) \
		.

sec:
	@if ! command -v trivy >/dev/null 2>&1; then \
		echo "ERROR: trivy not found. Install it and retry."; \
		exit 1; \
	fi
	@if ! docker image inspect $(IMAGE) >/dev/null 2>&1; then \
		echo "ERROR: image $(IMAGE) not found. Run 'make build' first."; \
		exit 1; \
	fi
	trivy image $(IMAGE) --vuln-type os,library --severity HIGH,CRITICAL --exit-code 1

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
