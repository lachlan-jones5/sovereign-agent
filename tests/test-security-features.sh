#!/usr/bin/env bash
# test-security-features.sh - Test security hardening features
# Usage: ./tests/test-security-features.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$PROJECT_DIR/lib"
TEMPLATES_DIR="$PROJECT_DIR/templates"
TEST_TMP_DIR=$(mktemp -d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

cleanup() {
    rm -rf "$TEST_TMP_DIR"
}
trap cleanup EXIT

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    echo "  Expected: $2"
    echo "  Got: $3"
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

# Create a test config with security settings
create_security_test_config() {
    cat > "$TEST_TMP_DIR/config.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://test.example.com",
  "site_name": "TestSite",
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
    "provider_whitelist": ["DeepInfra", "Fireworks"],
    "max_tokens": {
      "orchestrator": 16000,
      "planner": 8000,
      "librarian": 32000
    }
  }
}
EOF
}

# Source the generate script
source "$LIB_DIR/generate-configs.sh"

# =============================================================================
# Provider Whitelist Tests
# =============================================================================

test_provider_whitelist_in_config() {
    local name="opencode.json contains provider whitelist"
    create_security_test_config
    local output_dir="$TEST_TMP_DIR/output1"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    local whitelist
    whitelist=$(jq -r '.provider.openrouter.options.provider.order | join(",")' "$output_dir/opencode.json")
    
    if [[ "$whitelist" == "DeepInfra,Fireworks" ]]; then
        pass "$name"
    else
        fail "$name" "DeepInfra,Fireworks" "$whitelist"
    fi
}

test_allow_fallbacks_disabled() {
    local name="opencode.json has allow_fallbacks set to false"
    create_security_test_config
    local output_dir="$TEST_TMP_DIR/output2"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    local fallbacks
    fallbacks=$(jq -r '.provider.openrouter.options.provider.allow_fallbacks' "$output_dir/opencode.json")
    
    if [[ "$fallbacks" == "false" ]]; then
        pass "$name"
    else
        fail "$name" "false" "$fallbacks"
    fi
}

test_zdr_enabled() {
    local name="opencode.json has ZDR enabled"
    create_security_test_config
    local output_dir="$TEST_TMP_DIR/output3"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    local zdr
    zdr=$(jq -r '.provider.openrouter.options.zdr' "$output_dir/opencode.json")
    
    if [[ "$zdr" == "true" ]]; then
        pass "$name"
    else
        fail "$name" "true" "$zdr"
    fi
}

# =============================================================================
# Max Tokens Tests
# =============================================================================

test_orchestrator_max_tokens() {
    local name="opencode.json contains orchestrator max_tokens"
    create_security_test_config
    local output_dir="$TEST_TMP_DIR/output4"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    local max_tokens
    max_tokens=$(jq -r '.model_config["openrouter/deepseek/deepseek-v3"].max_tokens' "$output_dir/opencode.json")
    
    if [[ "$max_tokens" == "16000" ]]; then
        pass "$name"
    else
        fail "$name" "16000" "$max_tokens"
    fi
}

test_planner_max_tokens() {
    local name="opencode.json contains planner max_tokens"
    create_security_test_config
    local output_dir="$TEST_TMP_DIR/output5"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    local max_tokens
    max_tokens=$(jq -r '.model_config["openrouter/anthropic/claude-opus-4.5"].max_tokens' "$output_dir/opencode.json")
    
    if [[ "$max_tokens" == "8000" ]]; then
        pass "$name"
    else
        fail "$name" "8000" "$max_tokens"
    fi
}

# =============================================================================
# Opus Lock Tests
# =============================================================================

test_oracle_ask_permission() {
    local name="oh-my-opencode.json has oracle with ask permission (Opus Lock)"
    create_security_test_config
    local output_dir="$TEST_TMP_DIR/output6"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    local permission
    permission=$(jq -r '.agents.oracle.permissions.allow_tool_execution' "$output_dir/oh-my-opencode.json")
    
    if [[ "$permission" == "ask" ]]; then
        pass "$name"
    else
        fail "$name" "ask" "$permission"
    fi
}

test_auto_recover_disabled() {
    local name="oh-my-opencode.json has auto_recover set to false"
    create_security_test_config
    local output_dir="$TEST_TMP_DIR/output7"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    local auto_recover
    auto_recover=$(jq -r '.sisyphus_agent.auto_recover' "$output_dir/oh-my-opencode.json")
    
    if [[ "$auto_recover" == "false" ]]; then
        pass "$name"
    else
        fail "$name" "false" "$auto_recover"
    fi
}

# =============================================================================
# .opencodeignore Tests
# =============================================================================

test_opencodeignore_template_exists() {
    local name=".opencodeignore template exists"
    
    if [[ -f "$TEMPLATES_DIR/opencodeignore.tmpl" ]]; then
        pass "$name"
    else
        fail "$name" "file exists" "file not found"
    fi
}

test_opencodeignore_blocks_env() {
    local name=".opencodeignore blocks .env files"
    
    if grep -q "^\.env$" "$TEMPLATES_DIR/opencodeignore.tmpl" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" ".env in ignore list" "not found"
    fi
}

test_opencodeignore_blocks_pem() {
    local name=".opencodeignore blocks .pem files"
    
    if grep -q "\*\.pem" "$TEMPLATES_DIR/opencodeignore.tmpl" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "*.pem in ignore list" "not found"
    fi
}

test_opencodeignore_blocks_ssh_keys() {
    local name=".opencodeignore blocks SSH keys"
    
    if grep -q "id_rsa" "$TEMPLATES_DIR/opencodeignore.tmpl" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "id_rsa in ignore list" "not found"
    fi
}

test_opencodeignore_blocks_config_json() {
    local name=".opencodeignore blocks config.json (contains API key)"
    
    if grep -q "^config\.json$" "$TEMPLATES_DIR/opencodeignore.tmpl" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "config.json in ignore list" "not found"
    fi
}

# =============================================================================
# Default Values Tests
# =============================================================================

test_default_provider_whitelist() {
    local name="Uses default provider whitelist when not specified"
    
    # Create config without security section
    cat > "$TEST_TMP_DIR/minimal.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  }
}
EOF
    local output_dir="$TEST_TMP_DIR/output8"
    
    generate_all_configs "$TEST_TMP_DIR/minimal.json" "$output_dir" >/dev/null 2>&1
    
    local whitelist
    whitelist=$(jq -r '.provider.openrouter.options.provider.order | length' "$output_dir/opencode.json")
    
    # Default should have 3 providers
    if [[ "$whitelist" == "3" ]]; then
        pass "$name"
    else
        fail "$name" "3 default providers" "$whitelist providers"
    fi
}

test_default_max_tokens() {
    local name="Uses default max_tokens when not specified"
    
    cat > "$TEST_TMP_DIR/minimal2.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "deepseek/deepseek-v3",
    "planner": "anthropic/claude-opus-4.5",
    "librarian": "google/gemini-3-flash",
    "fallback": "meta-llama/llama-3.3-70b-instruct"
  }
}
EOF
    local output_dir="$TEST_TMP_DIR/output9"
    
    generate_all_configs "$TEST_TMP_DIR/minimal2.json" "$output_dir" >/dev/null 2>&1
    
    local max_tokens
    max_tokens=$(jq -r '.model_config["openrouter/deepseek/deepseek-v3"].max_tokens' "$output_dir/opencode.json")
    
    # Default orchestrator max_tokens is 32000
    if [[ "$max_tokens" == "32000" ]]; then
        pass "$name"
    else
        fail "$name" "32000 (default)" "$max_tokens"
    fi
}

# Run all tests
echo "========================================"
echo "Running Security Features Tests"
echo "========================================"
echo

echo "--- Provider Whitelist ---"
test_provider_whitelist_in_config
test_allow_fallbacks_disabled
test_zdr_enabled

echo
echo "--- Max Tokens Caps ---"
test_orchestrator_max_tokens
test_planner_max_tokens

echo
echo "--- Opus Lock & Auto-recover ---"
test_oracle_ask_permission
test_auto_recover_disabled

echo
echo "--- .opencodeignore Template ---"
test_opencodeignore_template_exists
test_opencodeignore_blocks_env
test_opencodeignore_blocks_pem
test_opencodeignore_blocks_ssh_keys
test_opencodeignore_blocks_config_json

echo
echo "--- Default Security Values ---"
test_default_provider_whitelist
test_default_max_tokens

echo
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
