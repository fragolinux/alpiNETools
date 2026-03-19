#!/bin/bash
set -euo pipefail

TRIVY_JSON="${1:?missing trivy json path}"
TRIVY_TABLE="${2:?missing trivy table path}"
OUTPUT_FILE="${3:?missing output path}"

attempt="${REMEDIATION_ATTEMPT:-1}"
base_branch="${REMEDIATION_BASE_BRANCH:-main}"
run_url="${REMEDIATION_RUN_URL:-}"
workflow_ref="${REMEDIATION_WORKFLOW_REF:-}"
source_event="${REMEDIATION_SOURCE:-workflow_dispatch}"

summary_json="$(jq -r '
  [
    .Results[]?
    | select((.Vulnerabilities // []) | length > 0)
    | {
        target: .Target,
        type: .Type,
        vulnerabilities: [
          .Vulnerabilities[]?
          | select(.Severity == "HIGH" or .Severity == "CRITICAL")
          | {
              id: .VulnerabilityID,
              severity: .Severity,
              pkg: .PkgName,
              installed: .InstalledVersion,
              fixed: .FixedVersion
            }
        ]
      }
    | select((.vulnerabilities | length) > 0)
  ]
' "$TRIVY_JSON")"

summary_pretty="$(printf '%s\n' "$summary_json" | jq '.')"
table_excerpt="$(sed -n '1,220p' "$TRIVY_TABLE")"

cat > "$OUTPUT_FILE" <<EOF
## Copilot Security Remediation Task

This issue was created automatically by the \`copilot-remediation.yaml\` workflow.

### Objective

Inspect the current repository state, fix the reported HIGH/CRITICAL Trivy findings, and open exactly one pull request against \`${base_branch}\`.

### Constraints

1. Keep the patch minimal and directly related to the reported findings.
2. Do not add fake Alpine packages to \`apk add --upgrade\`.
3. If a finding is \`Type: gobinary\` and the vulnerable library is \`stdlib\`, remediate it by updating the Go toolchain or affected build inputs, not by editing Alpine package lists.
4. Preserve the current Docker image behavior unless a change is required to remediate the findings.
5. Do not create more than one pull request.

### Context

- Attempt: \`${attempt}\`
- Base branch: \`${base_branch}\`
- Trigger source: \`${source_event}\`
- Workflow run: ${run_url:-N/A}
- Workflow ref: \`${workflow_ref}\`

### Relevant Files

- \`Dockerfile\`
- \`cato/Dockerfile.cato\`
- \`.github/workflows/ci.yaml\`
- \`.github/workflows/auto-remediation.yaml\`

### Trivy Findings Summary

\`\`\`json
${summary_pretty}
\`\`\`

### Trivy Table Output

\`\`\`text
${table_excerpt}
\`\`\`

### Expected Outcome

- Open one pull request with the remediation.
- In the PR description, summarize the root cause and the concrete fix.
- If no safe remediation is possible, explain why in the PR and keep the patch minimal.
EOF
