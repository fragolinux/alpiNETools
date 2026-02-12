#!/usr/bin/env bash
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

run_cmd() {
  if have timeout; then
    timeout 3 "$@"
  elif have gtimeout; then
    gtimeout 3 "$@"
  else
    "$@"
  fi
}

print_ver() {
  local name="$1"; shift
  local cmd=("$@")
  if ! have "$name"; then
    printf "%-18s %s\n" "$name" "missing"
    return 0
  fi
  local out
  if out="$(run_cmd "${cmd[@]}" 2>&1 | head -n1 || true)"; then
    out="${out//$'\r'/}"
    printf "%-18s %s\n" "$name" "${out:-unknown}"
  else
    printf "%-18s %s\n" "$name" "unknown"
  fi
}

echo "Tool versions"
echo "------------"
print_ver bash bash --version
print_ver curl curl --version
print_ver iperf3 iperf3 --version
print_ver tcpdump tcpdump --version
print_ver dig dig -v
print_ver netstat netstat --version
print_ver ip ip -V
print_ver ping ping -V
print_ver traceroute traceroute --version
print_ver mtr mtr --version
print_ver socat socat -V
print_ver nc nc -h
print_ver telnet telnet --help
print_ver jq jq --version
print_ver trurl trurl --version
print_ver http http --version
print_ver tar tar --version
print_ver gzip gzip --version
print_ver bzip2 bzip2 --version
print_ver openssl openssl version
print_ver nmap nmap --version
print_ver nano nano --version
print_ver file file --version
print_ver hurl hurl --version
if [[ -n "${DSTP_VERSION:-}" ]]; then
  printf "%-18s %s\n" "dstp" "v${DSTP_VERSION#v}"
else
  print_ver dstp dstp
fi
if [[ -n "${K9S_VERSION:-}" ]]; then
  printf "%-18s %s\n" "k9s" "${K9S_VERSION}"
else
  print_ver k9s k9s version --short
fi
if [[ -n "${KUBECTL_SRC_VERSION:-}" ]]; then
  printf "%-18s %s\n" "kubectl" "${KUBECTL_SRC_VERSION}"
else
  print_ver kubectl kubectl version --client --output=yaml
fi
if [[ -n "${YQ_VERSION:-}" ]]; then
  printf "%-18s %s\n" "yq" "${YQ_VERSION}"
else
  print_ver yq yq --version
fi
