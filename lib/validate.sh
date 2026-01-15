#!/usr/bin/env bash
# validate.sh - Validate user's config.json for Sovereign Agent

# Only set -e when run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -e
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate that config.json exists and has required fields
validate_config() {
    local config_file="$1"

    if [[ -z "$config_file" ]]; then
        log_error "No config file specified"
        return 1
    fi

    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        echo
        echo "Please create a config.json file. You can copy the example:"
        echo "  cp config.json.example config.json"
        return 1
    fi

    log_info "Validating config file: $config_file"

    # Check if file is valid JSON
    if ! jq empty "$config_file" 2>/dev/null; then
        log_error "Config file is not valid JSON"
        return 1
    fi

    local errors=0

    # Check relay configuration
    local relay_enabled
    local relay_mode
    relay_enabled=$(jq -r '.relay.enabled // false' "$config_file")
    relay_mode=$(jq -r '.relay.mode // empty' "$config_file")
    
    if [[ "$relay_enabled" == "true" ]]; then
        if [[ "$relay_mode" == "client" ]]; then
            log_info "Relay client mode - will connect to relay server"
            
            # Check relay port
            local relay_port
            relay_port=$(jq -r '.relay.port // empty' "$config_file")
            if [[ -z "$relay_port" ]]; then
                log_warn "relay.port not set, will use default: 8081"
            fi
        elif [[ "$relay_mode" == "server" ]]; then
            log_info "Relay server mode - will serve API requests"
            
            # Check for GitHub OAuth token (optional - can be added via /auth/device)
            local oauth_token
            oauth_token=$(jq -r '.github_oauth_token // empty' "$config_file")
            if [[ -z "$oauth_token" ]]; then
                log_warn "github_oauth_token not set - authenticate via /auth/device endpoint"
            fi
        else
            log_warn "relay.mode should be 'client' or 'server', got: $relay_mode"
        fi
    fi

    # Check for deprecated OpenRouter config
    local openrouter_key
    openrouter_key=$(jq -r '.openrouter_api_key // empty' "$config_file")
    if [[ -n "$openrouter_key" && "$openrouter_key" != "" ]]; then
        log_warn "openrouter_api_key is deprecated - Sovereign Agent now uses GitHub Copilot"
        log_warn "Remove openrouter_api_key and use /auth/device to authenticate with GitHub Copilot"
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Validation failed with $errors error(s)"
        return 1
    fi

    log_info "Config validation passed"
    return 0
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_config "$1"
fi
