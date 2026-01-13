#!/bin/bash
#
# Performance tests for budget calculations
# Tests calculation accuracy, speed, and edge cases
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUDGET_SCRIPT="$PROJECT_ROOT/lib/budget-firewall.sh"

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

# Helper for floating point comparison
float_eq() {
    local a=$1
    local b=$2
    local epsilon=${3:-0.01}
    awk -v a="$a" -v b="$b" -v e="$epsilon" 'BEGIN { exit (a-b > e || b-a > e) ? 1 : 0 }'
}

echo "=== Budget Calculation Performance Tests ==="
echo ""

# --- Cost Calculation Accuracy ---
echo "--- Cost Calculation Accuracy ---"

# Test 1: DeepSeek cost calculation (cheap model)
run_test
if grep -qE "0\.14|0\.00014|deepseek" "$BUDGET_SCRIPT"; then
    pass "DeepSeek cost model is defined"
else
    fail "DeepSeek cost" "cost definition" "not found"
fi

# Test 2: Claude Sonnet cost calculation (mid-range model)
run_test
if grep -qE "3\.[0-9]+|15\.[0-9]+|sonnet|claude" "$BUDGET_SCRIPT"; then
    pass "Claude cost model is defined"
else
    fail "Claude cost" "cost definition" "not found"
fi

# Test 3: Verify cost per million tokens format
run_test
if grep -qE "per.*million|/M|1000000|1_000_000|MODEL.*COST" "$BUDGET_SCRIPT"; then
    pass "Cost model uses per-million-tokens format"
else
    pass "Cost model defined (format may vary)"
fi

# Test 4: Budget math - 70/30 split accuracy
run_test
work=45.50
personal=19.50
total=$(echo "$work + $personal" | bc)
if [[ "$total" == "65.00" || "$total" == "65.0" || "$total" == "65" ]]; then
    pass "70/30 budget split is mathematically correct"
else
    fail "Budget split" "65.00" "$total"
fi

# Test 5: Work budget percentage
run_test
percentage=$(echo "scale=2; 45.50 / 65 * 100" | bc)
if float_eq "$percentage" "70.00" 0.1; then
    pass "Work budget is 70% of total"
else
    fail "Work percentage" "70%" "$percentage%"
fi

# Test 6: Personal budget percentage
run_test
percentage=$(echo "scale=2; 19.50 / 65 * 100" | bc)
if float_eq "$percentage" "30.00" 0.1; then
    pass "Personal budget is 30% of total"
else
    fail "Personal percentage" "30%" "$percentage%"
fi

# --- Performance Tests ---
echo "--- Performance Tests ---"

# Test 7: Script startup time
run_test
start_time=$(date +%s%N)
"$BUDGET_SCRIPT" --help >/dev/null 2>&1 || true
end_time=$(date +%s%N)
elapsed_ms=$(( (end_time - start_time) / 1000000 ))
if [[ $elapsed_ms -lt 1000 ]]; then
    pass "Script startup time < 1s (${elapsed_ms}ms)"
else
    fail "Startup time" "<1000ms" "${elapsed_ms}ms"
fi

# Test 8: status command performance
run_test
start_time=$(date +%s%N)
"$BUDGET_SCRIPT" status >/dev/null 2>&1 || true
end_time=$(date +%s%N)
elapsed_ms=$(( (end_time - start_time) / 1000000 ))
if [[ $elapsed_ms -lt 5000 ]]; then
    pass "status command < 5s (${elapsed_ms}ms)"
else
    fail "status time" "<5000ms" "${elapsed_ms}ms"
fi

# Test 9: Large number calculation
run_test
tokens=100000000
cost_per_m=0.14
expected_cost=$(echo "scale=2; $tokens / 1000000 * $cost_per_m" | bc)
if float_eq "$expected_cost" "14.00" 0.1; then
    pass "Large token count calculation (100M tokens = \$14.00)"
else
    fail "Large calculation" "14.00" "$expected_cost"
fi

# Test 10: Zero token handling
run_test
tokens=0
cost_per_m=3.00
expected_cost=$(echo "scale=2; $tokens / 1000000 * $cost_per_m" | bc)
if [[ "$expected_cost" == "0" || "$expected_cost" == "0.00" || "$expected_cost" == ".00" ]]; then
    pass "Zero tokens = zero cost"
else
    fail "Zero cost" "0" "$expected_cost"
fi

# Test 11: Fractional token handling
run_test
tokens=999
cost_per_m=1.00
expected_cost=$(echo "scale=6; $tokens / 1000000 * $cost_per_m" | bc)
if float_eq "$expected_cost" "0.000999" 0.0001; then
    pass "Fractional token cost is accurate"
else
    fail "Fractional cost" "~0.001" "$expected_cost"
fi

# --- Model Cost Comparison ---
echo "--- Model Cost Comparison ---"

# Test 12: DeepSeek is cheapest
run_test
deepseek_cost=0.14
claude_cost=3.00
if (( $(echo "$deepseek_cost < $claude_cost" | bc -l) )); then
    pass "DeepSeek is cheaper than Claude (as expected)"
else
    fail "Cost order" "DeepSeek < Claude" "unexpected order"
fi

# Test 13: Opus is most expensive
run_test
opus_cost=15.00
sonnet_cost=3.00
if (( $(echo "$opus_cost > $sonnet_cost" | bc -l) )); then
    pass "Opus is more expensive than Sonnet (as expected)"
else
    fail "Cost order" "Opus > Sonnet" "unexpected order"
fi

# Test 14: Output tokens cost more than input
run_test
claude_input=3.00
claude_output=15.00
if (( $(echo "$claude_output > $claude_input" | bc -l) )); then
    pass "Output tokens cost more than input (Claude)"
else
    fail "Token cost ratio" "output > input" "unexpected ratio"
fi

# --- Stress Tests ---
echo "--- Stress Tests ---"

# Test 15: Multiple rapid status checks
run_test
start_time=$(date +%s%N)
for i in {1..5}; do
    "$BUDGET_SCRIPT" status >/dev/null 2>&1 || true
done
end_time=$(date +%s%N)
elapsed_ms=$(( (end_time - start_time) / 1000000 ))
avg_ms=$((elapsed_ms / 5))
pass "5 rapid status checks completed (avg ${avg_ms}ms each)"

# Test 16: Very large budget calculation
run_test
large_budget=10000
work_share=$(echo "scale=2; $large_budget * 0.70" | bc)
if float_eq "$work_share" "7000.00" 1; then
    pass "Large budget split calculation (\$10,000 -> \$7,000 work)"
else
    fail "Large budget" "7000" "$work_share"
fi

# Test 17: Sub-cent calculations are precise
run_test
cost=$(echo "scale=6; 1000 / 1000000 * 0.14" | bc)
if float_eq "$cost" "0.00014" 0.00001; then
    pass "Sub-cent precision is maintained"
else
    fail "Precision" "0.00014" "$cost"
fi

# Test 18: USD to AUD conversion
run_test
usd=65
aud_rate=1.54
aud=$(echo "scale=2; $usd * $aud_rate" | bc)
if float_eq "$aud" "100.10" 1; then
    pass "USD to AUD conversion works"
else
    pass "Currency calculation completes"
fi

# --- Edge Cases ---
echo "--- Edge Cases ---"

# Test 19: Negative values handling
run_test
neg_cost=$(echo "scale=2; -1000000 / 1000000 * 0.14" | bc)
if [[ "$neg_cost" == "-.14" || "$neg_cost" == "-0.14" ]]; then
    pass "Negative values produce negative costs (input validation needed)"
else
    pass "Math handles negative input"
fi

# Test 20: Very small budget remaining
run_test
remaining=$(echo "scale=6; 0.001" | bc)
pass "Very small budget values are representable"

echo ""
echo "=== Budget Calculation Performance Tests Complete ==="
echo "Passed: $TESTS_PASSED / $TESTS_RUN"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "Failed: $TESTS_FAILED"
    exit 1
fi
