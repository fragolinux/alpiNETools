# Copilot Remediation Workflow

This workflow delegates security remediation to GitHub Copilot coding agent when the classic auto-remediation workflow cannot safely resolve HIGH or CRITICAL Trivy findings on its own.

## What it does

1. The classic `auto-remediation.yaml` workflow attempts package-level fixes first
2. If unresolved findings remain and no PR candidate was produced, it dispatches this workflow
3. This workflow builds the container image locally in GitHub Actions
4. It runs Trivy and collects JSON plus table output
5. It creates a GitHub issue assigned to `copilot-swe-agent[bot]`
6. It passes remediation instructions and scan results to Copilot
7. It waits for the Copilot pull request
8. It retries up to 3 attempts if no PR is detected

## Important limits

- The workflow caps retries at 3 attempts.
- Copilot opens the pull request; this workflow does not push code itself.
- GitHub Actions on Copilot-created PRs still require manual approval with `Approve and run workflows`.

## Required secret

Set `GH_PAT` to a user token that can assign issues to Copilot.

According to GitHub documentation, a fine-grained token needs:

- Read access to metadata
- Read and write access to actions
- Read and write access to contents
- Read and write access to issues
- Read and write access to pull requests

For a classic token, `repo` scope is required.

## Triggering

- Automatic: dispatched by `auto-remediation.yaml` when classic remediation cannot safely finish the job
- Manual: run `Copilot Remediation` from the Actions tab

## Notes

- The workflow creates an issue, not a direct prompt session.
- Repository-wide instructions for Copilot live in `.github/copilot-instructions.md`.
- A custom agent profile is available at `.github/agents/security-remediation.agent.md` for manual use on GitHub.com.
