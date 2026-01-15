#!/usr/bin/env bash
# install.sh - Sovereign Agent Installer
# Sets up OpenCode with Sovereign Relay (GitHub Copilot backend)

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
    echo -e "${BOLD}  GitHub Copilot Relay${NC}"
    echo -e "  Privacy-compliant agentic software engineering"
    echo
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -s, --skip-deps      Skip dependency installation"
    echo "  -h, --help           Show this help message"
    echo
}

# Parse command line arguments
SKIP_DEPS=false

while [[ $# -gt 0 ]]; do
    case $1 in
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

install_opencode() {
    log_info "Building and installing OpenCode..."
    
    cd "$VENDOR_DIR/opencode"
    
    # Install dependencies
    if ! bun install --frozen-lockfile 2>/dev/null; then
        log_warn "bun install --frozen-lockfile failed, trying without frozen lockfile"
        bun install
    fi
    
    # Build and link
    bun run build 2>/dev/null || true
    
    # Install globally
    if bun link 2>/dev/null; then
        log_info "OpenCode linked globally"
    else
        # Fallback: add to PATH via .bashrc
        local bin_path="$VENDOR_DIR/opencode/packages/opencode"
        if [[ -f "$bin_path/dist/cli.js" ]]; then
            echo "export PATH=\"$bin_path:\$PATH\"" >> "$HOME/.bashrc"
            log_info "Added OpenCode to PATH in .bashrc"
        fi
    fi
    
    cd "$SCRIPT_DIR"
}

copy_agents() {
    log_info "Setting up OpenAgents..."
    
    local opencode_dir="$HOME/.config/opencode"
    local agents_src="$VENDOR_DIR/OpenAgents/.opencode"
    
    # Create directory structure
    mkdir -p "$opencode_dir/.opencode"
    
    # Copy agent files if they exist
    if [[ -d "$agents_src/agent" ]]; then
        cp -r "$agents_src/agent" "$opencode_dir/.opencode/"
        log_info "Copied agent definitions"
    fi
    
    if [[ -d "$agents_src/command" ]]; then
        cp -r "$agents_src/command" "$opencode_dir/.opencode/"
        log_info "Copied command definitions"
    fi
    
    if [[ -d "$agents_src/context" ]]; then
        cp -r "$agents_src/context" "$opencode_dir/.opencode/"
        log_info "Copied context files"
    fi
}

main() {
    print_banner

    # Step 1: Ensure submodules are initialized
    log_header "Step 1: Checking Submodules"
    check_submodules
    log_info "Submodules ready"

    # Step 2: Check/install dependencies
    if [[ "$SKIP_DEPS" == "false" ]]; then
        log_header "Step 2: Installing Dependencies"
        
        if [[ -f "$LIB_DIR/check-deps.sh" ]]; then
            source "$LIB_DIR/check-deps.sh"
            check_all_deps
        else
            # Minimal dependency check
            if ! command -v bun &>/dev/null; then
                log_error "Bun is required but not installed"
                log_info "Install with: curl -fsSL https://bun.sh/install | bash"
                exit 1
            fi
            if ! command -v go &>/dev/null; then
                log_warn "Go is recommended for full functionality"
            fi
        fi
    else
        log_header "Step 2: Skipping Dependency Installation"
        log_warn "Skipping dependency installation (--skip-deps flag)"
    fi

    # Step 3: Install OpenCode
    log_header "Step 3: Installing OpenCode"
    install_opencode

    # Step 4: Copy OpenAgents
    log_header "Step 4: Setting Up Agents"
    copy_agents

    # Step 5: Final summary
    log_header "Installation Complete!"

    echo -e "${GREEN}Sovereign Agent has been configured successfully.${NC}"
    echo
    echo -e "${BOLD}Backend:${NC} GitHub Copilot (via Sovereign Relay)"
    echo
    echo -e "${BOLD}Config location:${NC}"
    echo "  - $HOME/.config/opencode/opencode.jsonc"
    echo "  - $HOME/.config/opencode/.opencode/ (agents, commands)"
    echo
    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Start a new shell session: ${BOLD}exec \$SHELL${NC}"
    echo "  2. Navigate to your project directory"
    echo "  3. Run: ${BOLD}opencode${NC}"
    echo
    echo -e "${BOLD}Model selection:${NC}"
    echo "  Use /models in OpenCode to switch between models"
    echo "  Default: gpt-5-mini (FREE - unlimited use)"
    echo
}

# Run main
main
