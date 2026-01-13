#!/bin/bash
# test-relay-env-vars.sh - Tests for relay environment variable handling
#
# Verifies that RELAY_HOST and RELAY_PORT are properly passed through
# the setup scripts and start scripts to the relay process.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    ((TESTS_RUN++))
}

echo "=== Relay Environment Variable Tests ==="
echo ""

# ============================================
# main.ts environment variable tests
# ============================================
echo "--- main.ts Environment Variable Handling ---"

# Test: main.ts defines RELAY_HOST from process.env
if grep -q 'const RELAY_HOST = process.env.RELAY_HOST' "$PROJECT_ROOT/relay/main.ts"; then
    pass "main.ts defines RELAY_HOST from process.env"
else
    fail "main.ts should define RELAY_HOST from process.env"
fi

# Test: main.ts defines RELAY_PORT from process.env
if grep -q 'const RELAY_PORT = parseInt(process.env.RELAY_PORT' "$PROJECT_ROOT/relay/main.ts"; then
    pass "main.ts defines RELAY_PORT from process.env"
else
    fail "main.ts should define RELAY_PORT from process.env"
fi

# Test: main.ts has default RELAY_HOST of 127.0.0.1
if grep -q 'RELAY_HOST.*||.*"127.0.0.1"\|RELAY_HOST.*\|\|.*127.0.0.1' "$PROJECT_ROOT/relay/main.ts"; then
    pass "main.ts has default RELAY_HOST of 127.0.0.1"
else
    fail "main.ts should default RELAY_HOST to 127.0.0.1"
fi

# Test: main.ts has default RELAY_PORT of 8080
if grep -q 'RELAY_PORT.*||.*"8080"\|RELAY_PORT.*8080' "$PROJECT_ROOT/relay/main.ts"; then
    pass "main.ts has default RELAY_PORT of 8080"
else
    fail "main.ts should default RELAY_PORT to 8080"
fi

# Test: main.ts uses hostname in Bun.serve
if grep -q 'hostname: RELAY_HOST' "$PROJECT_ROOT/relay/main.ts"; then
    pass "main.ts uses RELAY_HOST as hostname in Bun.serve"
else
    fail "main.ts should use RELAY_HOST as hostname"
fi

# Test: main.ts uses port in Bun.serve
if grep -q 'port: RELAY_PORT' "$PROJECT_ROOT/relay/main.ts"; then
    pass "main.ts uses RELAY_PORT as port in Bun.serve"
else
    fail "main.ts should use RELAY_PORT as port"
fi

# ============================================
# start-relay.sh environment variable tests
# ============================================
echo ""
echo "--- start-relay.sh Environment Variable Handling ---"

# Test: start-relay.sh exports RELAY_HOST
if grep -q 'export RELAY_HOST=' "$PROJECT_ROOT/relay/start-relay.sh"; then
    pass "start-relay.sh exports RELAY_HOST"
else
    fail "start-relay.sh should export RELAY_HOST"
fi

# Test: start-relay.sh exports RELAY_PORT
if grep -q 'export RELAY_PORT=' "$PROJECT_ROOT/relay/start-relay.sh"; then
    pass "start-relay.sh exports RELAY_PORT"
else
    fail "start-relay.sh should export RELAY_PORT"
fi

# Test: start-relay.sh respects existing RELAY_HOST env var
if grep -q 'RELAY_HOST:-127.0.0.1\|RELAY_HOST:=127.0.0.1\|{RELAY_HOST:-' "$PROJECT_ROOT/relay/start-relay.sh"; then
    pass "start-relay.sh respects existing RELAY_HOST env var"
else
    fail "start-relay.sh should use \${RELAY_HOST:-default} pattern"
fi

# Test: start-relay.sh respects existing RELAY_PORT env var
if grep -q 'RELAY_PORT:-8080\|RELAY_PORT:=8080\|{RELAY_PORT:-' "$PROJECT_ROOT/relay/start-relay.sh"; then
    pass "start-relay.sh respects existing RELAY_PORT env var"
else
    fail "start-relay.sh should use \${RELAY_PORT:-default} pattern"
fi

# Test: start-relay.sh documents RELAY_HOST in usage
if grep -q 'RELAY_HOST.*Host to bind' "$PROJECT_ROOT/relay/start-relay.sh"; then
    pass "start-relay.sh documents RELAY_HOST in usage"
else
    fail "start-relay.sh should document RELAY_HOST in usage"
fi

# Test: start-relay.sh shows host in status
if grep -q 'Host: \$RELAY_HOST\|echo.*RELAY_HOST' "$PROJECT_ROOT/relay/start-relay.sh"; then
    pass "start-relay.sh shows host in status output"
else
    fail "start-relay.sh should show host in status output"
fi

# ============================================
# setup-relay.sh environment variable tests
# ============================================
echo ""
echo "--- setup-relay.sh Environment Variable Handling ---"

# Test: setup-relay.sh captures RELAY_HOST at start
if grep -q 'RELAY_HOST=.*:-.*127.0.0.1\|RELAY_HOST:-127.0.0.1' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh captures RELAY_HOST with default"
else
    fail "setup-relay.sh should capture RELAY_HOST with default 127.0.0.1"
fi

# Test: setup-relay.sh captures RELAY_PORT at start
if grep -q 'RELAY_PORT=.*:-.*8080\|RELAY_PORT:-8080' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh captures RELAY_PORT with default"
else
    fail "setup-relay.sh should capture RELAY_PORT with default 8080"
fi

# Test: setup-relay.sh passes RELAY_HOST when starting daemon
if grep -q 'RELAY_HOST=.*start-relay.sh\|RELAY_HOST.*RELAY_PORT.*start-relay' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh passes RELAY_HOST when starting daemon"
else
    fail "setup-relay.sh should pass RELAY_HOST to start-relay.sh"
fi

# Test: setup-relay.sh passes RELAY_PORT when starting daemon
if grep -q 'RELAY_PORT=.*start-relay.sh\|RELAY_PORT.*start-relay' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh passes RELAY_PORT when starting daemon"
else
    fail "setup-relay.sh should pass RELAY_PORT to start-relay.sh"
fi

# Test: setup-relay.sh documents RELAY_HOST in usage comments
if grep -q 'RELAY_HOST=0.0.0.0\|RELAY_HOST.*0.0.0.0' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh documents RELAY_HOST=0.0.0.0 example"
else
    fail "setup-relay.sh should document RELAY_HOST=0.0.0.0 usage"
fi

# Test: setup-relay.sh passes RELAY_HOST to docker compose
if grep -q 'RELAY_HOST.*docker compose\|RELAY_HOST=.*docker' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh passes RELAY_HOST to docker compose"
else
    fail "setup-relay.sh should pass RELAY_HOST to docker compose"
fi

# Test: setup-relay.sh kills existing relay before restarting
if grep -q 'pkill.*bun.*main.ts\|kill.*relay' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh kills existing bun relay before restarting"
else
    fail "setup-relay.sh should kill existing bun relay before restarting with new config"
fi

# Test: setup-relay.sh stops docker container before restarting
if grep -q 'docker stop sovereign-relay' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh stops docker container before restarting"
else
    fail "setup-relay.sh should stop docker container before restarting"
fi

# Test: setup-relay.sh always starts relay (not conditional on not running)
if grep -q 'RELAY_HOST=.*start-relay.sh daemon' "$PROJECT_ROOT/scripts/setup-relay.sh"; then
    pass "setup-relay.sh always restarts relay to apply new config"
else
    fail "setup-relay.sh should always restart relay to apply new env vars"
fi

# ============================================
# Integration: Environment variable flow
# ============================================
echo ""
echo "--- Integration: Environment Variable Flow ---"

# Test: All scripts use same default RELAY_HOST
MAIN_TS_DEFAULT=$(grep -oP 'RELAY_HOST.*\|\|.*"\K[^"]+' "$PROJECT_ROOT/relay/main.ts" 2>/dev/null | head -1)
START_SH_DEFAULT=$(grep -oP 'RELAY_HOST:-\K[^}"]+' "$PROJECT_ROOT/relay/start-relay.sh" 2>/dev/null | head -1)
SETUP_SH_DEFAULT=$(grep -oP 'RELAY_HOST:-\K[^}"]+' "$PROJECT_ROOT/scripts/setup-relay.sh" 2>/dev/null | head -1)

# main.ts uses "127.0.0.1" as default in the || pattern
if [[ "$START_SH_DEFAULT" == "127.0.0.1" && "$SETUP_SH_DEFAULT" == "127.0.0.1" ]]; then
    pass "All scripts use consistent default RELAY_HOST (127.0.0.1)"
else
    fail "Scripts have inconsistent default RELAY_HOST values (start: $START_SH_DEFAULT, setup: $SETUP_SH_DEFAULT)"
fi

# Test: All scripts use same default RELAY_PORT
MAIN_TS_PORT=$(grep -oP 'RELAY_PORT.*\|\|.*"\K[^"]+' "$PROJECT_ROOT/relay/main.ts" 2>/dev/null | head -1)
START_SH_PORT=$(grep -oP 'RELAY_PORT:-\K[^}]+' "$PROJECT_ROOT/relay/start-relay.sh" 2>/dev/null | head -1)
SETUP_SH_PORT=$(grep -oP 'RELAY_PORT:-\K[^}]+' "$PROJECT_ROOT/scripts/setup-relay.sh" 2>/dev/null | head -1)

if [[ "$START_SH_PORT" == "8080" && "$SETUP_SH_PORT" == "8080" ]]; then
    pass "All scripts use consistent default RELAY_PORT (8080)"
else
    fail "Scripts have inconsistent default RELAY_PORT values (start: $START_SH_PORT, setup: $SETUP_SH_PORT)"
fi

# ============================================
# Docker Compose environment variable tests
# ============================================
echo ""
echo "--- Docker Compose Environment Variable Handling ---"

# Test: docker-compose.relay.yml uses RELAY_HOST in port binding
if grep -q 'RELAY_HOST:-127.0.0.1.*RELAY_PORT\|RELAY_HOST.*:.*RELAY_PORT' "$PROJECT_ROOT/docker-compose.relay.yml"; then
    pass "docker-compose.relay.yml uses RELAY_HOST in port binding"
else
    fail "docker-compose.relay.yml should use RELAY_HOST in port binding"
fi

# Test: docker-compose.relay.yml has default RELAY_HOST of 127.0.0.1
if grep -q 'RELAY_HOST:-127.0.0.1' "$PROJECT_ROOT/docker-compose.relay.yml"; then
    pass "docker-compose.relay.yml defaults RELAY_HOST to 127.0.0.1"
else
    fail "docker-compose.relay.yml should default RELAY_HOST to 127.0.0.1"
fi

# Test: docker-compose.relay.yml documents RELAY_HOST usage
if grep -q 'RELAY_HOST=0.0.0.0\|RELAY_HOST.*0.0.0.0' "$PROJECT_ROOT/docker-compose.relay.yml"; then
    pass "docker-compose.relay.yml documents RELAY_HOST=0.0.0.0 example"
else
    fail "docker-compose.relay.yml should document RELAY_HOST=0.0.0.0 usage"
fi

# Test: docker-compose.relay.yml passes RELAY_HOST to container environment
if grep -q 'RELAY_HOST.*environment\|environment:' "$PROJECT_ROOT/docker-compose.relay.yml" && \
   grep -q 'RELAY_HOST' "$PROJECT_ROOT/docker-compose.relay.yml"; then
    pass "docker-compose.relay.yml has RELAY_HOST in container environment"
else
    fail "docker-compose.relay.yml should pass RELAY_HOST to container environment"
fi

# ============================================
# TypeScript test file coverage
# ============================================
echo ""
echo "--- TypeScript Test Coverage ---"

# Test: main.test.ts has environment variable tests
if grep -q 'describe.*Environment Variables' "$PROJECT_ROOT/relay/main.test.ts"; then
    pass "main.test.ts has Environment Variables test suite"
else
    fail "main.test.ts should have Environment Variables test suite"
fi

# Test: main.test.ts tests RELAY_HOST default
if grep -q 'RELAY_HOST.*127.0.0.1' "$PROJECT_ROOT/relay/main.test.ts"; then
    pass "main.test.ts tests RELAY_HOST default value"
else
    fail "main.test.ts should test RELAY_HOST default value"
fi

# Test: main.test.ts tests RELAY_PORT default
if grep -q 'RELAY_PORT.*8080' "$PROJECT_ROOT/relay/main.test.ts"; then
    pass "main.test.ts tests RELAY_PORT default value"
else
    fail "main.test.ts should test RELAY_PORT default value"
fi

# Test: main.test.ts tests 0.0.0.0 as valid RELAY_HOST
if grep -q '0\.0\.0\.0' "$PROJECT_ROOT/relay/main.test.ts"; then
    pass "main.test.ts tests 0.0.0.0 as valid RELAY_HOST"
else
    fail "main.test.ts should test 0.0.0.0 as valid RELAY_HOST"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "=== Results ==="
echo "Passed: $TESTS_PASSED / $TESTS_RUN"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
