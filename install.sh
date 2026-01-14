#!/usr/bin/env bash
# install.sh - Sovereign Agent Installer
# Sets up the OpenCode with OpenAgents orchestration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
VENDOR_DIR="$SCRIPT_DIR/vendor"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
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

log_header() {
    echo
    echo -e "${BLUE}${BOLD}========================================${NC}"
    echo -e "${BLUE}${BOLD}  $1${NC}"
    echo -e "${BLUE}${BOLD}========================================${NC}"
    echo
}

print_banner() {
    echo -e "${BOLD}"
    echo '  ____                          _                _                    _   '
    echo ' / ___|  _____   _____ _ __ ___(_) __ _ _ __    / \   __ _  ___ _ __ | |_ '
    echo ' \___ \ / _ \ \ / / _ \  __/ _ \ |/ _` |  _ \  / _ \ / _` |/ _ \  _ \| __|'
    echo '  ___) | (_) \ V /  __/ | |  __/ | (_| | | | |/ ___ \ (_| |  __/ | | | |_ '
    echo ' |____/ \___/ \_/ \___|_|  \___|_|\__, |_| |_/_/   \_\__, |\___|_| |_|\__|'
    echo '                                  |___/             |___/                 '
    echo -e "${NC}"
    echo -e "${BOLD}  OpenAgents Pipeline Installer${NC}"
    echo -e "  Privacy-compliant agentic software engineering"
    echo
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -c, --config FILE    Path to config.json (default: ./config.json)"
    echo "  -d, --dest DIR       OpenCode config directory (default: ~/.config/opencode)"
    echo "  -s, --skip-deps      Skip dependency installation"
    echo "  -h, --help           Show this help message"
    echo
    echo "Example:"
    echo "  $0 --config my-config.json"
    echo
}

# Parse command line arguments
CONFIG_FILE="$SCRIPT_DIR/config.json"
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
SKIP_DEPS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -d|--dest)
            OPENCODE_CONFIG_DIR="$2"
            shift 2
            ;;
        -s|--skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Make config path absolute
if [[ ! "$CONFIG_FILE" = /* ]]; then
    CONFIG_FILE="$SCRIPT_DIR/$CONFIG_FILE"
fi

check_submodules() {
    # Skip if not a git repo (e.g., when installed from bundle)
    if [[ ! -d "$SCRIPT_DIR/.git" ]]; then
        log_info "Not a git repo - skipping submodule check"
        # Verify vendor directories exist (should be included in bundle)
        if [[ ! -d "$VENDOR_DIR/opencode" ]] || [[ ! -d "$VENDOR_DIR/OpenAgents" ]]; then
            log_error "Vendor directories missing. If installed from bundle, the bundle may be incomplete."
            exit 1
        fi
        return
    fi
    
    if [[ ! -d "$VENDOR_DIR/opencode/.git" ]] || [[ ! -d "$VENDOR_DIR/OpenAgents/.git" ]]; then
        log_info "Initializing git submodules..."
        git -C "$SCRIPT_DIR" submodule update --init --recursive
    fi
}

main() {
    print_banner

    # Step 0: Ensure submodules are initialized
    log_header "Step 0: Checking Submodules"
    check_submodules
    log_info "Submodules ready"

    # Step 1: Validate config
    log_header "Step 1: Validating Configuration"
    
    source "$LIB_DIR/validate.sh"
    if ! validate_config "$CONFIG_FILE"; then
        log_error "Configuration validation failed. Please fix the errors above."
        exit 1
    fi

    # Step 2: Check/install dependencies
    if [[ "$SKIP_DEPS" == "false" ]]; then
        log_header "Step 2: Installing Dependencies"
        
        source "$LIB_DIR/check-deps.sh"
        check_all_deps
    else
        log_header "Step 2: Skipping Dependency Installation"
        log_warn "Skipping dependency installation (--skip-deps flag)"
    fi

    # Step 3: Generate config files
    log_header "Step 3: Generating Configuration Files"
    
    source "$LIB_DIR/generate-configs.sh"
    generate_all_configs "$CONFIG_FILE" "$OPENCODE_CONFIG_DIR"

    # Step 4: Final summary
    log_header "Installation Complete!"

    local tier
    tier=$(jq -r '.tier // "frugal"' "$CONFIG_FILE")

    echo -e "${GREEN}The Sovereign Agent pipeline has been configured successfully.${NC}"
    echo
    echo -e "${BOLD}Generated files:${NC}"
    echo "  - $OPENCODE_CONFIG_DIR/opencode.jsonc"
    echo "  - $OPENCODE_CONFIG_DIR/dcp.jsonc"
    echo "  - $OPENCODE_CONFIG_DIR/.opencode/ (agents, commands, context)"
    echo
    echo -e "${BOLD}Tier: ${GREEN}$tier${NC}"
    echo
    echo -e "${BOLD}Privacy:${NC}"
    echo "  - Zero Data Retention (ZDR): ${GREEN}Enabled${NC}"
    echo "  - Provider: OpenRouter"
    echo
    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Start a new shell session: ${BOLD}exec \$SHELL${NC}"
    echo "  2. Navigate to your project directory"
    echo "  3. Run: ${BOLD}opencode${NC}"
    echo
    echo -e "${BOLD}Available agents:${NC}"
    echo "  - @openagent - Universal orchestrator"
    echo "  - @opencoder - Multi-language coding specialist"
    echo "  - @reviewer  - Code review and security"
    echo "  - @tester    - Test authoring with TDD"
    echo
}

# Run main
main
