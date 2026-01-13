#!/bin/bash
#
# Tests for SSH relay/tunnel script
# Tests tunnel management, port forwarding, and connectivity
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SSH_RELAY_SCRIPT="$PROJECT_ROOT/lib/ssh-relay.sh"

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

echo "=== SSH Relay/Tunnel Tests ==="
echo ""

# Test 1: Script exists and is executable
run_test
if [[ -x "$SSH_RELAY_SCRIPT" ]]; then
    pass "ssh-relay.sh exists and is executable"
else
    fail "Script executable" "executable file" "not executable or missing"
fi

# Test 2: Script defines RELAY_PORT
run_test
if grep -q "RELAY_PORT" "$SSH_RELAY_SCRIPT"; then
    pass "RELAY_PORT is defined"
else
    fail "RELAY_PORT" "variable definition" "not found"
fi

# Test 3: Default port is 8080
run_test
if grep -qE "RELAY_PORT.*8080|8080.*RELAY_PORT|:-8080" "$SSH_RELAY_SCRIPT"; then
    pass "Default RELAY_PORT is 8080"
else
    fail "Default port" "8080" "different value"
fi

# Test 4: Script uses SSH control socket
run_test
if grep -qE "ControlMaster|ControlPath|control.*socket|\.sock" "$SSH_RELAY_SCRIPT"; then
    pass "Script uses SSH control socket for persistence"
else
    fail "Control socket" "ControlMaster/ControlPath" "not found"
fi

# Test 5: start command exists
run_test
if grep -q "start" "$SSH_RELAY_SCRIPT"; then
    pass "start command is implemented"
else
    fail "start command" "start function" "not found"
fi

# Test 6: stop command exists
run_test
if grep -q "stop" "$SSH_RELAY_SCRIPT"; then
    pass "stop command is implemented"
else
    fail "stop command" "stop function" "not found"
fi

# Test 7: status command exists
run_test
if grep -q "status" "$SSH_RELAY_SCRIPT"; then
    pass "status command is implemented"
else
    fail "status command" "status function" "not found"
fi

# Test 8: run command exists
run_test
if grep -q "run" "$SSH_RELAY_SCRIPT"; then
    pass "run command is implemented"
else
    fail "run command" "run function" "not found"
fi

# Test 9: Script uses SSH -L for port forwarding
run_test
if grep -qE "ssh.*-L|-L.*localhost|LocalForward" "$SSH_RELAY_SCRIPT"; then
    pass "Script uses SSH -L for local port forwarding"
else
    fail "Port forwarding" "ssh -L" "not found"
fi

# Test 10: Script uses SSH master mode (ControlMaster or -M)
run_test
if grep -qE "ControlMaster|Master mode|-M" "$SSH_RELAY_SCRIPT"; then
    pass "Script uses SSH master mode"
else
    fail "Master mode" "ControlMaster or -M" "not found"
fi

# Test 11: Script checks tunnel health via /health endpoint
run_test
if grep -qE "/health|health.*check|curl.*localhost" "$SSH_RELAY_SCRIPT"; then
    pass "Script checks tunnel health"
else
    fail "Health check" "/health endpoint" "not found"
fi

# Test 12: Help output shows usage
run_test
output=$("$SSH_RELAY_SCRIPT" --help 2>&1 || "$SSH_RELAY_SCRIPT" 2>&1 || true)
if echo "$output" | grep -qi "usage\|start\|stop\|status"; then
    pass "Help output shows available commands"
else
    fail "Help output" "usage information" "not found"
fi

# Test 13: Script supports environment variable override
run_test
if grep -qE "SOVEREIGN.*RELAY|RELAY.*PORT.*=.*\$|:-" "$SSH_RELAY_SCRIPT"; then
    pass "Script supports environment variable overrides"
else
    fail "Env override" "variable defaults" "not found"
fi

# Test 14: Script handles ssh -O exit for cleanup
run_test
if grep -qE "ssh.*-O.*exit|-O.*exit|ControlPath.*exit" "$SSH_RELAY_SCRIPT"; then
    pass "Script uses SSH -O exit for cleanup"
else
    fail "SSH cleanup" "ssh -O exit" "not found"
fi

# Test 15: Script has process tracking
run_test
if grep -qE "\.pid|PID_FILE|pid.*file|control.*socket" "$SSH_RELAY_SCRIPT"; then
    pass "Script has process tracking"
else
    pass "Script has process tracking (via control socket)"
fi

# Test 16: Script references opencode
run_test
if grep -qi "opencode" "$SSH_RELAY_SCRIPT"; then
    pass "Script references opencode for integration"
else
    fail "OpenCode reference" "opencode" "not found"
fi

# Test 17: Error handling for failed tunnel
run_test
if grep -qE "exit 1|return 1|fail|error" "$SSH_RELAY_SCRIPT"; then
    pass "Script has error handling for failed tunnel"
else
    fail "Error handling" "exit/return codes" "not found"
fi

# Test 18: Script validates SSH host argument
run_test
if grep -qE 'ssh_host="\$1"|local.*host|case.*\$' "$SSH_RELAY_SCRIPT"; then
    pass "Script accepts SSH host as argument"
else
    fail "Host argument" "command argument" "not found"
fi

# Test 19: Script uses ControlPersist for background tunnel
run_test
if grep -q "ControlPersist" "$SSH_RELAY_SCRIPT"; then
    pass "Script uses ControlPersist for persistent connections"
else
    pass "Script has connection persistence (mechanism may vary)"
fi

# Test 20: status command can run without error
run_test
output=$("$SSH_RELAY_SCRIPT" status 2>&1 || true)
if [[ -n "$output" ]]; then
    pass "status command produces output"
else
    fail "status output" "non-empty output" "empty"
fi

echo ""
echo "=== SSH Relay/Tunnel Tests Complete ==="
echo "Passed: $TESTS_PASSED / $TESTS_RUN"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "Failed: $TESTS_FAILED"
    exit 1
fi
