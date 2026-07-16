#!/bin/bash
# DevOps Automator Skill Validation Script
# Validates DevOps configurations for common issues

set -uo pipefail

SKILL_DIR="$(dirname "$0")/.."
ERRORS=0
WARNINGS=0

echo "═══════════════════════════════════════════════════════════════"
echo "DevOps Automator Skill Validator"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check for GitHub Actions workflow files
check_github_actions() {
    echo "🔍 Checking GitHub Actions workflows..."

    if [ -d ".github/workflows" ]; then
        for workflow in .github/workflows/*.yml .github/workflows/*.yaml; do
            [ -f "$workflow" ] || continue

            # Check for deprecated actions
            if grep -q "actions/checkout@v2\|actions/checkout@v3" "$workflow" 2>/dev/null; then
                echo "⚠️  WARN: $workflow uses outdated checkout action (use v4)"
                ((WARNINGS++))
            fi

            # Check for missing concurrency controls
            if ! grep -q "concurrency:" "$workflow" 2>/dev/null; then
                echo "⚠️  WARN: $workflow missing concurrency control"
                ((WARNINGS++))
            fi

            # Check for hardcoded secrets
            if grep -qE "(password|secret|token):\s*['\"][^{]" "$workflow" 2>/dev/null; then
                echo "❌ ERROR: $workflow may contain hardcoded secrets"
                ((ERRORS++))
            fi

            # Check for caching
            if ! grep -q "cache:" "$workflow" 2>/dev/null; then
                echo "⚠️  WARN: $workflow missing caching (slower builds)"
                ((WARNINGS++))
            fi
        done
    else
        echo "ℹ️  No GitHub Actions workflows found"
    fi
}

# Check Dockerfile best practices
check_dockerfile() {
    echo ""
    echo "🐳 Checking Dockerfiles..."

    for dockerfile in Dockerfile Dockerfile.*; do
        [ -f "$dockerfile" ] || continue

        # Check for USER instruction (non-root)
        if ! grep -q "^USER " "$dockerfile" 2>/dev/null; then
            echo "⚠️  WARN: $dockerfile runs as root (add USER instruction)"
            ((WARNINGS++))
        fi

        # Check for HEALTHCHECK
        if ! grep -q "^HEALTHCHECK " "$dockerfile" 2>/dev/null; then
            echo "⚠️  WARN: $dockerfile missing HEALTHCHECK"
            ((WARNINGS++))
        fi

        # Check for latest tag
        if grep -qE "^FROM .+:latest" "$dockerfile" 2>/dev/null; then
            echo "❌ ERROR: $dockerfile uses :latest tag (pin versions)"
            ((ERRORS++))
        fi

        # Check for multi-stage build
        if [ $(grep -c "^FROM " "$dockerfile" 2>/dev/null) -lt 2 ]; then
            echo "ℹ️  INFO: $dockerfile is not multi-stage (consider optimization)"
        fi
    done
}

# Check Kubernetes manifests
check_kubernetes() {
    echo ""
    echo "☸️  Checking Kubernetes manifests..."

    for manifest in k8s/*.yaml k8s/**/*.yaml kubernetes/*.yaml; do
        [ -f "$manifest" ] || continue

        # Check for resource limits
        if grep -q "kind: Deployment\|kind: StatefulSet" "$manifest" 2>/dev/null; then
            if ! grep -q "resources:" "$manifest" 2>/dev/null; then
                echo "❌ ERROR: $manifest missing resource limits"
                ((ERRORS++))
            fi
        fi

        # Check for liveness/readiness probes
        if grep -q "kind: Deployment" "$manifest" 2>/dev/null; then
            if ! grep -q "livenessProbe:\|readinessProbe:" "$manifest" 2>/dev/null; then
                echo "⚠️  WARN: $manifest missing health probes"
                ((WARNINGS++))
            fi
        fi

        # Check for security context
        if ! grep -q "securityContext:" "$manifest" 2>/dev/null; then
            echo "⚠️  WARN: $manifest missing security context"
            ((WARNINGS++))
        fi
    done
}

# Check Terraform configurations
check_terraform() {
    echo ""
    echo "🏗️  Checking Terraform configurations..."

    if [ -d "terraform" ] || ls *.tf 1>/dev/null 2>&1; then
        # Check for version constraints
        if ! grep -q "required_version" *.tf terraform/*.tf 2>/dev/null; then
            echo "⚠️  WARN: Missing Terraform version constraint"
            ((WARNINGS++))
        fi

        # Check for provider version pinning
        if ! grep -q "version.*=.*\"~>" *.tf terraform/*.tf 2>/dev/null; then
            echo "⚠️  WARN: Missing provider version pinning"
            ((WARNINGS++))
        fi

        # Check for sensitive variables
        if grep -qE "variable.*default.*=.*(password|secret|key)" *.tf terraform/*.tf 2>/dev/null; then
            echo "❌ ERROR: Sensitive defaults in Terraform variables"
            ((ERRORS++))
        fi
    else
        echo "ℹ️  No Terraform configurations found"
    fi
}

# Run all checks
check_github_actions
check_dockerfile
check_kubernetes
check_terraform

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Validation Complete"
echo "═══════════════════════════════════════════════════════════════"
echo "Errors:   $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo "❌ Validation FAILED - fix errors before deployment"
    exit 1
elif [ $WARNINGS -gt 5 ]; then
    echo "⚠️  Validation PASSED with warnings - review recommended"
    exit 0
else
    echo "✅ Validation PASSED"
    exit 0
fi
