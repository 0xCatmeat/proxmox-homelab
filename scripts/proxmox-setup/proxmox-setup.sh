#!/usr/bin/env bash
set -euo pipefail

# Proxmox Host Setup Script v1.0
# https://github.com/0xCatmeat
#
# Usage:
#   sudo ./proxmox-setup.sh [options]
#
# Options:
#   --skip-community    Skip the community setup script
#   --skip-fail2ban     Skip Fail2Ban installation
#   --log               Keep log file even on success
#   --help              Show this help message

SCRIPT_NAME="proxmox-setup"
LOG_NAME="proxmox-setup.log"

# ----------------------------
# Configuration / flags
# ----------------------------
SKIP_COMMUNITY=0
SKIP_FAIL2BAN=0
FLAG_LOG=0

# ----------------------------
# Helper functions
# ----------------------------
usage() {
  cat <<'EOF'
Proxmox VE Setup Script

Usage:
  sudo ./proxmox-setup.sh [options]

Options:
  --skip-community    Skip the community setup script
  --skip-fail2ban     Skip Fail2Ban installation
  --log               Keep log file even on success
  --help              Show this help message

Examples:
  sudo ./proxmox-setup.sh
  sudo ./proxmox-setup.sh --skip-community
  sudo ./proxmox-setup.sh --skip-fail2ban
  sudo ./proxmox-setup.sh --log

What this script does:
  1. Optionally runs the Proxmox community setup script (interactive)
  2. Optionally installs and configures Fail2Ban for SSH protection

Notes:
  - The community script is downloaded from GitHub, previewed (first 30 lines),
    and requires explicit y/N confirmation before execution.
  - This script continues execution even if a step fails, and reports failures
    at the end.

EOF
}

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "[$SCRIPT_NAME] ERROR: This script must be run as root (use sudo)."
    exit 1
  fi
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

# ----------------------------
# Error handling
# ----------------------------
FAILED_STEPS=()
FAILED_CODES=()

record_failure() {
  local step="$1"
  local code="$2"
  FAILED_STEPS+=("$step")
  FAILED_CODES+=("$code")
  log_banner "ERROR: Step failed: $step (exit $code)"
  log_banner "Continuing execution."
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

run_step_sh() {
  local step="$1"
  local cmd="$2"
  step_banner "$step"

  set +e
  bash -c "$cmd"
  local rc=$?
  set -e

  if (( rc != 0 )); then
    record_failure "$step" "$rc"
  fi

  return 0
}

# ----------------------------
# Checks
# ----------------------------
check_proxmox() {
  if [[ ! -f /etc/pve/.version ]]; then
    log_banner "ERROR: This does not appear to be a Proxmox VE system (/etc/pve/.version not found)."
    return 1
  fi
  log_banner "Proxmox VE detected"
  return 0
}

check_network_for_github() {
  # Only required for the community script phase.
  if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    log_banner "ERROR: No internet connectivity detected (ping failed)."
    return 1
  fi

  if ! curl -fsSL --connect-timeout 5 https://raw.githubusercontent.com >/dev/null 2>&1; then
    log_banner "ERROR: Cannot reach raw.githubusercontent.com (required to download community script)."
    return 1
  fi

  log_banner "Network connectivity verified (GitHub reachable)"
  return 0
}

# ----------------------------
# Community script phase
# ----------------------------
run_community_script() {
  local script_url="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh"
  local temp_script=""

  if ! check_network_for_github; then
    return 1
  fi

  temp_script="$(mktemp "/tmp/${SCRIPT_NAME}.community.XXXXXX.sh")" || {
    log_banner "ERROR: Failed to create temporary file."
    return 1
  }

  log_banner "Downloading community script: $script_url"
  if ! curl -fsSL "$script_url" -o "$temp_script"; then
    log_banner "ERROR: Failed to download community script."
    rm -f "$temp_script"
    return 1
  fi

  echo
  echo "========================================="
  echo "Community Script Preview"
  echo "========================================="
  head -n 30 "$temp_script"
  echo "========================================="
  echo
  echo "Script URL: $script_url"
  echo
  echo "Recommended selections inside the community script:"
  echo "  - Disable Enterprise Repo: Yes (unless subscribed)"
  echo "  - Enable No-Subscription Repo: Yes"
  echo "  - Disable Subscription Nag: Yes"
  echo "  - Update Proxmox VE: Yes"
  echo

  read -p "Proceed with running this community script? [y/N]: " confirm
  confirm="${confirm:-N}"
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_banner "Community script execution cancelled by user."
    rm -f "$temp_script"
    return 0
  fi

  log_banner "Running community script (interactive)..."
  set +e
  bash "$temp_script"
  local rc=$?
  set -e

  rm -f "$temp_script"

  if (( rc == 0 )); then
    log_banner "Community setup script completed successfully."
    return 0
  fi

  log_banner "ERROR: Community setup script failed (exit $rc)."
  return "$rc"
}

# ----------------------------
# Fail2Ban configuration
# ----------------------------
install_fail2ban() {
  log_banner "Installing Fail2Ban (if needed)..."

  if command -v fail2ban-server >/dev/null 2>&1; then
    log_banner "Fail2Ban already installed: $(fail2ban-server --version | head -n1 || true)"
  else
    DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban || return 1
    log_banner "Fail2Ban installed"
  fi

  log_banner "Configuring Fail2Ban SSH jail..."
  local jail_file="/etc/fail2ban/jail.d/sshd.local"

  cat > "$jail_file" <<'EOF'
# Proxmox Setup - Fail2Ban SSH Jail Configuration
# Protects SSH from brute-force attacks

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
findtime = 10m
bantime = 1h
EOF

  log_banner "Jail written: $jail_file"

  log_banner "Enabling and starting Fail2Ban..."
  systemctl enable --now fail2ban || return 1

  # Reload to pick up jail changes.
  systemctl reload fail2ban >/dev/null 2>&1 || true
  sleep 1

  if systemctl is-active --quiet fail2ban; then
    log_banner "Fail2Ban is active"
  else
    log_banner "ERROR: Fail2Ban service is not running"
    return 1
  fi

  # Status output.
  echo
  log_banner "Fail2Ban SSH jail status:"
  fail2ban-client status sshd 2>/dev/null || log_banner "Warning: sshd jail status not available yet"
  echo

  return 0
}

# ----------------------------
# Completion reporting
# ----------------------------
show_completion_message() {
  local had_errors=0
  if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
    had_errors=1
  fi

  echo
  if [[ $had_errors -eq 0 ]]; then
    log_banner "========================================="
    log_banner "Proxmox Setup completed successfully!"
    log_banner "========================================="
  else
    log_banner "========================================="
    log_banner "Proxmox Setup finished with errors"
    log_banner "========================================="
    log_banner "${#FAILED_STEPS[@]} step(s) failed:"
    local i
    for i in "${!FAILED_STEPS[@]}"; do
      echo "  $((i+1))) ${FAILED_STEPS[$i]} (exit ${FAILED_CODES[$i]})"
    done
    echo
  fi

  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  if [[ -n "$ip" ]]; then
    log_banner "Proxmox web UI: https://${ip}:8006"
  else
    log_banner "Proxmox web UI: https://<proxmox-ip>:8006"
  fi

  echo
  log_banner "Next steps:"
  log_banner "  1. Verify Fail2Ban: systemctl status fail2ban"
  log_banner "  2. View bans/status: fail2ban-client status sshd"
  log_banner "  3. Consider additional hardening:"
  log_banner "     - Two-factor auth (Datacenter -> Permissions -> Two Factor)"
  log_banner "     - SSH keys, then disable password auth if desired"
  log_banner "     - Firewall review and management network isolation"
  log_banner "     - Backups and notifications"

  if [[ $SKIP_COMMUNITY -eq 0 ]]; then
    log_banner "Note: If Proxmox packages/kernel were updated, a reboot is recommended."
  fi
}

# ----------------------------
# Argument parsing
# ----------------------------
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-community)
        SKIP_COMMUNITY=1
        ;;
      --skip-fail2ban)
        SKIP_FAIL2BAN=1
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
  need_root
  parse_args "$@"

  local tmp_log
  tmp_log="$(mktemp "/tmp/${SCRIPT_NAME}.XXXXXX.log")"
  exec > >(tee -a "$tmp_log") 2>&1

  log_banner "========================================="
  log_banner "Proxmox VE Setup Script"
  log_banner "========================================="
  log_banner "Starting execution"
  log_banner "Flags: skip_community=$SKIP_COMMUNITY skip_fail2ban=$SKIP_FAIL2BAN log=$FLAG_LOG"
  echo

  run_step "Verify Proxmox VE host" check_proxmox

  if [[ $SKIP_COMMUNITY -eq 0 ]]; then
    run_step "Run community setup script (interactive)" run_community_script
  else
    step_banner "Skip community setup script"
    log_banner "Skipping (--skip-community flag used)"
  fi

  if [[ $SKIP_FAIL2BAN -eq 0 ]]; then
    run_step "Install and configure Fail2Ban" install_fail2ban
  else
    step_banner "Skip Fail2Ban installation"
    log_banner "Skipping (--skip-fail2ban flag used)"
  fi

  show_completion_message

  # Save log if requested or if errors occurred.
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

  # Exit non-zero if any steps failed.
  if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"