#!/bin/bash
# test-bundle-setup.sh - Comprehensive tests for bundle endpoint and client setup
#
# Tests cover:
# - Bundle contents verification
# - Client setup script flow
# - Dependency installation logic
# - Non-git repo installation handling
# - Docker image vendor submodule cloning

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

echo "=== Bundle and Client Setup Tests ==="
echo ""

# ============================================
# install.sh Non-Git Repo Handling
# ============================================
echo "--- install.sh Non-Git Repo Handling ---"

# Test: install.sh checks if .git directory exists
if grep -q '\.git.*-d\|! -d.*\.git\|-d "\$.*\.git"' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh checks if .git directory exists"
else
    fail "install.sh should check if .git directory exists"
fi

# Test: install.sh skips git commands when not a git repo
if grep -q 'Not a git repo\|skip.*submodule\|skipping submodule' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh skips git commands when not a git repo"
else
    fail "install.sh should skip git commands when not a git repo"
fi

# Test: install.sh checks VENDOR_DIR/opencode exists
if grep -q 'VENDOR_DIR.*opencode\|vendor.*opencode' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh checks vendor/opencode exists"
else
    fail "install.sh should check vendor/opencode exists"
fi

# Test: install.sh checks VENDOR_DIR/oh-my-opencode exists
if grep -q 'VENDOR_DIR.*oh-my-opencode\|vendor.*oh-my-opencode' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh checks vendor/oh-my-opencode exists"
else
    fail "install.sh should check vendor/oh-my-opencode exists"
fi

# Test: install.sh has error message for missing vendor dirs
if grep -q 'Vendor directories missing\|vendor.*missing\|bundle.*incomplete' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh has error message for missing vendor dirs"
else
    fail "install.sh should have error message for missing vendor dirs"
fi

# Test: install.sh exits with error if vendor dirs missing in non-git mode
if grep -q 'exit 1' "$PROJECT_ROOT/install.sh" && grep -q 'VENDOR_DIR' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh exits with error if vendor dirs missing"
else
    fail "install.sh should exit with error if vendor dirs missing"
fi

# Test: check_submodules function exists
if grep -q 'check_submodules\s*()' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh has check_submodules function"
else
    fail "install.sh should have check_submodules function"
fi

# Test: check_submodules is called
if grep 'check_submodules' "$PROJECT_ROOT/install.sh" | grep -v 'check_submodules()' | grep -q 'check_submodules'; then
    pass "install.sh calls check_submodules function"
else
    fail "install.sh should call check_submodules function"
fi

# ============================================
# Dockerfile.relay Vendor Submodule Cloning
# ============================================
echo ""
echo "--- Dockerfile.relay Vendor Submodule Cloning ---"

# Test: Dockerfile clones opencode repo
if grep -q 'git clone.*opencode' "$PROJECT_ROOT/Dockerfile.relay"; then
    pass "Dockerfile.relay clones opencode repo"
else
    fail "Dockerfile.relay should clone opencode repo"
fi

# Test: Dockerfile clones oh-my-opencode repo
if grep -q 'git clone.*oh-my-opencode' "$PROJECT_ROOT/Dockerfile.relay"; then
    pass "Dockerfile.relay clones oh-my-opencode repo"
else
    fail "Dockerfile.relay should clone oh-my-opencode repo"
fi

# Test: Dockerfile uses shallow clone (--depth 1)
if grep -q 'git clone --depth 1\|git clone.*--depth' "$PROJECT_ROOT/Dockerfile.relay"; then
    pass "Dockerfile.relay uses shallow clone for efficiency"
else
    fail "Dockerfile.relay should use shallow clone (--depth 1)"
fi

# Test: Dockerfile clones to vendor directory
if grep -q 'vendor/opencode\|vendor/oh-my-opencode' "$PROJECT_ROOT/Dockerfile.relay"; then
    pass "Dockerfile.relay clones to vendor directory"
else
    fail "Dockerfile.relay should clone to vendor directory"
fi

# Test: Dockerfile removes .git from cloned repos
if grep -q 'rm -rf vendor.*\.git' "$PROJECT_ROOT/Dockerfile.relay"; then
    pass "Dockerfile.relay removes .git from cloned repos"
else
    fail "Dockerfile.relay should remove .git from cloned repos"
fi

# Test: Dockerfile creates vendor directory first
if grep -q 'mkdir.*vendor' "$PROJECT_ROOT/Dockerfile.relay"; then
    pass "Dockerfile.relay creates vendor directory"
else
    fail "Dockerfile.relay should create vendor directory first"
fi

# Test: Dockerfile uses correct GitHub URLs
if grep -q 'github.com.*opencode' "$PROJECT_ROOT/Dockerfile.relay" && \
   grep -q 'github.com.*oh-my-opencode' "$PROJECT_ROOT/Dockerfile.relay"; then
    pass "Dockerfile.relay uses correct GitHub URLs"
else
    fail "Dockerfile.relay should use correct GitHub URLs for submodules"
fi

# ============================================
# Bundle Endpoint (main.ts)
# ============================================
echo ""
echo "--- Bundle Endpoint (main.ts) ---"

# Test: Bundle endpoint exists at /bundle.tar.gz
if grep -q '/bundle\.tar\.gz' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle endpoint exists at /bundle.tar.gz"
else
    fail "Bundle endpoint should exist at /bundle.tar.gz"
fi

# Test: Bundle endpoint logs REPO_PATH
if grep -q 'REPO_PATH.*log\|log.*REPO_PATH' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle endpoint logs REPO_PATH for debugging"
else
    fail "Bundle endpoint should log REPO_PATH for debugging"
fi

# Test: Bundle endpoint verifies essential files exist
if grep -q 'install\.sh.*lib.*relay\|ls.*install\.sh' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle endpoint verifies essential files exist"
else
    fail "Bundle endpoint should verify essential files exist"
fi

# Test: Bundle endpoint verifies essential files exist before streaming
if grep -q 'install\.sh.*lib.*relay\|ls.*install\.sh' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle endpoint verifies essential files exist before streaming"
else
    fail "Bundle endpoint should verify essential files exist before streaming"
fi

# Test: Bundle endpoint returns 500 error with details on failure
if grep -q 'status: 500\|500.*error' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle endpoint returns 500 error on failure"
else
    fail "Bundle endpoint should return 500 error on failure"
fi

# Test: Bundle endpoint includes repo_path in error response
if grep -q 'repo_path.*REPO_PATH\|REPO_PATH.*error' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle endpoint includes repo_path in error response"
else
    fail "Bundle endpoint should include repo_path in error response"
fi

# Test: Bun.serve has increased idleTimeout for large bundles
if grep -q 'idleTimeout' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bun.serve has idleTimeout configured"
else
    fail "Bun.serve should have idleTimeout configured for large bundle downloads"
fi

# Test: idleTimeout is at least 60 seconds
if grep -q 'idleTimeout.*[6-9][0-9]\|idleTimeout.*1[0-9][0-9]' "$PROJECT_ROOT/relay/main.ts"; then
    pass "idleTimeout is at least 60 seconds"
else
    fail "idleTimeout should be at least 60 seconds for bundle downloads"
fi

# Test: Bundle uses tar with gzip compression
if grep -q "tar -czf\|tar.*-c.*-z" "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle uses tar with gzip compression"
else
    fail "Bundle should use tar with gzip compression"
fi

# Test: Bundle excludes .git directory
if grep -q "exclude.*\.git\|--exclude=.*\.git" "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle excludes .git directory"
else
    fail "Bundle should exclude .git directory"
fi

# Test: Bundle excludes config.json (contains API key)
if grep -q "exclude.*config\.json\|--exclude=.*config\.json" "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle excludes config.json"
else
    fail "Bundle should exclude config.json (contains API key)"
fi

# Test: Bundle excludes node_modules
if grep -q "exclude.*node_modules\|--exclude=.*node_modules" "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle excludes node_modules"
else
    fail "Bundle should exclude node_modules"
fi

# Test: Bundle excludes .env files
if grep -q "exclude.*\.env\|--exclude=.*\.env" "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle excludes .env files"
else
    fail "Bundle should exclude .env files"
fi

# Test: Bundle excludes log files
if grep -q "exclude.*\.log\|--exclude=.*\.log" "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle excludes log files"
else
    fail "Bundle should exclude log files"
fi

# Test: Bundle uses REPO_PATH
if grep -q 'REPO_PATH' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle uses REPO_PATH for source directory"
else
    fail "Bundle should use REPO_PATH for source directory"
fi

# Test: Bundle returns application/gzip content type
if grep -q 'application/gzip' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle returns application/gzip content type"
else
    fail "Bundle should return application/gzip content type"
fi

# Test: Bundle endpoint uses streaming (execStream)
if grep -q 'execStream\|ReadableStream' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle endpoint uses streaming for large downloads"
else
    fail "Bundle endpoint should use streaming for large downloads"
fi

# Test: Bundle endpoint adds Content-Length header for progress
if grep -q 'Content-Length' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Bundle endpoint adds Content-Length header for progress"
else
    fail "Bundle endpoint should add Content-Length header for curl progress"
fi

# Test: Setup script uses curl with progress bar (-#)
if grep -q 'curl -#\|curl.*-#' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script uses curl with progress bar"
else
    fail "Setup script should use curl with progress bar (-#)"
fi

# Test: Setup script downloads to temp file first
if grep -q 'mktemp\|BUNDLE_TMP' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script downloads to temp file first"
else
    fail "Setup script should download to temp file to avoid partial extraction"
fi

# Test: Setup script cleans up temp file on failure
if grep -q 'rm -f.*TMP\|rm.*BUNDLE_TMP' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script cleans up temp file on failure"
else
    fail "Setup script should clean up temp file on failure"
fi

# ============================================
# Client Setup Script (embedded in main.ts)
# ============================================
echo ""
echo "--- Client Setup Script (in main.ts /setup endpoint) ---"

# Test: Setup script checks relay health first
if grep -q 'health.*curl\|curl.*health' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script checks relay health first"
else
    fail "Setup script should check relay health first"
fi

# Test: Setup script creates INSTALL_DIR
if grep -q 'mkdir.*INSTALL_DIR\|mkdir -p' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script creates INSTALL_DIR"
else
    fail "Setup script should create INSTALL_DIR"
fi

# Test: Setup script defaults INSTALL_DIR to PWD
if grep -q 'INSTALL_DIR.*PWD\|PWD.*sovereign-agent' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script defaults INSTALL_DIR to PWD"
else
    fail "Setup script should default INSTALL_DIR to PWD"
fi

# Test: Setup script downloads bundle
if grep -q 'bundle\.tar\.gz.*curl\|curl.*bundle\.tar\.gz' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script downloads bundle"
else
    fail "Setup script should download bundle"
fi

# Test: Setup script extracts bundle with tar
if grep -q 'tar -xzf\|tar.*-x.*-z' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script extracts bundle with tar"
else
    fail "Setup script should extract bundle with tar"
fi

# Test: Setup script verifies install.sh exists
if grep -q 'install\.sh.*not found\|install\.sh.*-f\|! -f.*install\.sh' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script verifies install.sh exists"
else
    fail "Setup script should verify install.sh exists"
fi

# Test: Setup script makes install.sh executable
if grep -q 'chmod.*install\.sh' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script makes install.sh executable"
else
    fail "Setup script should make install.sh executable"
fi

# Test: Setup script runs install.sh
if grep -q '\./install\.sh' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script runs install.sh"
else
    fail "Setup script should run install.sh"
fi

# Test: Setup script injects RELAY_PORT dynamically
if grep -q 'RELAY_PORT:-\${RELAY_PORT}' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script injects RELAY_PORT dynamically"
else
    fail "Setup script should inject RELAY_PORT dynamically"
fi

# ============================================
# Dependency Installation in Setup Script
# ============================================
echo ""
echo "--- Dependency Installation in Setup Script ---"

# Test: Setup script installs Bun if missing
if grep -q 'Installing Bun\|bun\.sh/install' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script installs Bun if missing"
else
    fail "Setup script should install Bun if missing"
fi

# Test: Setup script installs Go if missing
if grep -q 'Installing Go\|go\.dev/dl' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script installs Go if missing"
else
    fail "Setup script should install Go if missing"
fi

# Test: Setup script installs Go to user directory (no sudo required)
if grep -q '\.local/go\|HOME.*go' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script installs Go to user directory"
else
    fail "Setup script should install Go to user directory (no sudo required)"
fi

# Test: Setup script supports x86_64 architecture for Go
if grep -q 'x86_64.*amd64\|amd64' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script supports x86_64 architecture for Go"
else
    fail "Setup script should support x86_64 architecture for Go"
fi

# Test: Setup script supports arm64 architecture for Go
if grep -q 'aarch64.*arm64\|arm64' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script supports arm64 architecture for Go"
else
    fail "Setup script should support arm64 architecture for Go"
fi

# Test: Setup script installs jq if missing
if grep -q 'Installing jq\|apt.*jq\|apk.*jq' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script installs jq if missing"
else
    fail "Setup script should install jq if missing"
fi

# Test: Setup script handles apt-get for jq
if grep -q 'apt-get.*jq' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script handles apt-get for jq"
else
    fail "Setup script should handle apt-get for jq"
fi

# Test: Setup script handles apk for jq
if grep -q 'apk.*jq' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script handles apk for jq"
else
    fail "Setup script should handle apk for jq (Alpine)"
fi

# Test: Setup script handles dnf for jq
if grep -q 'dnf.*jq' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script handles dnf for jq"
else
    fail "Setup script should handle dnf for jq (Fedora/RHEL)"
fi

# Test: Setup script exports PATH for Bun
if grep -q 'BUN_INSTALL.*PATH\|PATH.*bun' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script exports PATH for Bun"
else
    fail "Setup script should export PATH for Bun"
fi

# Test: Setup script exports PATH for Go
if grep -q 'GO_INSTALL_DIR.*PATH\|PATH.*go.*bin' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script exports PATH for Go"
else
    fail "Setup script should export PATH for Go"
fi

# Test: Setup script handles dependency install failures gracefully
if grep -q 'Warning.*installation failed\|Warning.*install.*failed' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script handles dependency install failures gracefully"
else
    fail "Setup script should handle dependency install failures gracefully"
fi

# ============================================
# Setup Script Error Handling
# ============================================
echo ""
echo "--- Setup Script Error Handling ---"

# Test: Setup script checks relay connection before proceeding
if grep -q 'Cannot reach relay\|Relay connection' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script checks relay connection"
else
    fail "Setup script should check relay connection"
fi

# Test: Setup script exits on relay connection failure
if grep -q 'Cannot reach relay' "$PROJECT_ROOT/relay/main.ts" && grep -q 'exit 1' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script exits on relay connection failure"
else
    fail "Setup script should exit on relay connection failure"
fi

# Test: Setup script handles bundle download failure
if grep -q 'Bundle.*failed\|download.*failed\|extraction failed' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script handles bundle download failure"
else
    fail "Setup script should handle bundle download failure"
fi

# Test: Setup script provides manual recovery instructions
if grep -q 'Try running manually\|manually.*curl' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script provides manual recovery instructions"
else
    fail "Setup script should provide manual recovery instructions"
fi

# Test: Setup script uses pipefail for error detection
if grep -q 'pipefail' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script uses pipefail for error detection"
else
    fail "Setup script should use pipefail for error detection"
fi

# ============================================
# Config Generation in Setup Script
# ============================================
echo ""
echo "--- Config Generation in Setup Script ---"

# Test: Setup script creates config.json
if grep -q 'config\.json\|Creating.*config' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script creates config.json"
else
    fail "Setup script should create config.json"
fi

# Test: Setup script sets relay port in config
if grep -q '"port".*RELAY_PORT\|port.*\$RELAY_PORT' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script sets relay port in config"
else
    fail "Setup script should set relay port in config"
fi

# Test: Setup script sets relay.mode to client
if grep -q '"mode".*client\|mode.*client' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script sets relay.mode to client"
else
    fail "Setup script should set relay.mode to client"
fi

# Test: Setup script sets relay.enabled to true
if grep -q '"enabled".*true\|enabled.*true' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script sets relay.enabled to true"
else
    fail "Setup script should set relay.enabled to true"
fi

# Test: Setup script always overwrites config.json (fresh install)
if grep -q 'always overwrite\|Creating relay client config' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script always overwrites config.json for fresh install"
else
    fail "Setup script should always overwrite config.json for fresh install"
fi

# ============================================
# Existing OpenCode Installation Handling
# ============================================
echo ""
echo "--- Existing OpenCode Installation Handling ---"

# Test: Setup script checks for existing OpenCode config
if grep -q 'OPENCODE_CONFIG_DIR\|\.config/opencode' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script checks for existing OpenCode config"
else
    fail "Setup script should check for existing OpenCode config"
fi

# Test: Setup script checks for ~/.opencode alternative location
if grep -q 'OPENCODE_ALT_DIR\|\.opencode' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script checks for ~/.opencode alternative location"
else
    fail "Setup script should check for ~/.opencode alternative location"
fi

# Test: Setup script backs up existing OpenCode config
if grep -q 'backup\|Backup\|BACKUP' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script backs up existing OpenCode config"
else
    fail "Setup script should back up existing OpenCode config"
fi

# Test: Backup directory includes timestamp
if grep -q 'backup.*date\|date.*backup\|%Y%m%d\|+%Y' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Backup directory includes timestamp"
else
    fail "Backup directory should include timestamp"
fi

# Test: Setup script moves existing config to backup
if grep -q 'mv.*OPENCODE_CONFIG_DIR\|mv.*opencode.*backup' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script moves existing config to backup"
else
    fail "Setup script should move existing config to backup"
fi

# Test: Setup script informs user about backup
if grep -q 'Existing.*found\|Backing up' "$PROJECT_ROOT/relay/main.ts"; then
    pass "Setup script informs user about backup"
else
    fail "Setup script should inform user about backup"
fi

# ============================================
# Relay Mode Validation (validate.sh)
# ============================================
echo ""
echo "--- Relay Mode Validation (validate.sh) ---"

# Test: validate.sh checks for relay mode
if grep -q 'relay.*enabled\|relay\.enabled' "$PROJECT_ROOT/lib/validate.sh"; then
    pass "validate.sh checks for relay mode"
else
    fail "validate.sh should check for relay mode"
fi

# Test: validate.sh checks for relay client mode
if grep -q 'relay.*mode\|relay\.mode\|client' "$PROJECT_ROOT/lib/validate.sh"; then
    pass "validate.sh checks for relay client mode"
else
    fail "validate.sh should check for relay client mode"
fi

# Test: validate.sh skips API key check for relay client mode
if grep -q 'is_relay_client\|relay.*client.*API\|API.*key.*not required' "$PROJECT_ROOT/lib/validate.sh"; then
    pass "validate.sh skips API key check for relay client mode"
else
    fail "validate.sh should skip API key check for relay client mode"
fi

# Test: validate.sh logs that relay client mode detected
if grep -q 'Relay client mode\|relay.*mode.*detected' "$PROJECT_ROOT/lib/validate.sh"; then
    pass "validate.sh logs relay client mode detection"
else
    fail "validate.sh should log relay client mode detection"
fi

# Test: validate.sh still requires other fields in relay mode
REQUIRED_FIELDS=(".site_url" ".site_name" ".models.orchestrator" ".models.planner")
all_required_found=true
for field in "${REQUIRED_FIELDS[@]}"; do
    if ! grep -q "$field" "$PROJECT_ROOT/lib/validate.sh"; then
        all_required_found=false
    fi
done
if [[ "$all_required_found" == "true" ]]; then
    pass "validate.sh still requires site_url, site_name, and model fields"
else
    fail "validate.sh should still require site_url, site_name, and model fields"
fi

# Test: validate.sh handles empty API key for relay client mode
if grep -q 'is_relay_client.*false\|API key is required' "$PROJECT_ROOT/lib/validate.sh"; then
    pass "validate.sh handles empty API key appropriately per mode"
else
    fail "validate.sh should handle empty API key appropriately per mode"
fi

# ============================================
# .dockerignore Verification
# ============================================
echo ""
echo "--- .dockerignore Verification ---"

# Test: .dockerignore excludes .git
if grep -q '^\.git$\|^\.git/' "$PROJECT_ROOT/.dockerignore"; then
    pass ".dockerignore excludes .git"
else
    fail ".dockerignore should exclude .git"
fi

# Test: .dockerignore excludes config.json
if grep -q 'config\.json' "$PROJECT_ROOT/.dockerignore"; then
    pass ".dockerignore excludes config.json"
else
    fail ".dockerignore should exclude config.json"
fi

# Test: .dockerignore excludes tests
if grep -q 'tests' "$PROJECT_ROOT/.dockerignore"; then
    pass ".dockerignore excludes tests directory"
else
    fail ".dockerignore should exclude tests directory"
fi

# ============================================
# Bundle Contents Static Verification
# ============================================
echo ""
echo "--- Bundle Contents Static Verification ---"

# Test: install.sh exists in repo
if [[ -f "$PROJECT_ROOT/install.sh" ]]; then
    pass "install.sh exists in repo"
else
    fail "install.sh should exist in repo"
fi

# Test: install.sh is executable
if [[ -x "$PROJECT_ROOT/install.sh" ]]; then
    pass "install.sh is executable"
else
    fail "install.sh should be executable"
fi

# Test: lib directory exists
if [[ -d "$PROJECT_ROOT/lib" ]]; then
    pass "lib directory exists in repo"
else
    fail "lib directory should exist in repo"
fi

# Test: relay directory exists
if [[ -d "$PROJECT_ROOT/relay" ]]; then
    pass "relay directory exists in repo"
else
    fail "relay directory should exist in repo"
fi

# Test: templates directory exists
if [[ -d "$PROJECT_ROOT/templates" ]]; then
    pass "templates directory exists in repo"
else
    fail "templates directory should exist in repo"
fi

# Test: vendor directory exists
if [[ -d "$PROJECT_ROOT/vendor" ]]; then
    pass "vendor directory exists in repo"
else
    fail "vendor directory should exist in repo"
fi

# Test: vendor/opencode exists or is submodule placeholder
if [[ -d "$PROJECT_ROOT/vendor/opencode" ]] || [[ -f "$PROJECT_ROOT/.gitmodules" ]]; then
    pass "vendor/opencode exists or defined in .gitmodules"
else
    fail "vendor/opencode should exist or be defined in .gitmodules"
fi

# Test: vendor/oh-my-opencode exists or is submodule placeholder
if [[ -d "$PROJECT_ROOT/vendor/oh-my-opencode" ]] || [[ -f "$PROJECT_ROOT/.gitmodules" ]]; then
    pass "vendor/oh-my-opencode exists or defined in .gitmodules"
else
    fail "vendor/oh-my-opencode should exist or be defined in .gitmodules"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "=== Results ==="
echo "Total: $TESTS_RUN | Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
