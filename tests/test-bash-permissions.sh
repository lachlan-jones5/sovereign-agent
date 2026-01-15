#!/usr/bin/env bash
# test-bash-permissions.sh - Tests for granular bash permissions functionality
#
# Tests that bash permissions are properly configured in templates and config

# Don't use set -e as we want to run all tests even if some fail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$PROJECT_DIR/lib"
TEMPLATES_DIR="$PROJECT_DIR/templates"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Temp directory for test outputs
TEST_TMP=""

setup() {
    TEST_TMP=$(mktemp -d)
    mkdir -p "$TEST_TMP/config"
}

teardown() {
    if [[ -n "$TEST_TMP" && -d "$TEST_TMP" ]]; then
        rm -rf "$TEST_TMP"
    fi
}

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

# Create test config with bash permissions
create_test_config() {
    cat > "$TEST_TMP/config.json" << 'EOF'
{
  "github_oauth_token": "test-token",
  "site_url": "https://test.local",
  "site_name": "Test",
  "preferences": {
    "ultrawork_max_iterations": 50,
    "dcp_turn_protection": 2,
    "dcp_error_retention_turns": 4,
    "dcp_nudge_frequency": 10
  },
  "security": {
    "provider_whitelist": ["DeepInfra"],
    "max_tokens": {
      "orchestrator": 32000,
      "planner": 16000,
      "librarian": 64000
    }
  },
  "plugins": {
    "opencode_dcp_version": "1.2.1",
    "pin_versions": true
  },
  "tool_permissions": {
    "bash": {
      "mode": "blocklist",
      "allowed_commands": ["ls", "cat", "grep"],
      "blocked_commands": ["rm -rf /", "mkfs", "dd"],
      "blocked_patterns": ["curl.*|.*sh", "wget.*|.*bash"]
    }
  }
}
EOF
}

echo "========================================="
echo "Bash Permissions Tests"
echo "========================================="
echo

setup

# Test 1: Template has bash permission mode placeholder
if grep -q '{{BASH_PERMISSION_MODE}}' "$TEMPLATES_DIR/oh-my-opencode.json.tmpl"; then
    pass "Template has {{BASH_PERMISSION_MODE}} placeholder"
else
    fail "Template missing {{BASH_PERMISSION_MODE}} placeholder"
fi

# Test 2: Template has allowed commands placeholder
if grep -q '{{BASH_ALLOWED_COMMANDS}}' "$TEMPLATES_DIR/oh-my-opencode.json.tmpl"; then
    pass "Template has {{BASH_ALLOWED_COMMANDS}} placeholder"
else
    fail "Template missing {{BASH_ALLOWED_COMMANDS}} placeholder"
fi

# Test 3: Template has blocked commands placeholder
if grep -q '{{BASH_BLOCKED_COMMANDS}}' "$TEMPLATES_DIR/oh-my-opencode.json.tmpl"; then
    pass "Template has {{BASH_BLOCKED_COMMANDS}} placeholder"
else
    fail "Template missing {{BASH_BLOCKED_COMMANDS}} placeholder"
fi

# Test 4: Template has blocked patterns placeholder
if grep -q '{{BASH_BLOCKED_PATTERNS}}' "$TEMPLATES_DIR/oh-my-opencode.json.tmpl"; then
    pass "Template has {{BASH_BLOCKED_PATTERNS}} placeholder"
else
    fail "Template missing {{BASH_BLOCKED_PATTERNS}} placeholder"
fi

# Test 5: config.json.example has tool_permissions section
if grep -q '"tool_permissions"' "$PROJECT_DIR/config.json.example"; then
    pass "config.json.example has tool_permissions section"
else
    fail "config.json.example missing tool_permissions section"
fi

# Test 6: config.json.example has bash permissions
if grep -q '"bash"' "$PROJECT_DIR/config.json.example"; then
    pass "config.json.example has bash permissions"
else
    fail "config.json.example missing bash permissions"
fi

# Test 7: config.json.example blocks rm -rf /
if grep -q 'rm -rf /' "$PROJECT_DIR/config.json.example"; then
    pass "config.json.example blocks 'rm -rf /'"
else
    fail "config.json.example does not block 'rm -rf /'"
fi

# Test 8: config.json.example blocks fork bomb
if grep -q ':(){ :|:& };:' "$PROJECT_DIR/config.json.example"; then
    pass "config.json.example blocks fork bomb"
else
    fail "config.json.example does not block fork bomb"
fi

# Test 9: generate-configs.sh handles bash permission mode
if grep -q 'bash_permission_mode' "$LIB_DIR/generate-configs.sh"; then
    pass "generate-configs.sh handles bash_permission_mode"
else
    fail "generate-configs.sh missing bash_permission_mode handling"
fi

# Test 10: generate-configs.sh handles blocked commands
if grep -q 'bash_blocked_commands' "$LIB_DIR/generate-configs.sh"; then
    pass "generate-configs.sh handles bash_blocked_commands"
else
    fail "generate-configs.sh missing bash_blocked_commands handling"
fi

# Test 11: generate-configs.sh handles blocked patterns
if grep -q 'bash_blocked_patterns' "$LIB_DIR/generate-configs.sh"; then
    pass "generate-configs.sh handles bash_blocked_patterns"
else
    fail "generate-configs.sh missing bash_blocked_patterns handling"
fi

# Test 12: Template has tool_permissions section
if grep -q '"tool_permissions"' "$TEMPLATES_DIR/oh-my-opencode.json.tmpl"; then
    pass "Template has tool_permissions section"
else
    fail "Template missing tool_permissions section"
fi

# Test 13: Default mode is blocklist (not allowlist - less restrictive default)
if grep -q "blocklist" "$LIB_DIR/generate-configs.sh"; then
    pass "Default permission mode is blocklist"
else
    fail "Default permission mode is not blocklist"
fi

# Test 14: Test config generation includes bash permissions
create_test_config
source "$LIB_DIR/generate-configs.sh"
generate_all_configs "$TEST_TMP/config.json" "$TEST_TMP/config" > /dev/null 2>&1

if grep -q '"tool_permissions"' "$TEST_TMP/config/oh-my-opencode.json"; then
    pass "Generated config includes tool_permissions"
else
    fail "Generated config missing tool_permissions"
fi

teardown

echo
echo "========================================="
echo "Bash Permissions Test Results"
echo "========================================="
echo -e "Total: $TESTS_RUN | ${GREEN}Passed: $TESTS_PASSED${NC} | ${RED}Failed: $TESTS_FAILED${NC}"
echo

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
