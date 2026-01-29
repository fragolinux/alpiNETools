# Cato VPN: Local Build Guide

## Paths

- Cato root CA: `~/CatoNetworksTrustedRootCA.crt`
- Cato intermediate CA (if available): `~/CatoNetworksIntermediateCA.crt`
- Local bundle (recommended): `~/.cato/ca-bundle.crt`

## 1) Verify Cato certificates

Required file (must exist):
```bash
ls -l ~/CatoNetworksTrustedRootCA.crt
```

Check validity dates and subject/issuer:
```bash
openssl x509 -in ~/CatoNetworksTrustedRootCA.crt -noout -subject -issuer -dates
```

If the root CA is missing or expired, replace it and re-run the script.

## 2) Create or regenerate the bundle (scripted)

Use the helper script to:
- verify the root CA
- create the intermediate CA if missing
- build or refresh the bundle
- warn if VPN appears disconnected

## 3) Verify bundle is present and updated (scripted)

The script performs:
- bundle existence check
- bundle content check
- TLS validation against `proxy.golang.org`

If any of these fail, it regenerates the bundle and reports the issue.

## 4) Use the bundle for local Docker builds

Use your Dockerfile and pass the bundle as a secret:
```bash
docker buildx build --load -t myimage:local \
  -f <your-dockerfile> \
  --secret id=cato_ca,src=$HOME/.cato/ca-bundle.crt \
  .
```

## 4.1) Makefile shortcuts

Targets:
- `make test` runs the CA checks and (re)builds the bundle if needed.
- `make build` performs the local Docker build using the CA bundle secret.
- `make sec` runs Trivy on the locally built image (fails on HIGH/CRITICAL).
- `make release` bumps patch tag and pushes branch + tag.

Environment overrides:
```bash
IMAGE=myimage:local DOCKERFILE=<your-dockerfile> CATO_BUNDLE=$HOME/.cato/ca-bundle.crt make build
```

## 5) How to adapt any Dockerfile (future projects)

Required changes:
1) Add BuildKit syntax at the very top:
```dockerfile
# syntax=docker/dockerfile:1.6
```

2) In the stage that needs outbound TLS (e.g., Go builder),
mount the bundle as a secret and update CA store:
```dockerfile
RUN --mount=type=secret,id=cato_ca,target=/usr/local/share/ca-certificates/cato-ca.crt \
    update-ca-certificates
```

3) Build with:
```bash
docker buildx build \
  --secret id=cato_ca,src=$HOME/.cato/ca-bundle.crt \
  -f <your-dockerfile> \
  .
```

Notes:
- This keeps Cato certs out of the image and out of git history.
- Only for local builds under VPN.

---

## Helper script (recommended)

The script automates:
- Checking Cato cert presence and validity
- Creating the intermediate CA if missing
- Rebuilding the bundle if missing or outdated
- Warning if VPN appears to be off (no Cato in TLS chain)
- Printing the exact build command to use

Run:
```bash
chmod +x cato/cato-bundle.sh
./cato/cato-bundle.sh
```
