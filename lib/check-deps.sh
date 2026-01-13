#!/usr/bin/env bash
# check-deps.sh - Verify and install required dependencies

# Only set -e when run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -e
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENDOR_DIR="$PROJECT_DIR/vendor"

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

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check and install jq (required for JSON parsing)
check_jq() {
    if command_exists jq; then
        log_info "jq is already installed: $(jq --version)"
        return 0
    fi

    log_warn "jq is not installed. Attempting to install..."

    if command_exists apt-get; then
        sudo apt-get update && sudo apt-get install -y jq
    elif command_exists yum; then
        sudo yum install -y jq
    elif command_exists dnf; then
        sudo dnf install -y jq
    elif command_exists brew; then
        brew install jq
    elif command_exists pacman; then
        sudo pacman -S --noconfirm jq
    else
        log_error "Could not install jq. Please install it manually."
        return 1
    fi

    log_info "jq installed successfully"
}

# Check and install curl
check_curl() {
    if command_exists curl; then
        log_info "curl is already installed"
        return 0
    fi

    log_warn "curl is not installed. Attempting to install..."

    if command_exists apt-get; then
        sudo apt-get update && sudo apt-get install -y curl
    elif command_exists yum; then
        sudo yum install -y curl
    elif command_exists dnf; then
        sudo dnf install -y curl
    elif command_exists brew; then
        brew install curl
    elif command_exists pacman; then
        sudo pacman -S --noconfirm curl
    else
        log_error "Could not install curl. Please install it manually."
        return 1
    fi

    log_info "curl installed successfully"
}

# Check and install Go (required to build OpenCode)
check_go() {
    if command_exists go; then
        log_info "Go is already installed: $(go version)"
        return 0
    fi

    log_warn "Go is not installed. Attempting to install..."

    local go_version="1.23.4"
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) log_error "Unsupported architecture: $arch"; return 1 ;;
    esac

    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')

    local go_tar="go${go_version}.${os}-${arch}.tar.gz"
    local go_url="https://go.dev/dl/${go_tar}"

    log_info "Downloading Go ${go_version}..."
    curl -fsSL "$go_url" -o "/tmp/${go_tar}"

    log_info "Installing Go to /usr/local/go..."
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "/tmp/${go_tar}"
    rm "/tmp/${go_tar}"

    export PATH="/usr/local/go/bin:$PATH"

    if command_exists go; then
        log_info "Go installed successfully: $(go version)"
    else
        log_error "Go installation failed"
        return 1
    fi
}

# Check and install Bun
check_bun() {
    if command_exists bun; then
        log_info "Bun is already installed: $(bun --version)"
        return 0
    fi

    log_warn "Bun is not installed. Installing..."
    curl -fsSL https://bun.sh/install | bash

    # Add to path for current session
    if [[ -d "$HOME/.bun/bin" ]]; then
        export PATH="$HOME/.bun/bin:$PATH"
    fi

    if command_exists bun; then
        log_info "Bun installed successfully"
    else
        log_warn "Bun installed but may require a new terminal session"
    fi
}

# Build OpenCode from submodule
build_opencode() {
    local opencode_dir="$VENDOR_DIR/opencode"

    if [[ ! -d "$opencode_dir" ]]; then
        log_error "OpenCode submodule not found at $opencode_dir"
        log_error "Run: git submodule update --init --recursive"
        return 1
    fi

    log_info "Building OpenCode from source..."

    cd "$opencode_dir"

    # Check if already built
    if [[ -f "./opencode" ]]; then
        log_info "OpenCode binary already exists, rebuilding..."
    fi

    # Build
    go build -o opencode ./cmd/opencode

    # Install to ~/.local/bin
    mkdir -p "$HOME/.local/bin"
    cp opencode "$HOME/.local/bin/opencode"
    chmod +x "$HOME/.local/bin/opencode"

    export PATH="$HOME/.local/bin:$PATH"

    cd "$PROJECT_DIR"

    if command_exists opencode; then
        log_info "OpenCode built and installed successfully"
    else
        log_warn "OpenCode built but ~/.local/bin may not be in PATH"
    fi
}

# Build and install oh-my-opencode from submodule
build_oh_my_opencode() {
    local omo_dir="$VENDOR_DIR/oh-my-opencode"

    if [[ ! -d "$omo_dir" ]]; then
        log_error "oh-my-opencode submodule not found at $omo_dir"
        log_error "Run: git submodule update --init --recursive"
        return 1
    fi

    log_info "Installing oh-my-opencode from source..."

    # Ensure bun is in path
    if [[ -d "$HOME/.bun/bin" ]]; then
        export PATH="$HOME/.bun/bin:$PATH"
    fi

    if ! command_exists bun; then
        log_error "Bun is required but not found in PATH"
        return 1
    fi

    cd "$omo_dir"

    # Install dependencies
    bun install

    # Run the install script with our options
    bun run install --no-tui --claude=no --chatgpt=no --gemini=yes

    cd "$PROJECT_DIR"

    log_info "oh-my-opencode installed successfully"
}

# Main check function
check_all_deps() {
    log_info "Checking dependencies..."
    echo

    check_curl
    echo

    check_jq
    echo

    check_go
    echo

    check_bun
    echo

    build_opencode
    echo

    build_oh_my_opencode
    echo

    log_info "All dependencies checked/installed successfully"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_all_deps
fi
