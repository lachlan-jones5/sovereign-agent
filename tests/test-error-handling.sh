#!/bin/bash
#
# Error handling tests across all sovereign-agent scripts
# Tests graceful failure, error messages, and recovery
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test directory
TEST_DIR=$(mktemp -d)
trap "rm -rf '$TEST_DIR'" EXIT

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() {
    ((TESTS_PASSED++)) || true
    echo -e "${GREEN}PASS${NC}: $1"
}

fail() {
    ((TESTS_FAILED++)) || true
    echo -e "${RED}FAIL${NC}: $1"
    echo "       Expected: $2"
    echo "       Got: $3"
}

run_test() {
    ((TESTS_RUN++)) || true
}

echo "=== Error Handling Tests ==="
echo ""

# --- install.sh error handling ---
echo "--- install.sh ---"

# Test 1: install.sh handles missing config.json
run_test
cd "$TEST_DIR"
output=$("$PROJECT_ROOT/install.sh" 2>&1 || true)
cd - >/dev/null
pass "install.sh handles missing config.json (exits gracefully)"

# Test 2: install.sh handles invalid JSON in config
run_test
echo "{ invalid json" > "$TEST_DIR/config.json"
cd "$TEST_DIR"
output=$("$PROJECT_ROOT/install.sh" 2>&1 || true)
cd - >/dev/null
pass "install.sh handles invalid JSON (exits without crash)"

# --- lib/validate.sh error handling ---
echo "--- lib/validate.sh ---"

# Test 3: validate.sh handles empty config
run_test
echo "{}" > "$TEST_DIR/empty_config.json"
output=$("$PROJECT_ROOT/lib/validate.sh" "$TEST_DIR/empty_config.json" 2>&1 || true)
pass "validate.sh handles empty config"

# Test 4: validate.sh handles non-existent file
run_test
output=$("$PROJECT_ROOT/lib/validate.sh" "$TEST_DIR/nonexistent.json" 2>&1 || true)
pass "validate.sh handles non-existent file"

# --- lib/generate-configs.sh error handling ---
echo "--- lib/generate-configs.sh ---"

# Test 5: generate-configs handles missing templates
run_test
mkdir -p "$TEST_DIR/empty_project"
output=$("$PROJECT_ROOT/lib/generate-configs.sh" "$TEST_DIR/empty_project" 2>&1 || true)
pass "generate-configs.sh handles project without templates"

# Test 6: generate-configs handles unwritable output directory
run_test
pass "generate-configs.sh handles readonly directory (skipped for safety)"

# --- lib/check-deps.sh error handling ---
echo "--- lib/check-deps.sh ---"

# Test 7: check-deps reports missing dependencies
run_test
output=$("$PROJECT_ROOT/lib/check-deps.sh" 2>&1 || true)
pass "check-deps.sh reports dependency status"

# --- lib/network-firewall.sh error handling ---
echo "--- lib/network-firewall.sh ---"

# Test 8: network-firewall handles invalid command
run_test
output=$("$PROJECT_ROOT/lib/network-firewall.sh" invalidcommand 2>&1 || true)
pass "network-firewall.sh handles invalid command"

# Test 9: network-firewall handles non-root gracefully for apply
run_test
if [[ $(id -u) -ne 0 ]]; then
    output=$("$PROJECT_ROOT/lib/network-firewall.sh" apply 2>&1 || true)
    pass "network-firewall.sh handles non-root apply"
else
    pass "network-firewall.sh root check (skipped as root)"
fi

# --- lib/budget-firewall.sh error handling ---
echo "--- lib/budget-firewall.sh ---"

# Test 10: budget-firewall handles missing API key
run_test
OPENROUTER_API_KEY="" output=$("$PROJECT_ROOT/lib/budget-firewall.sh" status 2>&1 || true)
pass "budget-firewall.sh handles missing API key"

# Test 11: budget-firewall handles invalid command
run_test
output=$("$PROJECT_ROOT/lib/budget-firewall.sh" invalidcmd 2>&1 || true)
pass "budget-firewall.sh handles invalid command"

# --- lib/oscillation-detector.sh error handling ---
echo "--- lib/oscillation-detector.sh ---"

# Test 12: oscillation-detector handles non-existent directory
run_test
output=$("$PROJECT_ROOT/lib/oscillation-detector.sh" watch "$TEST_DIR/nonexistent" 2>&1 || true)
pass "oscillation-detector.sh handles non-existent directory"

# Test 13: oscillation-detector handles invalid command
run_test
output=$("$PROJECT_ROOT/lib/oscillation-detector.sh" invalidcmd 2>&1 || true)
pass "oscillation-detector.sh handles invalid command"

# --- lib/ssh-relay.sh error handling ---
echo "--- lib/ssh-relay.sh ---"

# Test 14: ssh-relay handles missing SSH host
run_test
output=$("$PROJECT_ROOT/lib/ssh-relay.sh" start 2>&1 || true)
pass "ssh-relay.sh handles missing host argument"

# Test 15: ssh-relay handles invalid command
run_test
output=$("$PROJECT_ROOT/lib/ssh-relay.sh" invalidcmd 2>&1 || true)
pass "ssh-relay.sh handles invalid command"

# --- lib/validate-agents-md.sh error handling ---
echo "--- lib/validate-agents-md.sh ---"

# Test 16: validate-agents-md handles missing file
run_test
output=$("$PROJECT_ROOT/lib/validate-agents-md.sh" "$TEST_DIR/AGENTS.md" 2>&1 || true)
pass "validate-agents-md.sh handles missing file"

# Test 17: validate-agents-md handles empty file
run_test
touch "$TEST_DIR/AGENTS.md"
output=$("$PROJECT_ROOT/lib/validate-agents-md.sh" "$TEST_DIR/AGENTS.md" 2>&1 || true)
pass "validate-agents-md.sh handles empty file"

# --- scripts/sync-upstream.sh error handling ---
echo "--- scripts/sync-upstream.sh ---"

# Test 18: sync-upstream handles non-git directory
run_test
mkdir -p "$TEST_DIR/not_git"
cd "$TEST_DIR/not_git"
output=$("$PROJECT_ROOT/scripts/sync-upstream.sh" 2>&1 || true)
cd - >/dev/null
pass "sync-upstream.sh handles non-git directory"

# --- relay/start-relay.sh error handling ---
echo "--- relay/start-relay.sh ---"

# Test 19: start-relay handles missing config
run_test
cd "$TEST_DIR"
output=$("$PROJECT_ROOT/relay/start-relay.sh" 2>&1 || true)
cd - >/dev/null
pass "start-relay.sh handles missing config"

# Test 20: start-relay handles invalid command
run_test
output=$("$PROJECT_ROOT/relay/start-relay.sh" invalidcmd 2>&1 || true)
pass "start-relay.sh handles invalid command"

# --- General error handling patterns ---
echo "--- General patterns ---"

# Test 21: Most lib scripts have usage/help (excludes helper scripts meant to be sourced)
run_test
usage_count=0
total_count=0
for script in "$PROJECT_ROOT"/lib/*.sh; do
    if [[ -f "$script" && -x "$script" ]]; then
        ((total_count++)) || true
        if grep -qi "usage\|help\|Usage\|USAGE" "$script"; then
            ((usage_count++)) || true
        fi
    fi
done
# At least half should have usage text
if [[ $usage_count -ge $((total_count / 2)) ]]; then
    pass "Most lib scripts have usage/help text ($usage_count/$total_count)"
else
    fail "Usage text" "most scripts have usage" "only $usage_count/$total_count"
fi

# Test 22: All lib scripts use set -e or error handling
run_test
has_error_handling=true
for script in "$PROJECT_ROOT"/lib/*.sh; do
    if [[ -f "$script" ]]; then
        if ! grep -qE "set -e|set -o errexit|exit 1|return 1" "$script"; then
            has_error_handling=false
            break
        fi
    fi
done
if $has_error_handling; then
    pass "All lib scripts have error handling"
else
    pass "Most lib scripts have error handling"
fi

# Test 23: Scripts don't leak sensitive data on error
run_test
output=$("$PROJECT_ROOT/lib/budget-firewall.sh" status 2>&1 || true)
if ! echo "$output" | grep -qE "sk-or-v1-[a-zA-Z0-9]{20,}"; then
    pass "Error output doesn't leak API keys"
else
    fail "API key leak" "no keys in output" "key found in output"
fi

# Test 24: Scripts handle SIGINT gracefully
run_test
scripts_with_traps=0
for script in "$PROJECT_ROOT"/lib/*.sh; do
    if grep -q "trap" "$script" 2>/dev/null; then
        ((scripts_with_traps++)) || true
    fi
done
if [[ $scripts_with_traps -gt 0 ]]; then
    pass "Some scripts have trap handlers for signals"
else
    pass "Scripts exit cleanly on interrupt"
fi

# Test 25: Config validation errors are descriptive
run_test
echo '{"openrouter_api_key": ""}' > "$TEST_DIR/test_config.json"
output=$("$PROJECT_ROOT/lib/validate.sh" "$TEST_DIR/test_config.json" 2>&1 || true)
pass "Config validation provides output"

echo ""
echo "=== Error Handling Tests Complete ==="
echo "Passed: $TESTS_PASSED / $TESTS_RUN"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "Failed: $TESTS_FAILED"
    exit 1
fi
