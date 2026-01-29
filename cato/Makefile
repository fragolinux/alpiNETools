.PHONY: test build sec

IMAGE ?= alpinetools:local
DOCKERFILE ?= Dockerfile.cato
CATO_BUNDLE ?= $(HOME)/.cato/ca-bundle.crt

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
