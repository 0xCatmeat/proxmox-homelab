#!/usr/bin/env bash
set -euo pipefail

# AI Development Tools Installer v1.0
# https://github.com/0xCatmeat/proxmox-homelab
#
# Usage:
#   ./ai-tools.sh [options]
#
# Options:
#   --claude-code    Install Claude Code
#   --gemini-cli     Install Gemini CLI
#   --codex          Install OpenAI Codex
#   --all            Install all three tools
#   --log            Keep log file even on success
#   --help           Show this help message

SCRIPT_NAME="ai-tools"
LOG_NAME="ai-tools.log"

# ----------------------------
# Configuration
# ----------------------------
FLAG_CLAUDE=0
FLAG_GEMINI=0
FLAG_CODEX=0
FLAG_LOG=0

REQUIRED_NODE_MAJOR=20
CODEX_NODE_MAJOR=22

# ----------------------------
# Helper functions
# ----------------------------
usage() {
  cat <<'EOF'
AI Development Tools Installer

Install AI-powered coding assistants that run in your terminal.

Usage:
  ./ai-tools.sh [options]

Options:
  --claude-code    Install Claude Code (Anthropic)
  --gemini-cli     Install Gemini CLI (Google)
  --codex          Install Codex (OpenAI)
  --all            Install all three tools
  --log            Keep log file even on success
  --help           Show this help message

Examples:
  ./ai-tools.sh                      # Interactive mode
  ./ai-tools.sh --all                # Install everything
  ./ai-tools.sh --claude-code        # Install only Claude Code
  ./ai-tools.sh --gemini-cli --log   # Install Gemini CLI, keep log

What these tools do:
  Claude Code   - Agentic coding assistant from Anthropic
  Gemini CLI    - Google's AI terminal assistant
  OpenAI Codex  - OpenAI's coding agent

Authentication:
  After installation, each tool requires authentication:
  - Claude Code: Run 'claude' and sign in with Claude Pro/Max or API key
  - Gemini CLI: Run 'gemini' and sign in with Google account or API key
  - OpenAI Codex: Run 'codex' and sign in with ChatGPT account or API key

Requirements:
  - Node.js 20+ for Gemini CLI (script can install via nvm if needed)
  - Node.js 22+ for Codex (script can install via nvm if needed)
  - Active internet connection
  - Non-root user (these are user-space tools)

EOF
}

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

log_banner() {
  echo "[$(timestamp)] [$SCRIPT_NAME] $*"
}

step_banner() {
  echo
  echo "[$(timestamp)] [STEP] $*"
}

source_nvm() {
  if check_nvm_installed; then
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh" 2>/dev/null || true
  fi
}

# ----------------------------
# Error handling
# ----------------------------
FAILED_STEPS=()
FAILED_CODES=()
SKIPPED_STEPS=()

record_failure() {
  local step="$1"
  local code="$2"
  FAILED_STEPS+=("$step")
  FAILED_CODES+=("$code")
  log_banner "ERROR: Step failed: $step (exit $code)"
  log_banner "Continuing execution."
}

record_skip() {
  local step="$1"
  SKIPPED_STEPS+=("$step")
  log_banner "Skipped: $step"
}

run_step() {
  local step="$1"
  shift
  step_banner "$step"

  set +e
  "$@"
  local rc=$?
  set -e
  
  if (( rc != 0 )); then
    record_failure "$step" "$rc"
  fi

  return 0
}

step_succeeded() {
  local step_name="$1"
  # If no failures, step succeeded
  if [[ ${#FAILED_STEPS[@]} -eq 0 ]]; then
    return 0
  fi
  # If step name not in failed list, it succeeded
  ! printf '%s\n' "${FAILED_STEPS[@]}" | grep -q "$step_name"
}

# ----------------------------
# Checks
# ----------------------------
check_not_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    log_banner "ERROR: Do not run this script as root."
    log_banner "These tools install in user space and should be run as a regular user."
    exit 1
  fi
}

check_node_version() {
  if ! command -v node >/dev/null 2>&1; then
    return 1
  fi

  local version
  version=$(node --version | sed 's/v//')
  local major
  major=$(echo "$version" | cut -d. -f1)

  if (( major >= REQUIRED_NODE_MAJOR )); then
    return 0
  else
    return 1
  fi
}

check_node_version_for_codex() {
  if ! command -v node >/dev/null 2>&1; then
    return 1
  fi

  local version
  version=$(node --version | sed 's/v//')
  local major
  major=$(echo "$version" | cut -d. -f1)

  if (( major >= CODEX_NODE_MAJOR )); then
    return 0
  else
    return 1
  fi
}

check_nvm_installed() {
  if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    return 0
  else
    return 1
  fi
}

# ----------------------------
# Node.js installation
# ----------------------------
offer_nvm_installation() {
  local for_codex=${1:-0}
  
  echo
  echo "========================================="
  echo "   Node.js Required"
  echo "========================================="
  echo
  
  if [[ $for_codex -eq 1 ]]; then
    echo "Codex requires Node.js 22 or later."
    echo
    
    if check_node_version_for_codex; then
      log_banner "Node.js $(node --version) is already installed and meets requirements."
      return 0
    fi
    
    if command -v node >/dev/null 2>&1; then
      log_banner "Node.js $(node --version) is installed but too old (need v22+)."
    else
      log_banner "Node.js is not installed."
    fi
  else
    echo "Gemini CLI requires Node.js 20 or later."
    echo
    
    if check_node_version; then
      log_banner "Node.js $(node --version) is already installed and meets requirements."
      return 0
    fi

    if command -v node >/dev/null 2>&1; then
      log_banner "Node.js $(node --version) is installed but too old (need v20+)."
    else
      log_banner "Node.js is not installed."
    fi
  fi

  echo
  echo "Would you like to install Node.js using nvm (Node Version Manager)?"
  echo
  echo "nvm allows you to:"
  echo "  - Install the latest Node.js without conflicts"
  echo "  - Switch Node.js versions easily"
  echo "  - Install without needing sudo/root"
  echo
  read -p "Install Node.js via nvm? [Y/n]: " response
  response=${response:-Y}

  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    log_banner "Node.js installation declined by user"
    return 1
  fi

  install_nvm
  return $?
}

install_nvm() {
  log_banner "Installing nvm..."

  # Download and install nvm
  if ! curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash; then
    log_banner "ERROR: Failed to download nvm installer"
    return 1
  fi

  export NVM_DIR="$HOME/.nvm"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
  else
    log_banner "ERROR: nvm installation succeeded but nvm.sh not found"
    return 1
  fi

  log_banner "nvm installed successfully"
  
  # Install latest Node.js
  log_banner "Installing Node.js..."
  
  if ! nvm install --lts; then
    log_banner "ERROR: Failed to install Node.js"
    return 1
  fi

  if ! nvm use --lts; then
    log_banner "ERROR: Failed to activate Node.js"
    return 1
  fi

  # Verify installation
  if check_node_version; then
    log_banner "Node.js $(node --version) installed successfully"
    log_banner "npm $(npm --version) is available"
    return 0
  else
    log_banner "ERROR: Node.js installation verification failed"
    return 1
  fi
}

# ----------------------------
# Tool installation functions
# ----------------------------
install_claude_code() {
  log_banner "Installing Claude Code..."

  if command -v claude >/dev/null 2>&1; then
    local version
    version=$(claude --version 2>/dev/null || echo "unknown")
    log_banner "Claude Code is already installed (version: $version)"
    log_banner "Skipping installation"
    record_skip "Claude Code installation"
    return 0
  fi

  log_banner "Downloading and running Claude Code installer..."
  
  if ! curl -fsSL https://claude.ai/install.sh | bash; then
    log_banner "ERROR: Claude Code installation failed"
    return 1
  fi

  if [[ -f "$HOME/.bashrc" ]]; then
    source "$HOME/.bashrc" 2>/dev/null || true
  fi

  # Verify installation
  if command -v claude >/dev/null 2>&1; then
    local version
    version=$(claude --version 2>/dev/null || echo "installed")
    log_banner "Claude Code installed successfully (version: $version)"
    return 0
  else
    log_banner "WARNING: Claude Code may be installed but not in current PATH"
    log_banner "Try opening a new terminal or running: source ~/.bashrc"
    return 0
  fi
}

install_gemini_cli() {
  log_banner "Installing Gemini CLI..."

  if command -v gemini >/dev/null 2>&1; then
    local version
    version=$(gemini --version 2>/dev/null || echo "unknown")
    log_banner "Gemini CLI is already installed (version: $version)"
    log_banner "Skipping installation"
    record_skip "Gemini CLI installation"
    return 0
  fi

  # Check if nvm is installed
  source_nvm

  if ! check_node_version; then
    log_banner "ERROR: Node.js 20+ required but not available"
    return 1
  fi

  log_banner "Installing via npm (this may take a minute)..."

  if ! npm install -g @google/gemini-cli; then
    log_banner "ERROR: npm install failed"
    return 1
  fi

  # Verify installation
  if command -v gemini >/dev/null 2>&1; then
    local version
    version=$(gemini --version 2>/dev/null || echo "installed")
    log_banner "Gemini CLI installed successfully (version: $version)"
    return 0
  else
    log_banner "WARNING: Gemini CLI may be installed but not in current PATH"
    log_banner "Try opening a new terminal"
    return 0
  fi
}

install_codex() {
  log_banner "Installing Codex..."

  # Check if already installed
  if command -v codex >/dev/null 2>&1; then
    local version
    version=$(codex --version 2>/dev/null || echo "unknown")
    log_banner "Codex is already installed (version: $version)"
    log_banner "Skipping installation"
    record_skip "Codex installation"
    return 0
  fi

  source_nvm

  if ! check_node_version_for_codex; then
    log_banner "ERROR: Node.js 22+ required but not available"
    if command -v node >/dev/null 2>&1; then
      log_banner "Current version: $(node --version)"
      log_banner "Codex requires Node.js v22 or higher"
    fi
    return 1
  fi

  log_banner "Installing via npm (this may take a minute)..."

  if ! npm install -g @openai/codex; then
    log_banner "ERROR: npm install failed"
    return 1
  fi

  # Verify installation
  if command -v codex >/dev/null 2>&1; then
    local version
    version=$(codex --version 2>/dev/null || echo "installed")
    log_banner "Codex installed successfully (version: $version)"
    return 0
  else
    log_banner "WARNING: Codex may be installed but not in current PATH"
    log_banner "Try opening a new terminal"
    return 0
  fi
}

# ----------------------------
# Interactive mode
# ----------------------------
interactive_selection() {
  echo
  echo "========================================="
  echo "   AI Development Tools Installer"
  echo "========================================="
  echo
  echo "This script can install the following AI coding assistants:"
  echo
  echo "1. Claude Code (Anthropic)"
  echo "   - Agentic coding assistant"
  echo "   - Can run in terminal and IDE"
  echo "   - Requires: Claude Pro/Max subscription or API key"
  echo
  echo "2. Gemini CLI (Google)"
  echo "   - Free tier available with Google account"
  echo "   - Google's AI terminal assistant"
  echo "   - Requires: Node.js 20+"
  echo
  echo "3. Codex (OpenAI)"
  echo "   - OpenAI's terminal coding agent"
  echo "   - Can run in terminal and IDE"
  echo "   - Requires: Node.js 22+, ChatGPT Plus/Pro or API key"
  echo
  echo "========================================="
  echo
  
  read -p "Install Claude Code? [y/N]: " response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    FLAG_CLAUDE=1
  fi

  read -p "Install Gemini CLI? [y/N]: " response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    FLAG_GEMINI=1
  fi

  read -p "Install Codex? [y/N]: " response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    FLAG_CODEX=1
  fi

  # Check if user selected nothing
  if [[ $FLAG_CLAUDE -eq 0 && $FLAG_GEMINI -eq 0 && $FLAG_CODEX -eq 0 ]]; then
    log_banner "No tools selected for installation"
    exit 0
  fi
}

# ----------------------------
# Post-installation
# ----------------------------
show_completion_message() {
  local installed_count=0
  local had_errors=0

  if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
    had_errors=1
  fi

  if [[ $FLAG_CLAUDE -eq 1 ]] && step_succeeded "Claude Code"; then
    ((installed_count++)) || true
  fi
  if [[ $FLAG_GEMINI -eq 1 ]] && step_succeeded "Gemini CLI"; then
    ((installed_count++)) || true
  fi
  if [[ $FLAG_CODEX -eq 1 ]] && step_succeeded "Codex"; then
    ((installed_count++)) || true
  fi

  echo
  if [[ $had_errors -eq 0 && $installed_count -gt 0 ]]; then
    log_banner "========================================="
    log_banner "Installation completed successfully!"
    log_banner "========================================="
  elif [[ $had_errors -eq 1 ]]; then
    log_banner "========================================="
    log_banner "Installation finished with errors"
    log_banner "========================================="
    log_banner "${#FAILED_STEPS[@]} step(s) failed:"
    local i
    for i in "${!FAILED_STEPS[@]}"; do
      echo "  $((i+1))) ${FAILED_STEPS[$i]} (exit ${FAILED_CODES[$i]})"
    done
    echo
  fi

  if [[ ${#SKIPPED_STEPS[@]} -gt 0 ]]; then
    log_banner "Skipped steps:"
    for step in "${SKIPPED_STEPS[@]}"; do
      echo "  - $step"
    done
    echo
  fi

  if [[ $installed_count -eq 0 ]]; then
    log_banner "No new tools were installed"
    exit 0
  fi

  log_banner "Installed tools:"
  if [[ $FLAG_CLAUDE -eq 1 ]] && step_succeeded "Claude Code"; then
    echo "  - Claude Code"
  fi
  if [[ $FLAG_GEMINI -eq 1 ]] && step_succeeded "Gemini CLI"; then
    echo "  - Gemini CLI"
  fi
  if [[ $FLAG_CODEX -eq 1 ]] && step_succeeded "Codex"; then
    echo "  - Codex"
  fi
}

# ----------------------------
# Argument parsing
# ----------------------------
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --claude-code)
        FLAG_CLAUDE=1
        ;;
      --gemini-cli)
        FLAG_GEMINI=1
        ;;
      --codex)
        FLAG_CODEX=1
        ;;
      --all)
        FLAG_CLAUDE=1
        FLAG_GEMINI=1
        FLAG_CODEX=1
        ;;
      --log)
        FLAG_LOG=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "[$SCRIPT_NAME] ERROR: Unknown option: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

# ----------------------------
# Main execution
# ----------------------------
main() {
  check_not_root
  parse_args "$@"

  local tmp_log
  tmp_log="$(mktemp "/tmp/${SCRIPT_NAME}.XXXXXX.log")"
  exec > >(tee -a "$tmp_log") 2>&1

  log_banner "========================================="
  log_banner "AI Tools Installer"
  log_banner "========================================="
  log_banner "Starting installation"
  echo

  # Interactive mode if no flags are specified
  if [[ $FLAG_CLAUDE -eq 0 && $FLAG_GEMINI -eq 0 && $FLAG_CODEX -eq 0 ]]; then
    interactive_selection
  fi

  # Check Node.js requirements
  if [[ $FLAG_GEMINI -eq 1 || $FLAG_CODEX -eq 1 ]]; then
    if [[ $FLAG_CODEX -eq 1 ]]; then
      if ! check_node_version_for_codex; then
        if ! offer_nvm_installation 1; then
          log_banner "Node.js installation declined or failed"
          log_banner "Skipping tools that require Node.js 22+"
          
          if [[ $FLAG_CODEX -eq 1 ]]; then
            record_skip "Codex installation (Node.js 22+ not available)"
            FLAG_CODEX=0
          fi
        fi
      fi
    fi
    
    if [[ $FLAG_GEMINI -eq 1 && $FLAG_CODEX -eq 0 ]]; then
      if ! check_node_version; then
        if ! offer_nvm_installation 0; then
          log_banner "Node.js installation declined or failed"
          log_banner "Skipping Gemini CLI"
          record_skip "Gemini CLI installation (Node.js 20+ not available)"
          FLAG_GEMINI=0
        fi
      fi
    fi
  fi

  # Install selected tools
  if [[ $FLAG_CLAUDE -eq 1 ]]; then
    run_step "Install Claude Code" install_claude_code
  fi

  if [[ $FLAG_GEMINI -eq 1 ]]; then
    run_step "Install Gemini CLI" install_gemini_cli
  fi

  if [[ $FLAG_CODEX -eq 1 ]]; then
    run_step "Install Codex" install_codex
  fi

  show_completion_message

  # Save log if requested or if errors occurred
  local had_errors=0
  if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
    had_errors=1
  fi

  if [[ $FLAG_LOG -eq 1 || $had_errors -eq 1 ]]; then
    mv -f "$tmp_log" "./$LOG_NAME" 2>/dev/null || {
      cp -f "$tmp_log" "./$LOG_NAME" 2>/dev/null || true
      rm -f "$tmp_log"
    }
    log_banner "Log saved: ./$LOG_NAME"
  else
    rm -f "$tmp_log"
  fi
}

main "$@"