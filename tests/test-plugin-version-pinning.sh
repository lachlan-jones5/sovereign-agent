#!/usr/bin/env bash
# test-plugin-version-pinning.sh - Tests for plugin version pinning functionality
#
# Tests that plugin versions are properly configured in templates and config

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

# Create test config with version pinning
create_pinned_config() {
    cat > "$TEST_TMP/config-pinned.json" << 'EOF'
{
  "openrouter_api_key": "test-key",
  "site_url": "https://test.local",
  "site_name": "Test",
  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  },
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
    "opencode_dcp_version": "0.5.0",
    "oh_my_opencode_version": "1.0.0",
    "pin_versions": true
  },
  "tool_permissions": {
    "bash": {
      "mode": "blocklist",
      "allowed_commands": [],
      "blocked_commands": ["rm -rf /"],
      "blocked_patterns": []
    }
  }
}
EOF
}

# Create test config without version pinning
create_unpinned_config() {
    cat > "$TEST_TMP/config-unpinned.json" << 'EOF'
{
  "openrouter_api_key": "test-key",
  "site_url": "https://test.local",
  "site_name": "Test",
  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  },
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
    "opencode_dcp_version": "0.5.0",
    "oh_my_opencode_version": "1.0.0",
    "pin_versions": false
  },
  "tool_permissions": {
    "bash": {
      "mode": "blocklist",
      "allowed_commands": [],
      "blocked_commands": ["rm -rf /"],
      "blocked_patterns": []
    }
  }
}
EOF
}

echo "========================================="
echo "Plugin Version Pinning Tests"
echo "========================================="
echo

setup

# Test 1: Template has version placeholder for DCP
if grep -q '{{DCP_VERSION}}' "$TEMPLATES_DIR/opencode.json.tmpl"; then
    pass "Template has {{DCP_VERSION}} placeholder"
else
    fail "Template missing {{DCP_VERSION}} placeholder"
fi

# Test 2: Template has version placeholder for oh-my-opencode
if grep -q '{{OH_MY_OPENCODE_VERSION}}' "$TEMPLATES_DIR/opencode.json.tmpl"; then
    pass "Template has {{OH_MY_OPENCODE_VERSION}} placeholder"
else
    fail "Template missing {{OH_MY_OPENCODE_VERSION}} placeholder"
fi

# Test 3: config.json.example has plugins section
if grep -q '"plugins"' "$PROJECT_DIR/config.json.example"; then
    pass "config.json.example has plugins section"
else
    fail "config.json.example missing plugins section"
fi

# Test 4: config.json.example has pin_versions option
if grep -q '"pin_versions"' "$PROJECT_DIR/config.json.example"; then
    pass "config.json.example has pin_versions option"
else
    fail "config.json.example missing pin_versions option"
fi

# Test 5: config.json.example has DCP version
if grep -q '"opencode_dcp_version"' "$PROJECT_DIR/config.json.example"; then
    pass "config.json.example has opencode_dcp_version"
else
    fail "config.json.example missing opencode_dcp_version"
fi

# Test 6: config.json.example has oh-my-opencode version
if grep -q '"oh_my_opencode_version"' "$PROJECT_DIR/config.json.example"; then
    pass "config.json.example has oh_my_opencode_version"
else
    fail "config.json.example missing oh_my_opencode_version"
fi

# Test 7: generate-configs.sh handles DCP version
if grep -q 'dcp_version' "$LIB_DIR/generate-configs.sh"; then
    pass "generate-configs.sh handles dcp_version"
else
    fail "generate-configs.sh missing dcp_version handling"
fi

# Test 8: generate-configs.sh handles oh-my-opencode version
if grep -q 'oh_my_opencode_version' "$LIB_DIR/generate-configs.sh"; then
    pass "generate-configs.sh handles oh_my_opencode_version"
else
    fail "generate-configs.sh missing oh_my_opencode_version handling"
fi

# Test 9: generate-configs.sh respects pin_versions flag
if grep -q 'pin_versions' "$LIB_DIR/generate-configs.sh"; then
    pass "generate-configs.sh respects pin_versions flag"
else
    fail "generate-configs.sh missing pin_versions flag handling"
fi

# Test 10: Test config generation with pinned versions
create_pinned_config
source "$LIB_DIR/generate-configs.sh"
generate_all_configs "$TEST_TMP/config-pinned.json" "$TEST_TMP/config" > /dev/null 2>&1

if grep -q '@0.5.0' "$TEST_TMP/config/opencode.json"; then
    pass "Pinned config generates versioned DCP plugin"
else
    fail "Pinned config does not generate versioned DCP plugin"
fi

# Test 11: Test pinned oh-my-opencode version in generated config
if grep -q 'oh-my-opencode@1.0.0' "$TEST_TMP/config/opencode.json"; then
    pass "Pinned config generates versioned oh-my-opencode plugin"
else
    fail "Pinned config does not generate versioned oh-my-opencode plugin"
fi

# Test 12: Test config generation with unpinned versions
create_unpinned_config
# Need to re-source to clear old values, run in subshell
(
    source "$LIB_DIR/generate-configs.sh"
    generate_all_configs "$TEST_TMP/config-unpinned.json" "$TEST_TMP/config" > /dev/null 2>&1
)

if grep -q '@latest' "$TEST_TMP/config/opencode.json"; then
    pass "Unpinned config generates @latest plugins"
else
    fail "Unpinned config does not generate @latest plugins"
fi

# Test 13: Default pin_versions should be true (secure by default)
if grep -q 'pin_versions.*true' "$LIB_DIR/generate-configs.sh" || \
   grep -q "pin_versions' 'true'" "$LIB_DIR/generate-configs.sh"; then
    pass "Default pin_versions is true (secure by default)"
else
    fail "Default pin_versions is not true"
fi

# Test 14: Template no longer uses @latest directly
if ! grep -q '@latest' "$TEMPLATES_DIR/opencode.json.tmpl"; then
    pass "Template does not hardcode @latest"
else
    fail "Template still hardcodes @latest"
fi

teardown

echo
echo "========================================="
echo "Plugin Version Pinning Test Results"
echo "========================================="
echo -e "Total: $TESTS_RUN | ${GREEN}Passed: $TESTS_PASSED${NC} | ${RED}Failed: $TESTS_FAILED${NC}"
echo

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
