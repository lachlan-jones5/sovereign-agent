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

# Create a valid test config
create_test_config() {
    cat > "$TEST_TMP_DIR/config.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key-12345",
  "site_url": "https://test.example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "test/orchestrator-model",
    "planner": "test/planner-model",
    "librarian": "test/librarian-model",
    "fallback": "test/fallback-model"
  },
  "preferences": {
    "ultrawork_max_iterations": 75,
    "dcp_turn_protection": 3,
    "dcp_error_retention_turns": 5,
    "dcp_nudge_frequency": 15
  }
}
EOF
}

# Source the generate script
source "$LIB_DIR/generate-configs.sh"

# Test 1: generates opencode.json with correct API key
test_opencode_api_key() {
    local name="opencode.json contains correct API key"
    create_test_config
    local output_dir="$TEST_TMP_DIR/output"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    local api_key
    api_key=$(jq -r '.provider.openrouter.apiKey' "$output_dir/opencode.json")
    
    if [[ "$api_key" == "sk-or-v1-test-key-12345" ]]; then
        pass "$name"
    else
        fail "$name" "sk-or-v1-test-key-12345" "$api_key"
    fi
}

# Test 2: generates opencode.json with correct model
test_opencode_model() {
    local name="opencode.json contains correct orchestrator model"
    create_test_config
    local output_dir="$TEST_TMP_DIR/output2"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    local model
    model=$(jq -r '.provider.openrouter.model' "$output_dir/opencode.json")
    
    if [[ "$model" == "test/orchestrator-model" ]]; then
        pass "$name"
    else
        fail "$name" "test/orchestrator-model" "$model"
    fi
}

# Test 3: generates dcp.jsonc with correct turn protection
test_dcp_turn_protection() {
    local name="dcp.jsonc contains correct turn protection"
    create_test_config
    local output_dir="$TEST_TMP_DIR/output3"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    local turns
    turns=$(jq -r '.turnProtection.turns' "$output_dir/dcp.jsonc")
    
    if [[ "$turns" == "3" ]]; then
        pass "$name"
    else
        fail "$name" "3" "$turns"
    fi
}

# Test 4: generates oh-my-opencode.json with correct agent models
test_omo_agent_models() {
    local name="oh-my-opencode.json contains correct Sisyphus model"
    create_test_config
    local output_dir="$TEST_TMP_DIR/output4"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    local model
    model=$(jq -r '.agents.Sisyphus.model' "$output_dir/oh-my-opencode.json")
    
    if [[ "$model" == "test/orchestrator-model" ]]; then
        pass "$name"
    else
        fail "$name" "test/orchestrator-model" "$model"
    fi
}

# Test 5: generates oh-my-opencode.json with correct oracle model
test_omo_oracle_model() {
    local name="oh-my-opencode.json contains correct oracle model"
    create_test_config
    local output_dir="$TEST_TMP_DIR/output5"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    local model
    model=$(jq -r '.agents.oracle.model' "$output_dir/oh-my-opencode.json")
    
    if [[ "$model" == "test/planner-model" ]]; then
        pass "$name"
    else
        fail "$name" "test/planner-model" "$model"
    fi
}

# Test 6: backs up existing configs
test_backup_existing() {
    local name="Backs up existing config files"
    create_test_config
    local output_dir="$TEST_TMP_DIR/output6"
    mkdir -p "$output_dir"
    
    # Create an existing config
    echo '{"existing": true}' > "$output_dir/opencode.json"
    
    generate_all_configs "$TEST_TMP_DIR/config.json" "$output_dir" >/dev/null 2>&1
    
    # Check if backup was created
    local backup_count
    backup_count=$(ls -1 "$output_dir"/opencode.json.backup.* 2>/dev/null | wc -l)
    
    if [[ "$backup_count" -ge 1 ]]; then
        pass "$name"
    else
        fail "$name" "at least 1 backup" "$backup_count backups"
    fi
}

# Test 7: uses default values when preferences not specified
test_default_preferences() {
    local name="Uses default values for missing preferences"
    
    # Create config without preferences
    cat > "$TEST_TMP_DIR/minimal.json" << 'EOF'
{
  "openrouter_api_key": "sk-or-v1-test-key",
  "site_url": "https://example.com",
  "site_name": "TestSite",
  "models": {
    "orchestrator": "test/orchestrator-model",
    "planner": "test/planner-model",
    "librarian": "test/librarian-model",
    "fallback": "test/fallback-model"
  }
}
EOF
    local output_dir="$TEST_TMP_DIR/output7"
    
    generate_all_configs "$TEST_TMP_DIR/minimal.json" "$output_dir" >/dev/null 2>&1
    
    local turns
    turns=$(jq -r '.turnProtection.turns' "$output_dir/dcp.jsonc")
    
    # Default is 2
    if [[ "$turns" == "2" ]]; then
        pass "$name"
    else
        fail "$name" "2 (default)" "$turns"
    fi
}

# Run all tests
echo "========================================"
echo "Running generate-configs.sh tests"
echo "========================================"
echo

test_opencode_api_key
test_opencode_model
test_dcp_turn_protection
test_omo_agent_models
test_omo_oracle_model
test_backup_existing
test_default_preferences

echo
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
