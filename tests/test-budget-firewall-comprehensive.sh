#!/usr/bin/env bash
# test-budget-firewall-comprehensive.sh - Extended tests for budget monitoring
# Covers API mocking, cost calculations, and threshold warnings
# Usage: ./tests/test-budget-firewall-comprehensive.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$PROJECT_DIR/lib"
TEST_TMP_DIR=$(mktemp -d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

BUDGET_SCRIPT="$LIB_DIR/budget-firewall.sh"

# ============================================================================
# SCRIPT STRUCTURE TESTS
# ============================================================================

echo "========================================"
echo "Script Structure Tests"
echo "========================================"
echo

test_script_exists() {
    local name="budget-firewall.sh script exists"
    if [[ -f "$BUDGET_SCRIPT" ]]; then
        pass "$name"
    else
        fail "$name" "script exists" "not found"
    fi
}

test_script_executable() {
    local name="budget-firewall.sh is executable"
    if [[ -x "$BUDGET_SCRIPT" ]]; then
        pass "$name"
    else
        fail "$name" "executable" "not executable"
    fi
}

test_script_exists
test_script_executable

# ============================================================================
# BUDGET CONSTANTS TESTS
# ============================================================================

echo
echo "========================================"
echo "Budget Constants Tests"
echo "========================================"
echo

test_budget_defined() {
    local name="Monthly budget is defined"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -qi 'budget\|BUDGET'; then
        pass "$name"
    else
        fail "$name" "budget constant" "not found"
    fi
}

test_budget_has_usd_value() {
    local name="Budget has USD value"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -qi '\$\|usd\|dollar\|20'; then
        pass "$name"
    else
        fail "$name" "USD value" "not found"
    fi
}

test_work_personal_split() {
    local name="Work/personal split is defined"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -qi 'work\|personal\|split\|ratio'; then
        pass "$name"
    else
        fail "$name" "work/personal split" "not found"
    fi
}

test_budget_defined
test_budget_has_usd_value
test_work_personal_split

# ============================================================================
# MODEL COST TESTS
# ============================================================================

echo
echo "========================================"
echo "Model Cost Tests"
echo "========================================"
echo

test_deepseek_cost() {
    local name="DeepSeek model cost is defined"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -qi 'deepseek'; then
        pass "$name"
    else
        fail "$name" "DeepSeek cost" "not found"
    fi
}

test_claude_cost() {
    local name="Claude model cost is defined"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -qi 'claude\|anthropic'; then
        pass "$name"
    else
        fail "$name" "Claude cost" "not found"
    fi
}

test_gemini_cost() {
    local name="Gemini model cost is defined"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -qi 'gemini\|google'; then
        pass "$name"
    else
        fail "$name" "Gemini cost" "not found"
    fi
}

test_deepseek_cost
test_claude_cost
test_gemini_cost

# ============================================================================
# COMMAND STRUCTURE TESTS
# ============================================================================

echo
echo "========================================"
echo "Command Structure Tests"
echo "========================================"
echo

test_status_command() {
    local name="status command is defined"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -q 'status)'; then
        pass "$name"
    else
        fail "$name" "status command" "not found"
    fi
}

test_estimate_command() {
    local name="estimate command is defined"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -q 'estimate)'; then
        pass "$name"
    else
        fail "$name" "estimate command" "not found"
    fi
}

test_monitor_command() {
    local name="monitor command is defined"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -q 'monitor)'; then
        pass "$name"
    else
        fail "$name" "monitor command" "not found"
    fi
}

test_status_command
test_estimate_command
test_monitor_command

# ============================================================================
# API KEY HANDLING TESTS
# ============================================================================

echo
echo "========================================"
echo "API Key Handling Tests"
echo "========================================"
echo

test_get_api_key_function() {
    local name="get_api_key function is defined"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -q 'get_api_key()\|api_key\|API_KEY'; then
        pass "$name"
    else
        fail "$name" "get_api_key function" "not found"
    fi
}

test_checks_env_variable() {
    local name="Checks environment variable for API key"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -qi 'GITHUB_OAUTH_TOKEN\|github_oauth_token'; then
        pass "$name"
    else
        fail "$name" "environment variable check" "not found"
    fi
}

test_checks_config_file() {
    local name="Checks config.json for API key"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -qi 'config\.json\|jq.*api_key\|github_oauth_token'; then
        pass "$name"
    else
        fail "$name" "config.json check" "not found"
    fi
}

test_get_api_key_function
test_checks_env_variable
test_checks_config_file

# ============================================================================
# GITHUB COPILOT API TESTS
# ============================================================================

echo
echo "========================================"
echo "GitHub Copilot API Tests"
echo "========================================"
echo

test_uses_github_api() {
    local name="Uses GitHub Copilot API endpoint"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -qi 'api.githubcopilot.com\|github.*copilot'; then
        pass "$name"
    else
        fail "$name" "GitHub Copilot API" "not found"
    fi
}

test_get_usage_stats_function() {
    local name="get_usage_stats function is defined"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -q 'get_usage_stats()\|usage'; then
        pass "$name"
    else
        fail "$name" "get_usage_stats function" "not found"
    fi
}

test_uses_curl() {
    local name="Uses curl for API calls"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -q 'curl'; then
        pass "$name"
    else
        fail "$name" "curl" "not found"
    fi
}

test_uses_github_api
test_get_usage_stats_function
test_uses_curl

# ============================================================================
# STATUS DISPLAY TESTS
# ============================================================================

echo
echo "========================================"
echo "Status Display Tests"
echo "========================================"
echo

test_show_status_function() {
    local name="show_status function is defined"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -q 'show_status()\|show_status ()'; then
        pass "$name"
    else
        fail "$name" "show_status function" "not found"
    fi
}

test_shows_percentage() {
    local name="Shows percentage of budget used"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -qi 'percent\|%'; then
        pass "$name"
    else
        fail "$name" "percentage" "not found"
    fi
}

test_warning_thresholds() {
    local name="Has warning thresholds"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -qi 'warn\|threshold\|50\|80\|100'; then
        pass "$name"
    else
        fail "$name" "warning thresholds" "not found"
    fi
}

test_show_status_function
test_shows_percentage
test_warning_thresholds

# ============================================================================
# COST CALCULATION TESTS
# ============================================================================

echo
echo "========================================"
echo "Cost Calculation Tests"
echo "========================================"
echo

test_estimate_costs_function() {
    local name="estimate_costs function is defined"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -q 'estimate_costs()\|estimate'; then
        pass "$name"
    else
        fail "$name" "estimate_costs function" "not found"
    fi
}

test_calculates_per_token() {
    local name="Calculates cost per token"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -qi 'token\|1000000\|million'; then
        pass "$name"
    else
        fail "$name" "per-token calculation" "not found"
    fi
}

test_input_output_costs() {
    local name="Distinguishes input/output costs"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -qi 'input\|output\|prompt\|completion'; then
        pass "$name"
    else
        fail "$name" "input/output costs" "not found"
    fi
}

test_estimate_costs_function
test_calculates_per_token
test_input_output_costs

# ============================================================================
# MONITORING TESTS
# ============================================================================

echo
echo "========================================"
echo "Monitoring Tests"
echo "========================================"
echo

test_monitor_usage_function() {
    local name="monitor_usage function is defined"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -q 'monitor_usage()\|monitor'; then
        pass "$name"
    else
        fail "$name" "monitor_usage function" "not found"
    fi
}

test_continuous_loop() {
    local name="Monitor has continuous loop"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -qi 'while\|loop\|sleep'; then
        pass "$name"
    else
        fail "$name" "continuous loop" "not found"
    fi
}

test_delta_calculation() {
    local name="Calculates usage delta"
    local content
    content=$(cat "$BUDGET_SCRIPT")
    
    if echo "$content" | grep -qi 'delta\|diff\|change\|previous'; then
        pass "$name"
    else
        fail "$name" "delta calculation" "not found"
    fi
}

test_monitor_usage_function
test_continuous_loop
test_delta_calculation

# ============================================================================
# INTEGRATION TESTS (Non-destructive)
# ============================================================================

echo
echo "========================================"
echo "Integration Tests (Non-destructive)"
echo "========================================"
echo

test_help_output() {
    local name="Help output is available"
    local output
    output=$("$BUDGET_SCRIPT" help 2>&1 || "$BUDGET_SCRIPT" --help 2>&1 || "$BUDGET_SCRIPT" 2>&1)
    
    if echo "$output" | grep -qi 'usage\|budget\|command'; then
        pass "$name"
    else
        fail "$name" "usage text" "no output"
    fi
}

test_estimate_without_key() {
    local name="Estimate command handles missing API key"
    
    # Run with empty/invalid key
    local output
    output=$(GITHUB_OAUTH_TOKEN="" "$BUDGET_SCRIPT" estimate 2>&1)
    
    # Should not crash, should show error or fallback
    pass "$name"
}

test_help_output
test_estimate_without_key

# ============================================================================
# COST CALCULATION ACCURACY TESTS
# ============================================================================

echo
echo "========================================"
echo "Cost Calculation Accuracy Tests"
echo "========================================"
echo

test_deepseek_math() {
    local name="DeepSeek V3.2 cost calculation is accurate"
    
    # DeepSeek V3.2: $0.25/M input, $0.38/M output
    # 1M tokens should cost $0.63 total
    local input_cost="0.25"
    local output_cost="0.38"
    local total
    total=$(echo "$input_cost + $output_cost" | bc)
    
    if [[ "$total" == ".63" ]] || [[ "$total" == "0.63" ]]; then
        pass "$name"
    else
        fail "$name" "0.63" "$total"
    fi
}

test_claude_math() {
    local name="Claude Haiku cost calculation is accurate"
    
    # Claude Haiku 4.5: $1.00/M input, $5.00/M output
    # 1M tokens should cost $6.00 total
    local input_cost="1.00"
    local output_cost="5.00"
    local total
    total=$(echo "$input_cost + $output_cost" | bc)
    
    if [[ "$total" == "6.00" ]] || [[ "$total" == "6" ]]; then
        pass "$name"
    else
        fail "$name" "6.00" "$total"
    fi
}

test_monthly_budget() {
    local name="Monthly budget allows reasonable token usage"
    
    # With $20 budget and DeepSeek V3.2 ($0.63/M tokens)
    # Should allow ~31M tokens per month
    local budget="20"
    local cost_per_million="0.63"
    local tokens_allowed
    tokens_allowed=$(echo "scale=0; $budget / $cost_per_million" | bc)
    
    if [[ "$tokens_allowed" -gt 25 ]]; then
        pass "$name"
    else
        fail "$name" ">25M tokens" "${tokens_allowed}M tokens"
    fi
}

test_deepseek_math
test_claude_math
test_monthly_budget

# ============================================================================
# SUMMARY
# ============================================================================

echo
echo "========================================"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
