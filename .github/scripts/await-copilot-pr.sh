#!/bin/bash
set -euo pipefail

issue_number="${ISSUE_NUMBER:?missing ISSUE_NUMBER}"
wait_minutes="${WAIT_MINUTES:-20}"
repo="${GITHUB_REPOSITORY:?missing GITHUB_REPOSITORY}"

deadline=$(( $(date +%s) + wait_minutes * 60 ))

while [ "$(date +%s)" -lt "$deadline" ]; do
    timeline="$(gh api \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "/repos/${repo}/issues/${issue_number}/timeline" 2>/dev/null || true)"

    pr_url="$(printf '%s' "$timeline" | jq -r '
      [
        .[]?
        | select(.event == "cross-referenced")
        | .source.issue?
        | select(.pull_request)
        | .html_url
      ]
      | last // empty
    ')"

    if [ -n "$pr_url" ]; then
        printf 'pr_url=%s\n' "$pr_url"
        exit 0
    fi

    sleep 60
done

printf 'pr_url=\n'
