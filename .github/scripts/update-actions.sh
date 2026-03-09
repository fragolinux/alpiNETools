#!/bin/bash
set -euo pipefail

# Script to check and update outdated GitHub Actions
# Limits: Only checks common actions to avoid excessive API calls

echo "🔍 Checking for outdated GitHub Actions..."

WORKFLOW_DIR=".github/workflows"
UPDATED=false

# Function to get the latest release tag for a GitHub repo
get_latest_version() {
    local repo="$1"
    local current_version="$2"
    
    # Try to get latest release from GitHub API (with rate limiting consideration)
    # Using Accept header for v3 API
    local latest=$(curl -s -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$repo/releases/latest" | \
        jq -r '.tag_name // empty' 2>/dev/null || echo "")
    
    if [ -z "$latest" ]; then
        # Fallback: try tags endpoint
        latest=$(curl -s -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$repo/tags" | \
            jq -r '.[0].name // empty' 2>/dev/null || echo "")
    fi
    
    echo "$latest"
}

# Function to compare versions (simple major version comparison)
should_update() {
    local current="$1"
    local latest="$2"
    
    # Extract major version numbers
    current_major=$(echo "$current" | sed 's/v//' | cut -d. -f1)
    latest_major=$(echo "$latest" | sed 's/v//' | cut -d. -f1)
    
    # Update if latest major version is greater
    if [ "$latest_major" -gt "$current_major" ] 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Function to update action version in workflow files
update_action() {
    local action_name="$1"
    local old_version="$2"
    local new_version="$3"
    
    echo "  📦 Updating $action_name: $old_version → $new_version"
    
    # Update in all workflow files
    shopt -s nullglob
    for workflow in "$WORKFLOW_DIR"/*.yml "$WORKFLOW_DIR"/*.yaml; do
        if [ -f "$workflow" ]; then
            # Use @ to match version tags
            sed -i.bak "s|$action_name@$old_version|$action_name@$new_version|g" "$workflow"
            rm -f "$workflow.bak"
        fi
    done
    shopt -u nullglob
    
    UPDATED=true
}

# Check common actions used in the repository
# Format: "owner/repo" "pattern_to_find" "api_repo_path"
ACTIONS_TO_CHECK=(
    "actions/checkout"
    "actions/setup-go"
    "docker/setup-buildx-action"
    "docker/setup-qemu-action"
    "docker/login-action"
    "docker/build-push-action"
    "aquasecurity/setup-trivy"
    "aquasecurity/trivy-action"
    "github/codeql-action/upload-sarif"
    "peter-evans/create-pull-request"
    "softprops/action-gh-release"
)

echo ""
echo "📋 Scanning workflows in $WORKFLOW_DIR..."

for action_path in "${ACTIONS_TO_CHECK[@]}"; do
    # Extract action name and current version from workflow files
    action_name="${action_path}"
    
    # Find current version used in workflows
    current_version=""
    shopt -s nullglob
    for workflow in "$WORKFLOW_DIR"/*.yml "$WORKFLOW_DIR"/*.yaml; do
        if [ -f "$workflow" ] && grep -q "$action_name@" "$workflow"; then
            current_version=$(grep "$action_name@" "$workflow" | head -1 | sed "s|.*$action_name@||" | awk '{print $1}')
            break
        fi
    done
    shopt -u nullglob
    
    if [ -z "$current_version" ]; then
        continue
    fi
    
    echo ""
    echo "🔎 Checking $action_name (current: $current_version)"
    
    # Get latest version from GitHub
    # Extract repo path (handle nested paths like codeql-action/upload-sarif)
    repo_path=$(echo "$action_path" | cut -d'/' -f1-2)
    latest_version=$(get_latest_version "$repo_path" "$current_version")
    
    if [ -z "$latest_version" ]; then
        echo "  ⚠️ Could not determine latest version (API rate limit or repo issue)"
        continue
    fi
    
    echo "  Latest version: $latest_version"
    
    # Simple version comparison (major version only to avoid too many updates)
    if [ "$current_version" != "$latest_version" ]; then
        if should_update "$current_version" "$latest_version"; then
            update_action "$action_name" "$current_version" "$latest_version"
        else
            echo "  ℹ️ Current version is recent enough (same major version)"
        fi
    else
        echo "  ✅ Already up to date"
    fi
    
    # Rate limiting: small delay between API calls
    sleep 0.5
done

echo ""
if [ "$UPDATED" = true ]; then
    echo "✨ GitHub Actions updated successfully"
    echo "📋 Modified workflows:"
    git diff --name-only "$WORKFLOW_DIR" || true
else
    echo "✅ All GitHub Actions are up to date"
fi
