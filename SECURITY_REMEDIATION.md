# Remediation note — CVE-2026-50163 (oras-go)

Date: 2026-07-10

Summary:
- Affected: `usr/local/bin/k9s` (gobinary) built during image build.
- Vulnerable library: `oras.land/oras-go/v2` (CVE-2026-50163)
- Trivy scan shows a HIGH finding in the `k9s` binary after rebuilding.

Context:
- I attempted to bump `oras-go` to v2.6.2, but that tag does not exist in the module proxy; available versions end at v2.6.1.

Decision:
- Accept the risk temporarily and track remediation in this file and in the repo TODOs.

Rationale:
- No upstream fixed release is currently available to safely update the dependency.
- Producing/maintaining a forked fix or removing `k9s` are non-trivial changes that require coordination; for now we prefer to document and monitor.

Next steps (recommended):
1. Open an upstream issue / PR against `oras-go` to request a fix (if none exists).
2. Consider creating a temporary fork + patch and use `go mod edit -replace` to point `k9s` at the fork (short-term mitigation).
3. If `k9s` is not essential in some deployments, remove it from the image until upstream fixes the library.
4. Re-scan weekly and update this file when upstream publishes a fixed release.

Owner: @mrshark

Suggested issue body (copy to GitHub issue):
Title: "Request: security fix for CVE-2026-50163 in oras.land/oras-go/v2"

Body:
```
We detected CVE-2026-50163 affecting oras.land/oras-go/v2 when building the k9s binary.

Details:
- Affected module: oras.land/oras-go/v2
- Trivy finding: CVE-2026-50163 (HIGH)

Request:
Please advise whether a fixed release is planned, or accept a PR with a backported fix.

Context: the fix is currently not available via module proxy (latest available tag v2.6.1). We can supply a PR or a fork for testing if helpful.
```
