#!/bin/bash
set -euo pipefail

# Auto-remediation script for Alpine package vulnerabilities
# Limits: Max 3 attempts to avoid excessive iterations

VULNERABLE_PACKAGES="$1"
MAX_ATTEMPTS=3
ATTEMPT=0

echo "🔍 Analyzing vulnerable packages: $VULNERABLE_PACKAGES"

if [ -z "$VULNERABLE_PACKAGES" ]; then
    echo "No vulnerable packages to fix"
    exit 0
fi

# Function to add packages to upgrade list in Dockerfile
add_packages_to_dockerfile() {
    local dockerfile="$1"
    local packages="$2"
    
    echo "📝 Updating $dockerfile..."
    
    # Find the RUN apk upgrade line with the explicit package list
    if ! grep -q "apk add --no-cache --upgrade" "$dockerfile"; then
        echo "⚠️ Cannot find package upgrade section in $dockerfile"
        return 1
    fi
    
    # For each package, check if it's already in the upgrade list
    for pkg in $packages; do
        if grep -q "apk add --no-cache --upgrade" "$dockerfile" && \
           ! grep -A 10 "apk add --no-cache --upgrade" "$dockerfile" | grep -q "^\s*$pkg\s*\\\\"; then
            
            echo "  Adding $pkg to upgrade list"
            
            # Add package after libssl3 line (or adjust as needed)
            # This uses sed to insert the package in the upgrade section
            sed -i.bak "/libssl3 \\\\/a\\    $pkg \\\\" "$dockerfile"
        else
            echo "  $pkg already in upgrade list or not applicable"
        fi
    done
    
    # Clean up backup file
    rm -f "$dockerfile.bak"
}

# Function to clean up and deduplicate packages
cleanup_dockerfile() {
    local dockerfile="$1"
    
    echo "🧹 Cleaning up $dockerfile..."
    
    # Remove any duplicate lines in the upgrade section (simplified approach)
    # This is a safety measure to avoid adding the same package multiple times
    
    # Note: In a more sophisticated version, we could parse and reconstruct
    # the entire RUN command, but for now we rely on the check above
}

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo ""
    echo "🔄 Attempt $ATTEMPT of $MAX_ATTEMPTS"
    
    # Update main Dockerfile
    if [ -f "Dockerfile" ]; then
        add_packages_to_dockerfile "Dockerfile" "$VULNERABLE_PACKAGES"
        cleanup_dockerfile "Dockerfile"
    fi
    
    # Update Cato Dockerfile
    if [ -f "cato/Dockerfile.cato" ]; then
        add_packages_to_dockerfile "cato/Dockerfile.cato" "$VULNERABLE_PACKAGES"
        cleanup_dockerfile "cato/Dockerfile.cato"
    fi
    
    echo "✅ Packages added to upgrade list in attempt $ATTEMPT"
    
    # In a real scenario, we would rebuild and test here
    # But that's handled by the GitHub Action workflow
    break
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "⚠️ Reached maximum attempts ($MAX_ATTEMPTS)"
    exit 1
fi

echo ""
echo "✨ Fix script completed successfully"
echo "📋 Modified files:"
git diff --name-only || true
