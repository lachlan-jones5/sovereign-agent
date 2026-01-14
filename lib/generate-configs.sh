#!/usr/bin/env bash
# generate-configs.sh - Generate OpenCode config files from templates
#
# Generates tier-based config files for the OpenAgents system.
# Tiers: free, frugal (default), premium

# Only set -e when run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -e
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$PROJECT_DIR/templates"
VENDOR_DIR="$PROJECT_DIR/vendor"
OPENAGENTS_DIR="$VENDOR_DIR/OpenAgents"

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

# Extract values from config.json
# Note: handles boolean false correctly (jq's // operator treats false as falsy)
get_config_value() {
    local config_file="$1"
    local jq_path="$2"
    local default="$3"
    
    local value
    # Use if-then-else to properly handle false/null/missing values
    value=$(jq -r "if $jq_path == null then \"\" elif $jq_path == false then \"false\" else $jq_path end" "$config_file")
    
    if [[ -z "$value" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Generate a config file from a template
generate_from_template() {
    local template_file="$1"
    local output_file="$2"
    local config_file="$3"

    if [[ ! -f "$template_file" ]]; then
        log_error "Template file not found: $template_file"
        return 1
    fi

    # Read template
    local content
    content=$(cat "$template_file")

    # Extract config values
    local openrouter_api_key
    openrouter_api_key=$(get_config_value "$config_file" '.openrouter_api_key' '')
    
    local site_url
    site_url=$(get_config_value "$config_file" '.site_url' 'https://localhost')
    
    local site_name
    site_name=$(get_config_value "$config_file" '.site_name' 'SovereignAgent')
    
    local dcp_turn_protection
    dcp_turn_protection=$(get_config_value "$config_file" '.preferences.dcp_turn_protection' '2')
    
    local dcp_error_retention
    dcp_error_retention=$(get_config_value "$config_file" '.preferences.dcp_error_retention_turns' '4')
    
    local dcp_nudge_frequency
    dcp_nudge_frequency=$(get_config_value "$config_file" '.preferences.dcp_nudge_frequency' '10')

    # Plugin version pinning
    local pin_versions
    pin_versions=$(get_config_value "$config_file" '.plugins.pin_versions' 'true')
    
    local dcp_version
    if [[ "$pin_versions" == "true" ]]; then
        dcp_version=$(get_config_value "$config_file" '.plugins.opencode_dcp_version' '1.2.1')
    else
        dcp_version="latest"
    fi

    # Relay configuration
    local relay_enabled
    relay_enabled=$(get_config_value "$config_file" '.relay.enabled' 'false')
    
    local relay_mode
    relay_mode=$(get_config_value "$config_file" '.relay.mode' 'server')
    
    local relay_port
    relay_port=$(get_config_value "$config_file" '.relay.port' '8080')
    
    local relay_base_url
    if [[ "$relay_enabled" == "true" && "$relay_mode" == "client" ]]; then
        # Client mode: point at local relay tunnel
        # Note: OpenRouter SDK expects baseURL to include /api/v1
        relay_base_url="http://localhost:${relay_port}/api/v1"
    else
        # Server mode or disabled: use OpenRouter directly
        relay_base_url="https://openrouter.ai/api/v1"
    fi

    # Replace placeholders
    content="${content//\{\{OPENROUTER_API_KEY\}\}/$openrouter_api_key}"
    content="${content//\{\{SITE_URL\}\}/$site_url}"
    content="${content//\{\{SITE_NAME\}\}/$site_name}"
    content="${content//\{\{DCP_TURN_PROTECTION\}\}/$dcp_turn_protection}"
    content="${content//\{\{DCP_ERROR_RETENTION_TURNS\}\}/$dcp_error_retention}"
    content="${content//\{\{DCP_NUDGE_FREQUENCY\}\}/$dcp_nudge_frequency}"
    content="${content//\{\{DCP_VERSION\}\}/$dcp_version}"
    content="${content//\{\{RELAY_BASE_URL\}\}/$relay_base_url}"

    # Create output directory if needed
    local output_dir
    output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir"

    # Write output file
    echo "$content" > "$output_file"
    log_info "Generated: $output_file"
}

# Copy OpenAgents files to destination
copy_openagents_files() {
    local dest_dir="$1"
    local opencode_dir="$dest_dir/.opencode"
    
    if [[ ! -d "$OPENAGENTS_DIR/.opencode" ]]; then
        log_error "OpenAgents .opencode directory not found: $OPENAGENTS_DIR/.opencode"
        return 1
    fi
    
    # Create destination .opencode directory
    mkdir -p "$opencode_dir"
    
    # Copy agent files
    if [[ -d "$OPENAGENTS_DIR/.opencode/agent" ]]; then
        cp -r "$OPENAGENTS_DIR/.opencode/agent" "$opencode_dir/"
        log_info "Copied agents to $opencode_dir/agent"
    fi
    
    # Copy command files
    if [[ -d "$OPENAGENTS_DIR/.opencode/command" ]]; then
        cp -r "$OPENAGENTS_DIR/.opencode/command" "$opencode_dir/"
        log_info "Copied commands to $opencode_dir/command"
    fi
    
    # Copy context files
    if [[ -d "$OPENAGENTS_DIR/.opencode/context" ]]; then
        cp -r "$OPENAGENTS_DIR/.opencode/context" "$opencode_dir/"
        log_info "Copied context to $opencode_dir/context"
    fi
    
    # Copy skill files
    if [[ -d "$OPENAGENTS_DIR/.opencode/skill" ]]; then
        cp -r "$OPENAGENTS_DIR/.opencode/skill" "$opencode_dir/"
        log_info "Copied skills to $opencode_dir/skill"
    fi
    
    # Copy prompts files
    if [[ -d "$OPENAGENTS_DIR/.opencode/prompts" ]]; then
        cp -r "$OPENAGENTS_DIR/.opencode/prompts" "$opencode_dir/"
        log_info "Copied prompts to $opencode_dir/prompts"
    fi
}

# Generate all config files
generate_all_configs() {
    local config_file="$1"
    local opencode_config_dir="${2:-$HOME/.config/opencode}"

    if [[ -z "$config_file" ]]; then
        log_error "No config file specified"
        return 1
    fi

    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        return 1
    fi

    # Get the tier from config (default: frugal)
    local tier
    tier=$(get_config_value "$config_file" '.tier' 'frugal')
    
    # Validate tier
    case "$tier" in
        free|frugal|premium)
            log_info "Using tier: $tier"
            ;;
        *)
            log_warn "Unknown tier '$tier', defaulting to 'frugal'"
            tier="frugal"
            ;;
    esac

    log_info "Generating config files..."
    log_info "OpenCode config directory: $opencode_config_dir"
    echo

    # Create config directory
    mkdir -p "$opencode_config_dir"

    # Backup existing configs
    if [[ -f "$opencode_config_dir/opencode.jsonc" ]]; then
        local backup_file="$opencode_config_dir/opencode.jsonc.backup.$(date +%Y%m%d%H%M%S)"
        cp "$opencode_config_dir/opencode.jsonc" "$backup_file"
        log_warn "Backed up existing opencode.jsonc to $backup_file"
    fi

    if [[ -f "$opencode_config_dir/dcp.jsonc" ]]; then
        local backup_file="$opencode_config_dir/dcp.jsonc.backup.$(date +%Y%m%d%H%M%S)"
        cp "$opencode_config_dir/dcp.jsonc" "$backup_file"
        log_warn "Backed up existing dcp.jsonc to $backup_file"
    fi

    # Generate opencode.jsonc from tier template
    local tier_template="$TEMPLATES_DIR/opencode.${tier}.jsonc.tmpl"
    if [[ ! -f "$tier_template" ]]; then
        log_error "Tier template not found: $tier_template"
        return 1
    fi
    
    generate_from_template \
        "$tier_template" \
        "$opencode_config_dir/opencode.jsonc" \
        "$config_file"

    # Generate dcp.jsonc
    generate_from_template \
        "$TEMPLATES_DIR/dcp.jsonc.tmpl" \
        "$opencode_config_dir/dcp.jsonc" \
        "$config_file"

    # Copy OpenAgents files to config directory
    copy_openagents_files "$opencode_config_dir"

    # Copy .opencodeignore template to user's home directory
    if [[ -f "$TEMPLATES_DIR/opencodeignore.tmpl" ]]; then
        local opencodeignore_dest="$HOME/.opencodeignore"
        if [[ -f "$opencodeignore_dest" ]]; then
            local backup_file="$opencodeignore_dest.backup.$(date +%Y%m%d%H%M%S)"
            cp "$opencodeignore_dest" "$backup_file"
            log_warn "Backed up existing .opencodeignore to $backup_file"
        fi
        cp "$TEMPLATES_DIR/opencodeignore.tmpl" "$opencodeignore_dest"
        log_info "Generated: $opencodeignore_dest"
    fi

    echo
    log_info "All config files generated successfully"
    log_info "Tier: $tier"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    generate_all_configs "$1" "$2"
fi
