# Copilot Repository Instructions

- Prefer the smallest safe remediation that directly addresses the reported problem.
- For Trivy findings on `gobinary` targets, never try to fix `stdlib` findings by editing Alpine package lists.
- If a vulnerability is fixed in a newer Go patch release, update the Go toolchain version consistently across `Dockerfile`, `cato/Dockerfile.cato`, `cato/Makefile`, and any workflow build arguments.
- Keep workflow changes narrowly scoped and preserve existing release behavior.
- Do not rewrite unrelated files or perform cosmetic refactors during security remediation.
