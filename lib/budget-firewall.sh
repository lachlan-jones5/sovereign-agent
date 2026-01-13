#!/usr/bin/env bash
# budget-firewall.sh - OpenRouter Budget Firewall Setup
#
# Implements the "Budget Firewall" from the red team analysis:
# - Helps set hard credit limits on OpenRouter API keys
# - Monitors current usage and remaining budget
# - Provides cost estimates for different usage patterns
#
# Usage:
#   ./lib/budget-firewall.sh status           # Check current usage
#   ./lib/budget-firewall.sh estimate         # Estimate costs for usage patterns
#   ./lib/budget-firewall.sh setup-limits     # Instructions for setting limits
#   ./lib/budget-firewall.sh monitor          # Continuous usage monitoring

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Budget constraints (from red team analysis)
MONTHLY_BUDGET_AUD=100
MONTHLY_BUDGET_USD=65
WORK_BUDGET_USD=45.50    # 70% for work
PERSONAL_BUDGET_USD=19.50 # 30% for personal

# Model costs (per 1M tokens) from OpenRouter
declare -A MODEL_INPUT_COSTS=(
    ["deepseek/deepseek-v3"]=0.27
    ["anthropic/claude-opus-4.5"]=5.00
    ["google/gemini-3-flash"]=0.50
    ["meta-llama/llama-3.3-70b-instruct"]=0.20
)

declare -A MODEL_OUTPUT_COSTS=(
    ["deepseek/deepseek-v3"]=1.10
    ["anthropic/claude-opus-4.5"]=25.00
    ["google/gemini-3-flash"]=3.00
    ["meta-llama/llama-3.3-70b-instruct"]=0.20
)

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get API key from config or environment
get_api_key() {
    local api_key=""
    
    # Try environment variable first
    if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
        api_key="$OPENROUTER_API_KEY"
    # Then try config file
    elif [[ -f "$PROJECT_DIR/config.json" ]]; then
        api_key=$(jq -r '.openrouter_api_key // empty' "$PROJECT_DIR/config.json")
    fi
    
    if [[ -z "$api_key" || "$api_key" == "sk-or-v1-your-api-key-here" ]]; then
        log_error "No valid API key found"
        echo "Set OPENROUTER_API_KEY environment variable or update config.json"
        return 1
    fi
    
    echo "$api_key"
}

# Query OpenRouter API for usage stats
get_usage_stats() {
    local api_key
    api_key=$(get_api_key) || return 1
    
    # OpenRouter API endpoint for usage
    local response
    response=$(curl -s -H "Authorization: Bearer $api_key" \
        "https://openrouter.ai/api/v1/auth/key" 2>/dev/null)
    
    if [[ -z "$response" || "$response" == *"error"* ]]; then
        log_error "Failed to fetch usage stats from OpenRouter"
        echo "$response"
        return 1
    fi
    
    echo "$response"
}

# Show current usage status
show_status() {
    echo -e "${BOLD}${BLUE}=== OpenRouter Budget Status ===${NC}"
    echo
    
    local stats
    stats=$(get_usage_stats) || return 1
    
    local usage
    local limit
    local remaining
    
    usage=$(echo "$stats" | jq -r '.data.usage // 0')
    limit=$(echo "$stats" | jq -r '.data.limit // "unlimited"')
    rate_limit=$(echo "$stats" | jq -r '.data.rate_limit // {}')
    
    echo -e "${BOLD}API Key Info:${NC}"
    echo "  Usage:      \$$usage"
    echo "  Limit:      ${limit}"
    echo
    
    if [[ "$limit" != "unlimited" && "$limit" != "null" ]]; then
        remaining=$(echo "$limit - $usage" | bc 2>/dev/null || echo "unknown")
        echo "  Remaining:  \$$remaining"
        
        # Calculate percentage used
        local pct
        pct=$(echo "scale=1; $usage / $limit * 100" | bc 2>/dev/null || echo "?")
        echo "  Used:       ${pct}%"
        
        # Warnings
        if (( $(echo "$pct > 80" | bc -l 2>/dev/null || echo 0) )); then
            log_warn "WARNING: Over 80% of budget used!"
        elif (( $(echo "$pct > 50" | bc -l 2>/dev/null || echo 0) )); then
            log_info "Over 50% of budget used"
        fi
    else
        log_warn "No hard limit set! See 'setup-limits' command"
    fi
    
    echo
    echo -e "${BOLD}Budget Constraints (from red team analysis):${NC}"
    echo "  Monthly Budget:  \$${MONTHLY_BUDGET_AUD} AUD (\$${MONTHLY_BUDGET_USD} USD)"
    echo "  Work Budget:     \$${WORK_BUDGET_USD} USD (70%)"
    echo "  Personal Budget: \$${PERSONAL_BUDGET_USD} USD (30%)"
    echo
    echo -e "${BOLD}Recommended Actions:${NC}"
    if [[ "$limit" == "unlimited" || "$limit" == "null" ]]; then
        echo "  1. Set a hard credit limit on your API key (see 'setup-limits')"
        echo "  2. Consider creating separate keys for work/personal"
    fi
}

# Estimate costs for usage patterns
estimate_costs() {
    echo -e "${BOLD}${BLUE}=== Cost Estimation Calculator ===${NC}"
    echo
    
    echo -e "${BOLD}Model Costs (per 1M tokens):${NC}"
    echo "  ┌─────────────────────────────────┬──────────┬───────────┐"
    echo "  │ Model                           │ Input    │ Output    │"
    echo "  ├─────────────────────────────────┼──────────┼───────────┤"
    printf "  │ %-31s │ \$%-7.2f │ \$%-8.2f │\n" "DeepSeek V3 (Orchestrator)" 0.27 1.10
    printf "  │ %-31s │ \$%-7.2f │ \$%-8.2f │\n" "Claude Opus 4.5 (Planner)" 5.00 25.00
    printf "  │ %-31s │ \$%-7.2f │ \$%-8.2f │\n" "Gemini 3 Flash (Librarian)" 0.50 3.00
    printf "  │ %-31s │ \$%-7.2f │ \$%-8.2f │\n" "Llama 3.3 70B (Fallback)" 0.20 0.20
    echo "  └─────────────────────────────────┴──────────┴───────────┘"
    echo
    
    echo -e "${BOLD}Usage Scenarios:${NC}"
    echo
    
    # Scenario 1: DeepSeek V3 Ultrawork session
    echo "  ${BOLD}1. DeepSeek V3 Ultrawork Session (50 iterations)${NC}"
    echo "     Context: 50k tokens average"
    echo "     Output: ~15k tokens (code/logs)"
    local ds_input_cost=$(echo "scale=4; 50 * 0.05 * 0.27" | bc)
    local ds_output_cost=$(echo "scale=4; 0.015 * 1.10" | bc)
    local ds_total=$(echo "scale=2; $ds_input_cost + $ds_output_cost" | bc)
    echo "     Cost: \$${ds_total} USD per session"
    echo "     ${GREEN}Budget allows: ~$(echo "scale=0; $WORK_BUDGET_USD / $ds_total" | bc) sessions/month${NC}"
    echo
    
    # Scenario 2: Claude Opus spike
    echo "  ${BOLD}2. Claude Opus 4.5 Planning Session${NC}"
    echo "     Context: 50k tokens"
    echo "     Output: ~2k tokens (plan)"
    local opus_input_cost=$(echo "scale=4; 0.05 * 5.00" | bc)
    local opus_output_cost=$(echo "scale=4; 0.002 * 25.00" | bc)
    local opus_total=$(echo "scale=2; $opus_input_cost + $opus_output_cost" | bc)
    echo "     Cost: \$${opus_total} USD per session"
    echo "     ${YELLOW}Budget allows: ~$(echo "scale=0; $WORK_BUDGET_USD / $opus_total" | bc) sessions/month${NC}"
    echo "     ${RED}WARNING: 10 iterations with Opus = \$$(echo "scale=2; $opus_total * 10" | bc) USD!${NC}"
    echo
    
    # Scenario 3: Librarian bulk read
    echo "  ${BOLD}3. Gemini Librarian Bulk Ingestion${NC}"
    echo "     Context: 2M tokens (large docs folder)"
    echo "     Output: ~1k tokens (summary)"
    local lib_input_cost=$(echo "scale=4; 2 * 0.50" | bc)
    local lib_output_cost=$(echo "scale=4; 0.001 * 3.00" | bc)
    local lib_total=$(echo "scale=2; $lib_input_cost + $lib_output_cost" | bc)
    echo "     Cost: \$${lib_total} USD per read"
    echo "     ${YELLOW}Budget allows: ~$(echo "scale=0; $WORK_BUDGET_USD / $lib_total" | bc) bulk reads/month${NC}"
    echo
    
    # Scenario 4: Retry storm
    echo "  ${BOLD}4. Retry Storm (10 parallel agents)${NC}"
    echo "     Context: 30k tokens each"
    echo "     Output: minimal"
    local storm_cost=$(echo "scale=4; 10 * 0.03 * 0.27" | bc)
    echo "     Cost: \$${storm_cost} USD per storm"
    echo "     ${YELLOW}Low cost per incident, but can cascade rapidly${NC}"
    echo
    
    echo -e "${BOLD}Daily Budget Recommendations:${NC}"
    local daily_work=$(echo "scale=2; $WORK_BUDGET_USD / 20" | bc)
    local daily_personal=$(echo "scale=2; $PERSONAL_BUDGET_USD / 10" | bc)
    echo "  Work (20 days/month):     \$$daily_work USD/day"
    echo "  Personal (10 days/month): \$$daily_personal USD/day"
}

# Show instructions for setting limits
setup_limits() {
    echo -e "${BOLD}${BLUE}=== OpenRouter Credit Limit Setup ===${NC}"
    echo
    
    echo -e "${BOLD}Why Set Credit Limits?${NC}"
    echo "  Hard credit limits are the ONLY guaranteed way to prevent"
    echo "  budget overruns from runaway agent loops or retry storms."
    echo "  Application-level controls (max_tokens, max_iterations) can fail."
    echo
    
    echo -e "${BOLD}Step 1: Access OpenRouter Dashboard${NC}"
    echo "  1. Go to: https://openrouter.ai/settings/credits"
    echo "  2. Log in with your account"
    echo
    
    echo -e "${BOLD}Step 2: Create Budget-Limited API Keys${NC}"
    echo "  Navigate to: https://openrouter.ai/settings/keys"
    echo
    echo "  Recommended setup (dual-key strategy):"
    echo
    echo "  ${GREEN}Work Key:${NC}"
    echo "    - Name: sovereign-agent-work"
    echo "    - Credit Limit: \$45.00 USD"
    echo "    - Use for: Client projects, professional work"
    echo
    echo "  ${GREEN}Personal Key:${NC}"
    echo "    - Name: sovereign-agent-personal"
    echo "    - Credit Limit: \$19.00 USD"
    echo "    - Use for: Side projects, learning"
    echo
    
    echo -e "${BOLD}Step 3: Configure Key in Sovereign Agent${NC}"
    echo "  Option A: Environment variable"
    echo "    export OPENROUTER_API_KEY=sk-or-v1-your-work-key"
    echo
    echo "  Option B: config.json"
    echo "    Update 'openrouter_api_key' in config.json"
    echo
    echo "  Option C: Separate configs"
    echo "    ./install.sh --config work-config.json"
    echo "    ./install.sh --config personal-config.json"
    echo
    
    echo -e "${BOLD}Step 4: Enable Usage Alerts (Recommended)${NC}"
    echo "  In OpenRouter settings, enable email alerts for:"
    echo "    - 50% budget consumed"
    echo "    - 80% budget consumed"
    echo "    - 100% budget consumed (key disabled)"
    echo
    
    echo -e "${BOLD}Additional Protections in Sovereign Agent:${NC}"
    echo "  Already configured by install.sh:"
    echo "    - max_tokens caps per model (prevents context bloat)"
    echo "    - Opus Lock (human confirmation for expensive model)"
    echo "    - auto_recover: false (prevents retry storms)"
    echo "    - allow_fallbacks: false (no surprise routing)"
    echo
    
    echo -e "${YELLOW}IMPORTANT: OpenRouter credit limits are the ultimate safety net.${NC}"
    echo -e "${YELLOW}Set them lower than your actual budget to leave a buffer.${NC}"
}

# Continuous monitoring
monitor_usage() {
    local interval="${1:-60}"  # Default: check every 60 seconds
    
    echo -e "${BOLD}${BLUE}=== Continuous Usage Monitor ===${NC}"
    echo "Checking every $interval seconds. Press Ctrl+C to stop."
    echo
    
    local last_usage=0
    
    while true; do
        local stats
        stats=$(get_usage_stats 2>/dev/null) || {
            log_error "Failed to fetch stats"
            sleep "$interval"
            continue
        }
        
        local usage
        local limit
        usage=$(echo "$stats" | jq -r '.data.usage // 0')
        limit=$(echo "$stats" | jq -r '.data.limit // "unlimited"')
        
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        local delta=""
        if [[ "$last_usage" != "0" ]]; then
            local diff
            diff=$(echo "$usage - $last_usage" | bc 2>/dev/null || echo "0")
            if (( $(echo "$diff > 0" | bc -l 2>/dev/null || echo 0) )); then
                delta=" (+\$${diff})"
            fi
        fi
        
        printf "[%s] Usage: \$%s%s / %s\n" "$timestamp" "$usage" "$delta" "$limit"
        
        # Alert on high usage
        if [[ "$limit" != "unlimited" && "$limit" != "null" ]]; then
            local pct
            pct=$(echo "scale=0; $usage / $limit * 100" | bc 2>/dev/null || echo "0")
            if (( pct > 90 )); then
                echo -e "  ${RED}CRITICAL: ${pct}% of budget used!${NC}"
            elif (( pct > 75 )); then
                echo -e "  ${YELLOW}WARNING: ${pct}% of budget used${NC}"
            fi
        fi
        
        last_usage="$usage"
        sleep "$interval"
    done
}

# Print usage
usage() {
    echo "Usage: $0 <command>"
    echo
    echo "Commands:"
    echo "  status        Show current usage and budget status"
    echo "  estimate      Show cost estimates for usage patterns"
    echo "  setup-limits  Instructions for setting OpenRouter credit limits"
    echo "  monitor [N]   Continuous monitoring (check every N seconds, default 60)"
    echo
    echo "Environment:"
    echo "  OPENROUTER_API_KEY   API key (or set in config.json)"
    echo
    echo "Budget Constraints:"
    echo "  Monthly: \$${MONTHLY_BUDGET_AUD} AUD (\$${MONTHLY_BUDGET_USD} USD)"
    echo "  Work:    \$${WORK_BUDGET_USD} USD (70%)"  
    echo "  Personal: \$${PERSONAL_BUDGET_USD} USD (30%)"
}

# Main
case "${1:-}" in
    status)
        show_status
        ;;
    estimate)
        estimate_costs
        ;;
    setup-limits|setup)
        setup_limits
        ;;
    monitor)
        monitor_usage "${2:-60}"
        ;;
    *)
        usage
        exit 1
        ;;
esac
