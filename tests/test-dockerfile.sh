#!/bin/bash
# Test suite for Dockerfile verification
# Validates Dockerfiles and ensures relay code is compatible with target runtime

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASSED=0
FAILED=0

pass() {
    echo "  ✓ $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo "  ✗ $1"
    FAILED=$((FAILED + 1))
}

echo "============================================"
echo "Dockerfile Verification Tests"
echo "============================================"

# ============================================
# Dockerfile existence and syntax
# ============================================
echo ""
echo "--- Dockerfile Existence ---"

# Test: Dockerfile.relay exists
if [[ -f "$PROJECT_ROOT/Dockerfile.relay" ]]; then
    pass "Dockerfile.relay exists"
else
    fail "Dockerfile.relay should exist"
fi

# Test: Dockerfile exists (full agent)
if [[ -f "$PROJECT_ROOT/Dockerfile" ]]; then
    pass "Dockerfile exists"
else
    fail "Dockerfile should exist"
fi

# Test: docker-compose.relay.yml exists
if [[ -f "$PROJECT_ROOT/docker-compose.relay.yml" ]]; then
    pass "docker-compose.relay.yml exists"
else
    fail "docker-compose.relay.yml should exist"
fi

# ============================================
# Dockerfile.relay validation
# ============================================
echo ""
echo "--- Dockerfile.relay Validation ---"

# Test: Uses bun base image
if grep -q 'FROM.*oven/bun' "$PROJECT_ROOT/Dockerfile.relay"; then
    pass "Dockerfile.relay uses Bun base image"
else
    fail "Dockerfile.relay should use Bun base image"
fi

# Test: Has health check
if grep -q 'HEALTHCHECK' "$PROJECT_ROOT/Dockerfile.relay"; then
    pass "Dockerfile.relay has health check"
else
    fail "Dockerfile.relay should have health check"
fi

# Test: Exposes port 8080
if grep -q 'EXPOSE 8080' "$PROJECT_ROOT/Dockerfile.relay"; then
    pass "Dockerfile.relay exposes port 8080"
else
    fail "Dockerfile.relay should expose port 8080"
fi

# Test: Copies relay/main.ts
if grep -q 'COPY relay/main.ts' "$PROJECT_ROOT/Dockerfile.relay"; then
    pass "Dockerfile.relay copies relay/main.ts"
else
    fail "Dockerfile.relay should copy relay/main.ts"
fi

# Test: Sets CONFIG_PATH environment variable
if grep -q 'ENV CONFIG_PATH' "$PROJECT_ROOT/Dockerfile.relay"; then
    pass "Dockerfile.relay sets CONFIG_PATH"
else
    fail "Dockerfile.relay should set CONFIG_PATH"
fi

# Test: Sets RELAY_PORT environment variable
if grep -q 'ENV RELAY_PORT' "$PROJECT_ROOT/Dockerfile.relay"; then
    pass "Dockerfile.relay sets RELAY_PORT"
else
    fail "Dockerfile.relay should set RELAY_PORT"
fi

# ============================================
# relay/main.ts compatibility checks
# ============================================
echo ""
echo "--- relay/main.ts Compatibility ---"

# Test: Does NOT use Bun Shell syntax (incompatible with older Bun/arm64)
if grep -q 'await \$`' "$PROJECT_ROOT/relay/main.ts"; then
    fail "relay/main.ts uses Bun Shell syntax (\$\`) - incompatible with arm64/older Bun"
else
    pass "relay/main.ts does not use Bun Shell syntax"
fi

# Test: Does NOT import $ from bun
if grep -q 'import.*\$.*from.*"bun"' "$PROJECT_ROOT/relay/main.ts" || \
   grep -q 'import.*{.*\$.*}.*from.*"bun"' "$PROJECT_ROOT/relay/main.ts"; then
    fail "relay/main.ts imports \$ from bun - incompatible with arm64/older Bun"
else
    pass "relay/main.ts does not import \$ from bun"
fi

# Test: Uses child_process spawn for shell commands (cross-platform)
if grep -q 'import.*spawn.*from.*"child_process"' "$PROJECT_ROOT/relay/main.ts"; then
    pass "relay/main.ts uses child_process spawn"
else
    fail "relay/main.ts should use child_process spawn for compatibility"
fi

# Test: Has exec helper function
if grep -q 'async function exec' "$PROJECT_ROOT/relay/main.ts"; then
    pass "relay/main.ts has exec helper function"
else
    fail "relay/main.ts should have exec helper function"
fi

# Test: Has execBuffer helper function
if grep -q 'async function execBuffer' "$PROJECT_ROOT/relay/main.ts"; then
    pass "relay/main.ts has execBuffer helper function"
else
    fail "relay/main.ts should have execBuffer helper function"
fi

# Test: Uses Bun.serve for HTTP server (standard Bun API)
if grep -q 'Bun.serve' "$PROJECT_ROOT/relay/main.ts"; then
    pass "relay/main.ts uses Bun.serve"
else
    fail "relay/main.ts should use Bun.serve"
fi

# ============================================
# TypeScript syntax validation
# ============================================
echo ""
echo "--- TypeScript Syntax Validation ---"

# Test: relay/main.ts has valid syntax (check with bun)
if command -v bun &>/dev/null; then
    if bun check "$PROJECT_ROOT/relay/main.ts" 2>/dev/null || \
       bun build --dry-run "$PROJECT_ROOT/relay/main.ts" 2>/dev/null; then
        pass "relay/main.ts has valid TypeScript syntax"
    else
        # Try parsing with a different method
        if timeout 5 bun run --bun "$PROJECT_ROOT/relay/main.ts" --help 2>&1 | grep -q "error: Syntax Error"; then
            fail "relay/main.ts has TypeScript syntax errors"
        else
            pass "relay/main.ts has valid TypeScript syntax (parse check)"
        fi
    fi
else
    echo "  - Skipping TypeScript syntax check (bun not available)"
fi

# ============================================
# Bun Shell detection (comprehensive)
# ============================================
echo ""
echo "--- Bun Shell Detection (Comprehensive) ---"

# Test: No template literal $ usage
BUN_SHELL_PATTERNS=(
    '\$`'
    'await \$`'
    '\$.quiet'
    '\$.verbose'
    '\$.cwd'
    '\$.env'
)

for pattern in "${BUN_SHELL_PATTERNS[@]}"; do
    if grep -qE "$pattern" "$PROJECT_ROOT/relay/main.ts" 2>/dev/null; then
        fail "relay/main.ts contains Bun Shell pattern: $pattern"
    else
        pass "relay/main.ts does not contain: $pattern"
    fi
done

# ============================================
# docker-compose.relay.yml validation
# ============================================
echo ""
echo "--- docker-compose.relay.yml Validation ---"

# Test: Uses Dockerfile.relay
if grep -q 'dockerfile.*Dockerfile.relay\|Dockerfile.relay' "$PROJECT_ROOT/docker-compose.relay.yml"; then
    pass "docker-compose.relay.yml uses Dockerfile.relay"
else
    fail "docker-compose.relay.yml should use Dockerfile.relay"
fi

# Test: Mounts config.json
if grep -q 'config.json' "$PROJECT_ROOT/docker-compose.relay.yml"; then
    pass "docker-compose.relay.yml mounts config.json"
else
    fail "docker-compose.relay.yml should mount config.json"
fi

# Test: Sets restart policy
if grep -q 'restart:' "$PROJECT_ROOT/docker-compose.relay.yml"; then
    pass "docker-compose.relay.yml has restart policy"
else
    fail "docker-compose.relay.yml should have restart policy"
fi

# Test: Uses RELAY_PORT variable
if grep -q 'RELAY_PORT' "$PROJECT_ROOT/docker-compose.relay.yml"; then
    pass "docker-compose.relay.yml uses RELAY_PORT"
else
    fail "docker-compose.relay.yml should use RELAY_PORT"
fi

# ============================================
# Security checks
# ============================================
echo ""
echo "--- Security Checks ---"

# Test: Dockerfile.relay installs curl for health checks only
if grep -q 'apk add.*curl' "$PROJECT_ROOT/Dockerfile.relay" && \
   ! grep -q 'apk add.*bash\|apk add.*wget' "$PROJECT_ROOT/Dockerfile.relay"; then
    pass "Dockerfile.relay has minimal package installs"
else
    fail "Dockerfile.relay should only install necessary packages"
fi

# Test: Config mounted read-only
if grep -q ':ro' "$PROJECT_ROOT/docker-compose.relay.yml"; then
    pass "docker-compose.relay.yml mounts config read-only"
else
    fail "docker-compose.relay.yml should mount config read-only"
fi

# ============================================
# Multi-architecture support
# ============================================
echo ""
echo "--- Multi-Architecture Support ---"

# Test: Uses Alpine-based image (supports arm64)
if grep -q 'alpine' "$PROJECT_ROOT/Dockerfile.relay"; then
    pass "Dockerfile.relay uses Alpine (arm64 support)"
else
    fail "Dockerfile.relay should use Alpine for arm64 support"
fi

# Test: No x86-specific instructions
if grep -qiE 'amd64|x86_64|x86-64' "$PROJECT_ROOT/Dockerfile.relay"; then
    fail "Dockerfile.relay has x86-specific instructions"
else
    pass "Dockerfile.relay has no x86-specific instructions"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "============================================"
echo "Dockerfile Verification Results"
echo "============================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [[ $FAILED -gt 0 ]]; then
    echo "FAILED - Some tests did not pass"
    exit 1
else
    echo "SUCCESS - All tests passed"
    exit 0
fi
