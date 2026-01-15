#!/usr/bin/env bash
# auth-relay.sh - Authenticate relay server with GitHub Copilot (headless-friendly)
#
# Usage:
#   ./scripts/auth-relay.sh [relay-url]
#
# Examples:
#   ./scripts/auth-relay.sh                    # Uses http://localhost:8080
#   ./scripts/auth-relay.sh http://localhost:8081
#   RELAY_URL=http://pi:8080 ./scripts/auth-relay.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

RELAY_URL="${1:-${RELAY_URL:-http://localhost:8080}}"

echo -e "${BLUE}${BOLD}"
echo "╔═══════════════════════════════════════════════════╗"
echo "║     GitHub Copilot Authentication (Headless)      ║"
echo "╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check if already authenticated
echo -e "${YELLOW}Checking current auth status...${NC}"
AUTH_STATUS=$(curl -sf "${RELAY_URL}/auth/status" 2>/dev/null || echo '{"authenticated":false}')
IS_AUTH=$(echo "$AUTH_STATUS" | grep -o '"authenticated":\s*true' || true)

if [[ -n "$IS_AUTH" ]]; then
    echo -e "${GREEN}Already authenticated with GitHub Copilot!${NC}"
    echo ""
    echo "If you need to re-authenticate, first clear the token:"
    echo "  Edit config.json and remove the github_oauth_token field"
    echo "  Then restart the relay and run this script again"
    exit 0
fi

# Start device code flow
echo -e "${YELLOW}Starting device code flow...${NC}"
DEVICE_RESPONSE=$(curl -sf -X POST "${RELAY_URL}/auth/device" 2>/dev/null || true)

if [[ -z "$DEVICE_RESPONSE" ]]; then
    echo -e "${RED}Error: Could not connect to relay at ${RELAY_URL}${NC}"
    echo ""
    echo "Make sure the relay is running:"
    echo "  cd ~/sovereign-agent/relay && bun run main.ts"
    echo ""
    echo "Or start it with the setup script:"
    echo "  curl -fsSL .../scripts/setup-relay.sh | bash"
    exit 1
fi

# Parse response
USER_CODE=$(echo "$DEVICE_RESPONSE" | grep -o '"user_code":"[^"]*"' | cut -d'"' -f4)
VERIFICATION_URI=$(echo "$DEVICE_RESPONSE" | grep -o '"verification_uri":"[^"]*"' | cut -d'"' -f4)
FLOW_ID=$(echo "$DEVICE_RESPONSE" | grep -o '"flow_id":"[^"]*"' | cut -d'"' -f4)

if [[ -z "$USER_CODE" || -z "$FLOW_ID" ]]; then
    echo -e "${RED}Error: Failed to start device code flow${NC}"
    echo "Response: $DEVICE_RESPONSE"
    exit 1
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}Your code:${NC}  ${BLUE}${BOLD}${USER_CODE}${NC}"
echo ""
echo -e "  ${BOLD}Go to:${NC}      ${BLUE}${VERIFICATION_URI}${NC}"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Waiting for you to authorize...${NC}"
echo "(Press Ctrl+C to cancel)"
echo ""

# Poll for completion
MAX_ATTEMPTS=60  # 5 minutes with 5-second intervals
ATTEMPT=0

while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
    sleep 5
    ((ATTEMPT++))
    
    POLL_RESPONSE=$(curl -sf -X POST "${RELAY_URL}/auth/poll" \
        -H "Content-Type: application/json" \
        -d "{\"flow_id\":\"${FLOW_ID}\"}" 2>/dev/null || echo '{"status":"error"}')
    
    STATUS=$(echo "$POLL_RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    case "$STATUS" in
        success)
            echo ""
            echo -e "${GREEN}${BOLD}Authentication successful!${NC}"
            echo ""
            echo "Your relay is now connected to GitHub Copilot."
            echo "You can now use the relay to proxy API requests."
            exit 0
            ;;
        expired)
            echo ""
            echo -e "${RED}Device code expired. Please try again.${NC}"
            exit 1
            ;;
        error)
            MESSAGE=$(echo "$POLL_RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
            echo ""
            echo -e "${RED}Error: ${MESSAGE:-Unknown error}${NC}"
            exit 1
            ;;
        pending)
            # Still waiting, show a dot
            echo -n "."
            ;;
        *)
            echo -n "."
            ;;
    esac
done

echo ""
echo -e "${RED}Timed out waiting for authorization.${NC}"
echo "Please try again."
exit 1
