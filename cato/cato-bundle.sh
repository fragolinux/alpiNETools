#!/usr/bin/env bash
set -euo pipefail

# Local-only helper for Cato VPN TLS issues.
# Creates/updates a CA bundle for Docker builds without modifying the repo.

say(){ printf '%s\n' "$*"; }
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }

have(){ command -v "$1" >/dev/null 2>&1; }

HOME_CA_ROOT="${HOME}/CatoNetworksTrustedRootCA.crt"
HOME_CA_INT="${HOME}/CatoNetworksIntermediateCA.crt"
CATO_DIR="${HOME}/.cato"
BUNDLE="${CATO_DIR}/ca-bundle.crt"
BUNDLE_SHA="${CATO_DIR}/ca-bundle.sha256"
TMP_INT="/tmp/cato-intermediate.crt"
TMP_ROOT="/tmp/cato-root.crt"

SYS_CA_DARWIN="/etc/ssl/cert.pem"
SYS_CA_LINUX_1="/etc/ssl/certs/ca-certificates.crt"
SYS_CA_LINUX_2="/etc/pki/tls/certs/ca-bundle.crt"

detect_sys_ca() {
  if [[ "$(uname -s)" == "Darwin" ]] && [[ -f "$SYS_CA_DARWIN" ]]; then
    printf '%s' "$SYS_CA_DARWIN"; return 0
  fi
  if [[ -f "$SYS_CA_LINUX_1" ]]; then
    printf '%s' "$SYS_CA_LINUX_1"; return 0
  fi
  if [[ -f "$SYS_CA_LINUX_2" ]]; then
    printf '%s' "$SYS_CA_LINUX_2"; return 0
  fi
  printf ''
}

check_cert_file() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  [[ -s "$f" ]] || return 1
  return 0
}

check_cert_valid() {
  local f="$1"
  openssl x509 -in "$f" -noout -checkend 0 >/dev/null 2>&1
}

print_cert_info() {
  local f="$1"
  openssl x509 -in "$f" -noout -subject -issuer -dates
}

build_bundle_tmp() {
  local sys_ca="$1"
  local tmp="$2"
  : > "$tmp"
  [[ -f "$HOME_CA_INT" ]] && cat "$HOME_CA_INT" >> "$tmp"
  [[ -f "$HOME_CA_ROOT" ]] && cat "$HOME_CA_ROOT" >> "$tmp"
  [[ -n "$sys_ca" && -f "$sys_ca" ]] && cat "$sys_ca" >> "$tmp"
}

extract_chain_from_host() {
  local host="${1:-proxy.golang.org}" port="${2:-443}" sni="${3:-$host}"
  rm -f /tmp/.cato_chain_*.pem "$TMP_INT" "$TMP_ROOT" 2>/dev/null || true
  if have openssl; then
    (
      openssl s_client -showcerts -connect "${host}:${port}" -servername "${sni}" </dev/null 2>/dev/null \
      | awk '/BEGIN CERTIFICATE/ {i++} {fn=sprintf("/tmp/.cato_chain_%d.pem",i); print > fn}'
    ) || true
    [[ -s /tmp/.cato_chain_2.pem ]] && mv /tmp/.cato_chain_2.pem "$TMP_INT" || true
    [[ -s /tmp/.cato_chain_3.pem ]] && mv /tmp/.cato_chain_3.pem "$TMP_ROOT" || true
    rm -f /tmp/.cato_chain_*.pem 2>/dev/null || true
  fi
}

ensure_intermediate_cert() {
  if check_cert_file "$HOME_CA_INT"; then
    return 0
  fi
  say "Intermediate CA missing, attempting to fetch from TLS chain..."
  extract_chain_from_host "proxy.golang.org" 443 "proxy.golang.org" || true
  if [[ -s "$TMP_INT" ]]; then
    cp "$TMP_INT" "$HOME_CA_INT"
    say "Intermediate CA created at $HOME_CA_INT"
    return 0
  fi
  say "WARNING: Unable to fetch Intermediate CA automatically."
  return 1
}

sha256_file() {
  if have shasum; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

bundle_needs_update() {
  local new_sha="$1"
  if [[ ! -f "$BUNDLE" || ! -f "$BUNDLE_SHA" ]]; then
    return 0
  fi
  local old_sha
  old_sha="$(cat "$BUNDLE_SHA" 2>/dev/null || true)"
  [[ "$new_sha" != "$old_sha" ]]
}

check_cato_in_chain() {
  # If VPN is on and Cato is intercepting, the TLS chain often contains "Cato".
  # We only warn if no Cato is found.
  local host="proxy.golang.org"
  if have openssl; then
    if openssl s_client -showcerts -connect "${host}:443" -servername "${host}" </dev/null 2>/dev/null \
      | awk '/BEGIN CERTIFICATE/ {i++} {print > ("/tmp/.cato_chain_" i ".pem")}' >/dev/null 2>&1; then
      local hit=0 f
      for f in /tmp/.cato_chain_*.pem; do
        [[ -f "$f" ]] || continue
        if openssl x509 -in "$f" -noout -issuer -subject 2>/dev/null | grep -qi "cato"; then
          hit=1
          break
        fi
      done
      rm -f /tmp/.cato_chain_*.pem >/dev/null 2>&1 || true
      [[ $hit -eq 1 ]] && return 0
    fi
  fi
  return 1
}

main() {
  have openssl || fail "openssl is required"

  say "Cato bundle helper"
  say "Root CA: $HOME_CA_ROOT"
  say "Intermediate CA: $HOME_CA_INT"
  say "Bundle: $BUNDLE"
  say ""

  if ! check_cert_file "$HOME_CA_ROOT"; then
    fail "Missing $HOME_CA_ROOT (place the Cato root CA at this path and re-run)"
  fi

  say "Checking cert validity..."
  check_cert_valid "$HOME_CA_ROOT" || fail "Root CA is expired or invalid"
  ensure_intermediate_cert || true
  if check_cert_file "$HOME_CA_INT"; then
    check_cert_valid "$HOME_CA_INT" || fail "Intermediate CA is expired or invalid"
  fi

  say "Root CA info:"
  print_cert_info "$HOME_CA_ROOT"
  if check_cert_file "$HOME_CA_INT"; then
    say "Intermediate CA info:"
    print_cert_info "$HOME_CA_INT"
  else
    say "WARNING: Intermediate CA still missing; bundle will include only root + system CA"
  fi

  local sys_ca
  sys_ca="$(detect_sys_ca)"
  [[ -n "$sys_ca" ]] || fail "System CA bundle not found"

  mkdir -p "$CATO_DIR"
  local tmp_bundle
  tmp_bundle="$(mktemp)"
  build_bundle_tmp "$sys_ca" "$tmp_bundle"

  local new_sha
  new_sha="$(sha256_file "$tmp_bundle")"

  if bundle_needs_update "$new_sha"; then
    say "Creating/updating bundle..."
    mv "$tmp_bundle" "$BUNDLE"
    printf '%s\n' "$new_sha" > "$BUNDLE_SHA"
  else
    say "Bundle is up-to-date."
    rm -f "$tmp_bundle"
  fi

  if ! grep -qi "cato" "$BUNDLE"; then
    say "WARNING: Bundle does not contain 'Cato' in subjects/issuers."
  fi

  if check_cato_in_chain; then
    say "VPN check: Cato detected in TLS chain."
  else
    say "WARNING: Cato NOT detected in TLS chain."
    say "If you are on VPN, reconnect and re-run this script to validate."
  fi

  say ""
  say "Next step for local build:"
  say "docker buildx build --load -t alpinetools:local \\"
  say "  -f Dockerfile.cato \\"
  say "  --secret id=cato_ca,src=$BUNDLE \\"
  say "  ."
  say ""
  say "Alternative (if make is installed):"
  say "  make build"
}

main "$@"
