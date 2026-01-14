#!/usr/bin/env bash
# test-generate-configs.sh - Test the config generation script
# Usage: ./tests/test-generate-configs.sh

# Don't use set -e as we test various scenarios

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

# Create a valid test config with tier system
create_test_config() {
    cat > "$TEST_TMP_DIR/config.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key-12345",
  "site_url": "https://test.example.com",
  "site_name": "TestSite",
  "tier": "frugal",
  "preferences": {
    "dcp_turn_protection": 3,
    "dcp_error_retention_turns": 5,
    "dcp_nudge_frequency": 15
  }
}
EOF
}

# Source the generate script
source "$LIB_DIR/generate-configs.sh"

# Test 1: generates opencode.jsonc with correct API key
test_opencode_api_key() {
    local name="opencode.jsonc contains correct API key"
    create_test_config
    local output_dir="$TEST_TMP_DIR/output"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    # Check for API key using grep (simpler than parsing JSONC)
    if grep -q 'sk-or-v1-test-key-12345' "$output_dir/opencode.jsonc"; then
        pass "$name"
    else
        fail "$name" "sk-or-v1-test-key-12345 in file" "not found"
    fi
}

# Test 2: generates opencode.jsonc for frugal tier
test_opencode_frugal_tier() {
    local name="opencode.jsonc uses frugal tier template"
    create_test_config
    local output_dir="$TEST_TMP_DIR/output2"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    # Check that opencode.jsonc exists and contains frugal-specific model
    if grep -q 'deepseek/deepseek-v3.2' "$output_dir/opencode.jsonc"; then
        pass "$name"
    else
        fail "$name" "deepseek/deepseek-v3.2 in config" "not found"
    fi
}

# Test 3: generates dcp.jsonc with correct turn protection
test_dcp_turn_protection() {
    local name="dcp.jsonc contains correct turn protection"
    create_test_config
    local output_dir="$TEST_TMP_DIR/output3"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    # JSONC files have comments, so we need to strip them before parsing with jq
    local turns
    turns=$(sed '/^\/\//d' "$output_dir/dcp.jsonc" | jq -r '.turnProtection.turns')
    
    if [[ "$turns" == "3" ]]; then
        pass "$name"
    else
        fail "$name" "3" "$turns"
    fi
}

# Test 4: copies OpenAgents files
test_openagents_copied() {
    local name="OpenAgents agent files copied to config dir"
    create_test_config
    local output_dir="$TEST_TMP_DIR/output4"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    # Check that agent files were copied
    if [[ -d "$output_dir/.opencode/agent" ]]; then
        pass "$name"
    else
        fail "$name" ".opencode/agent directory" "not found"
    fi
}

# Test 5: copies OpenAgents commands
test_openagents_commands() {
    local name="OpenAgents command files copied to config dir"
    create_test_config
    local output_dir="$TEST_TMP_DIR/output5"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    # Check that command files were copied
    if [[ -d "$output_dir/.opencode/command" ]]; then
        pass "$name"
    else
        fail "$name" ".opencode/command directory" "not found"
    fi
}

# Test 6: backs up existing configs
test_backup_existing() {
    local name="Backs up existing config files"
    create_test_config
    local output_dir="$TEST_TMP_DIR/output6"
    mkdir -p "$output_dir"
    
    # Create an existing config
    echo '{"existing": true}' > "$output_dir/opencode.jsonc"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    # Check if backup was created
    local backup_count
    backup_count=$(ls -1 "$output_dir"/opencode.jsonc.backup.* 2>/dev/null | wc -l)
    
    if [[ "$backup_count" -ge 1 ]]; then
        pass "$name"
    else
        fail "$name" "at least 1 backup" "$backup_count backups"
    fi
}

# Test 7: uses default tier when not specified
test_default_tier() {
    local name="Uses default tier (frugal) when not specified"
    
    # Create config without tier
    cat > "$TEST_TMP_DIR/minimal.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite"
}
EOF
    local output_dir="$TEST_TMP_DIR/output7"
    
    generate_all_configs "$TEST_TMP_DIR/minimal.json" "$output_dir" >/dev/null 2>&1
    
    # Frugal tier uses DeepSeek V3.2 as the openagent model
    if grep -q 'deepseek/deepseek-v3.2' "$output_dir/opencode.jsonc"; then
        pass "$name"
    else
        fail "$name" "frugal tier (deepseek model)" "not found"
    fi
}

# Test 8: premium tier uses Claude models
test_premium_tier() {
    local name="Premium tier uses Claude models"
    
    cat > "$TEST_TMP_DIR/premium.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "tier": "premium"
}
EOF
    local output_dir="$TEST_TMP_DIR/output8"
    
    generate_all_configs "$TEST_TMP_DIR/premium.json" "$output_dir" >/dev/null 2>&1
    
    # Premium tier uses Claude Sonnet/Opus
    if grep -q 'anthropic/claude-sonnet-4.5\|anthropic/claude-opus-4.5' "$output_dir/opencode.jsonc"; then
        pass "$name"
    else
        fail "$name" "claude models" "not found"
    fi
}

# Test 9: free tier uses free models
test_free_tier() {
    local name="Free tier uses free models"
    
    cat > "$TEST_TMP_DIR/free.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "tier": "free"
}
EOF
    local output_dir="$TEST_TMP_DIR/output9"
    
    generate_all_configs "$TEST_TMP_DIR/free.json" "$output_dir" >/dev/null 2>&1
    
    # Free tier uses :free suffix models
    if grep -q ':free' "$output_dir/opencode.jsonc"; then
        pass "$name"
    else
        fail "$name" ":free models" "not found"
    fi
}

# Run all tests
echo "========================================"
echo "Running generate-configs.sh tests"
echo "========================================"
echo

test_opencode_api_key
test_opencode_frugal_tier
test_dcp_turn_protection
test_openagents_copied
test_openagents_commands
test_backup_existing
test_default_tier
test_premium_tier
test_free_tier

echo
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
