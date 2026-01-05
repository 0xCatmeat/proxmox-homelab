#!/usr/bin/env bash
set -euo pipefail

# Ubuntu Setup Script v1.0
# https://github.com/0xCatmeat

# Usage:
#   sudo ./ubuntu-setup.sh [options]
#
# Options:
#   --subnet CIDR      Manually specify subnet (e.g., 192.168.1.0/24)
#                      Optional with --ufw: Auto-detected if not provided
#   --docker           Install Docker Engine
#   --pwfeedback       Enable sudo password feedback (show * when typing)
#   --log              Keep log file even on success
#   --help             Show this help message

SCRIPT_NAME="ubuntu-setup"
LOG_NAME="ubuntu-setup.log"

# ----------------------------
# Configuration
# ----------------------------
SUBNET=""
FLAG_DOCKER=0
FLAG_PWFEEDBACK=0
FLAG_UFW=0
FLAG_LOG=0

# ----------------------------
# Helper functions
# ----------------------------
usage() {
  cat <<'EOF'
Ubuntu Setup Script

Usage:
  sudo ./ubuntu-setup.sh [options]

Options:
  --subnet CIDR      Manually specify subnet (e.g., 192.168.1.0/24)
                     Optional with --ufw: Auto-detected if not provided
  --docker           Install Docker Engine
  --ufw              Configure UFW firewall with subnet restrictions
  --pwfeedback       Enable sudo password feedback
  --log              Keep log file even on success
  --help             Show this help message

Examples:
  sudo ./ubuntu-setup.sh
  sudo ./ubuntu-setup.sh --docker
  sudo ./ubuntu-setup.sh --ufw --subnet 192.168.1.0/24
  sudo ./ubuntu-setup.sh --docker --ufw --pwfeedback

What this script does:
  1. Installs QEMU guest agent (for Proxmox integration)
  2. Installs essential server tools
  3. Hardens SSH (disables root login)
  4. Enables unattended security updates
  5. Applies system performance tweaks
  6. Optionally configures UFW firewall (--ufw)
  7. Optionally installs Docker (--docker)

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
# APT lock handling
# ----------------------------
wait_for_apt_locks() {
  local timeout_secs=600
  local interval_secs=2
  local start
  start="$(date +%s)"

  local locks=(
    "/var/lib/dpkg/lock"
    "/var/lib/dpkg/lock-frontend"
    "/var/lib/apt/lists/lock"
    "/var/cache/apt/archives/lock"
  )

  if command -v fuser >/dev/null 2>&1; then
    while :; do
      local locked=0
      local lf
      for lf in "${locks[@]}"; do
        if fuser "$lf" >/dev/null 2>&1; then
          locked=1
          break
        fi
      done

      if [[ $locked -eq 0 ]]; then
        return 0
      fi

      local now
      now="$(date +%s)"
      if (( now - start >= timeout_secs )); then
        log_banner "Package manager locks held for too long."
        return 1
      fi

      log_banner "Waiting for package manager locks..."
      sleep "$interval_secs"
    done
  else
    log_banner "Lock detection utility not found... proceeding without checks."
    sleep 5
    return 0
  fi
}

# ----------------------------
# Network detection
# ----------------------------
auto_detect_subnet() {
  # Get the default route interface
  local interface
  interface=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
  
  if [[ -z "$interface" ]]; then
    log_banner "Warning: No default route found"
    return 1
  fi
  
  # Get the first IPv4 address on that interface
  local ip_cidr
  ip_cidr=$(ip -o -f inet addr show "$interface" | awk '{print $4}' | head -n1)
  
  if [[ -z "$ip_cidr" ]]; then
    log_banner "Warning: No IPv4 address found on $interface"
    return 1
  fi
  
  # Use Python to calculate the network address
  if ! command -v python3 >/dev/null 2>&1; then
    log_banner "Error: python3 not found (required for subnet calculation)"
    return 1
  fi
  
  local network
  network=$(python3 -c "import ipaddress; print(ipaddress.ip_network('$ip_cidr', strict=False))" 2>/dev/null)
  
  if [[ -z "$network" ]]; then
    log_banner "Error: Failed to calculate network from $ip_cidr"
    return 1
  fi
  
  echo "$network"
  return 0
}

validate_subnet() {
  local subnet="$1"
  
  # Extract IP and CIDR using regex
  if [[ ! "$subnet" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})/([0-9]{1,2})$ ]]; then
    return 1
  fi
  
  local octet1="${BASH_REMATCH[1]}"
  local octet2="${BASH_REMATCH[2]}"
  local octet3="${BASH_REMATCH[3]}"
  local octet4="${BASH_REMATCH[4]}"
  local cidr="${BASH_REMATCH[5]}"
  
  # Validate octets are 0-255
  for octet in "$octet1" "$octet2" "$octet3" "$octet4"; do
    if (( octet > 255 )); then
      return 1
    fi
  done
  
  # Validate CIDR is 0-32
  if (( cidr > 32 )); then
    return 1
  fi
  
  return 0
}

warn_broad_subnet() {
  local subnet="$1"
  local cidr="${subnet##*/}"
  
  # Warn on very broad ranges
  if (( cidr <= 16 )); then
    echo ""
    echo "   WARNING: This is a very broad subnet (/$cidr)"
    echo "   This allows SSH from a large number of IP addresses."
    echo "   Examples:"
    echo "     /0  = Entire internet (4.3 billion IPs)"
    echo "     /8  = 16 million IPs"
    echo "     /16 = 65,536 IPs"
    echo "     /24 = 254 IPs (typical home network)"
    echo ""
    read -p "Are you sure you want to use $subnet? [y/N]: " confirm
    confirm=${confirm:-N}
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      return 1
    fi
  fi
  return 0
}

configure_subnet() {
  # If subnet was provided via flag, validate and use it
  if [[ -n "$SUBNET" ]]; then
    if validate_subnet "$SUBNET"; then
      if warn_broad_subnet "$SUBNET"; then
        log_banner "Using provided subnet: $SUBNET"
        return 0
      else
        log_banner "Subnet rejected by user"
        exit 1
      fi
    else
      log_banner "ERROR: Invalid subnet format: $SUBNET"
      log_banner "Expected format: 192.168.1.0/24"
      log_banner "Octets must be 0-255, CIDR must be 0-32"
      exit 1
    fi
  fi
  
  # Try auto-detection
  local detected_subnet
  detected_subnet=$(auto_detect_subnet)
  
  if [[ -n "$detected_subnet" ]]; then
    log_banner "Auto-detected subnet: $detected_subnet"
    
    # Ask user to confirm or override
    read -p "Use this subnet for SSH firewall rule? [Y/n]: " confirm
    confirm=${confirm:-Y}
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      if warn_broad_subnet "$detected_subnet"; then
        SUBNET="$detected_subnet"
        log_banner "Using subnet: $SUBNET"
        return 0
      fi
    fi
  else
    log_banner "Could not auto-detect network subnet."
  fi
  
  # If auto-detection failed or user declined, prompt manually
  while true; do
    read -p "Enter your network subnet (e.g., 192.168.1.0/24): " SUBNET
    
    if validate_subnet "$SUBNET"; then
      if warn_broad_subnet "$SUBNET"; then
        log_banner "Using subnet: $SUBNET"
        break
      fi
    else
      echo "Invalid format. Please use CIDR notation like: 192.168.1.0/24"
      echo "Octets must be 0-255, CIDR must be 0-32"
    fi
  done
}

# ----------------------------
# Core setup functions
# ----------------------------
install_qemu_agent() {
  log_banner "Installing QEMU guest agent for Proxmox integration..."
  apt-get install -y qemu-guest-agent || return 1
  
  # Try to enable and start (may fail on static units, which is OK)
  systemctl enable qemu-guest-agent 2>/dev/null || true
  systemctl start qemu-guest-agent 2>/dev/null || true
  
  # Verify it's running
  if systemctl is-active --quiet qemu-guest-agent; then
    log_banner "QEMU guest agent installed and running"
  else
    log_banner "QEMU guest agent installed (static unit or manual start required)"
    log_banner "This is normal on some systems - agent will start on next boot"
  fi
  return 0
}

install_baseline_packages() {
  log_banner "Installing baseline packages..."
  
  local pkgs=(
    curl wget git ca-certificates gnupg
    software-properties-common btop net-tools
    vim openssh-server zip unzip p7zip-full
    dnsutils iputils-ping psmisc python3
  )
  
  DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}" || return 1
  log_banner "Baseline packages installed"
  return 0
}

harden_ssh() {
  log_banner "Hardening SSH configuration..."
  
  local dropin_dir="/etc/ssh/sshd_config.d"
  local dropin_file="${dropin_dir}/99-ubuntu-setup.conf"
  
  # Create drop-in directory if it doesn't exist
  mkdir -p "$dropin_dir" || return 1
  
  # Create the hardening configuration drop-in file
  cat > "$dropin_file" <<'EOF'
# Ubuntu Setup - SSH Hardening Configuration
# This file is managed by ubuntu-setup script

# Disable root login - use sudo with regular user account
PermitRootLogin no

# Enable public key authentication
PubkeyAuthentication yes

# Keep password authentication enabled (disable after setting up keys)
PasswordAuthentication yes

# Optional additional hardening (uncomment to enable):
# MaxAuthTries 3
# MaxSessions 2
# LoginGraceTime 30
EOF
  
  log_banner "SSH hardening configuration written to $dropin_file"
  
  # Ensure host keys exist before validation (prevents common fresh-install failures)
  ssh-keygen -A >/dev/null 2>&1 || true

  # Ensure runtime directory exists
  install -d -m 0755 /run/sshd
  
  # Test configuration before restarting
  local err
  err="$(sshd -t 2>&1)" || {
    log_banner "ERROR: SSH configuration test failed:"
    echo "$err"
    rm -f "$dropin_file"
    return 1
  }

  if systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null; then
    log_banner "SSH hardened: root login disabled, password auth enabled"
    log_banner "Configuration file: $dropin_file"
    return 0
  fi

  log_banner "ERROR: Failed to restart SSH service"
  rm -f "$dropin_file"
  return 1
}

install_ufw() {
  log_banner "Installing UFW firewall..."
  
  if command -v ufw >/dev/null 2>&1; then
    log_banner "UFW is already installed"
  else
    if apt-get install -y ufw; then
      log_banner "UFW installed successfully"
    else
      log_banner "ERROR: Failed to install UFW"
      return 1
    fi
  fi
  
  return 0
}

configure_ufw() {
  log_banner "Configuring UFW firewall..."
  
  # Display exactly what we're about to do
  echo ""
  echo "========================================="
  echo "   FIREWALL CONFIGURATION CONFIRMATION"
  echo "========================================="
  echo ""
  echo "UFW will be configured with these rules:"
  echo "  1. Default: DENY all incoming connections"
  echo "  2. Default: ALLOW all outgoing connections"
  echo "  3. ALLOW SSH (port 22) from: $SUBNET"
  echo ""
  echo "   WARNING: If your current IP is NOT in $SUBNET subnet,"
  echo "   you will lose SSH access when the firewall is enabled!"
  echo ""
  
  # Get current IP for comparison
  local current_ip
  current_ip=$(who am i | awk '{print $5}' | tr -d '()')
  if [[ -n "$current_ip" ]]; then
    echo "Your current connection IP: $current_ip"
    echo ""
  fi
  
  read -p "Proceed with firewall configuration? [y/N]: " confirm
  confirm=${confirm:-N}
  
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_banner "Firewall configuration cancelled by user"
    return 1
  fi
  
  echo ""
  log_banner "Applying firewall rules..."
  
  # Set defaults
  ufw --force reset >/dev/null 2>&1 || true
  ufw default deny incoming || return 1
  ufw default allow outgoing || return 1
  
  # Allow SSH from specified subnet only
  log_banner "Adding rule: allow from $SUBNET to any port 22 proto tcp"
  ufw allow from "$SUBNET" to any port 22 proto tcp || return 1
  
  # Enable firewall
  log_banner "Enabling firewall..."
  ufw --force enable || return 1
  
  # Verify firewall is active
  if ufw status | grep -q "Status: active"; then
    log_banner "UFW configured: SSH allowed from $SUBNET only"
  else
    log_banner "Warning: UFW enabled but status unclear"
  fi
  
  return 0
}

enable_unattended_upgrades() {
  log_banner "Enabling unattended security updates..."
  
  apt-get install -y unattended-upgrades || return 1
  
  cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

  systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true

  # Test configuration but don't fail if dry-run has issues
  if ! unattended-upgrade --dry-run --debug >/dev/null 2>&1; then
    log_banner "Warning: unattended-upgrades dry-run reported issues"
    log_banner "This is often transient - automatic updates should still function"
  fi

  log_banner "Unattended security updates configured"
  return 0
}

apply_sysctl_tweaks() {
  log_banner "Applying system performance tweaks..."
  
  cat > /etc/sysctl.d/99-script-tweaks.conf <<'EOF'
# Increase inotify limits for file watchers
fs.inotify.max_user_instances=1024
fs.inotify.max_user_watches=524288

# Reduce swappiness (prefer RAM over swap)
vm.swappiness=10
EOF
  
  sysctl --system >/dev/null 2>&1 || return 1
  
  log_banner "System tweaks applied"
  return 0
}

# ----------------------------
# Optional features
# ----------------------------
enable_pwfeedback() {
  log_banner "Enabling sudo password feedback..."
  
  local dest="/etc/sudoers.d/${SCRIPT_NAME}-pwfeedback"
  local tmp
  tmp="$(mktemp "/tmp/${SCRIPT_NAME}.sudoers.XXXXXX")" || return 1

  printf "Defaults pwfeedback\n" > "$tmp" || { rm -f "$tmp"; return 1; }

  if command -v visudo >/dev/null 2>&1; then
    visudo -cf "$tmp" >/dev/null 2>&1 || { 
      log_banner "ERROR: Sudoers validation failed"
      rm -f "$tmp"
      return 1
    }
  fi

  install -m 0440 "$tmp" "$dest" || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"
  
  log_banner "Sudo password feedback enabled"
  return 0
}

install_docker() {
  log_banner "Installing Docker Engine via official repository..."
  
  # Detect OS for correct Docker repository
  local os_id
  os_id=$(. /etc/os-release && echo "$ID")
  
  # Validate supported OS
  if [[ "$os_id" != "ubuntu" ]]; then
    log_banner "ERROR: Docker installation in this script only supports Ubuntu"
    log_banner "Detected OS: $os_id"
    return 1
  fi
  
  local version_codename
  version_codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
  
  log_banner "Detected Ubuntu $version_codename"
  
  # Add Docker's official GPG key
  install -m 0755 -d /etc/apt/keyrings || return 1
  if ! curl -fsSL "https://download.docker.com/linux/${os_id}/gpg" -o /etc/apt/keyrings/docker.asc; then
    log_banner "ERROR: Failed to download Docker GPG key"
    return 1
  fi
  chmod a+r /etc/apt/keyrings/docker.asc || return 1
  
  # Add the repository to Apt sources
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${os_id} \
    ${version_codename} stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
  
  # Update package lists - this will fail if Docker doesn't support this Ubuntu version
  if ! apt-get update 2>/dev/null; then
    log_banner "ERROR: Docker repository update failed"
    log_banner "Docker may not support Ubuntu ${version_codename} yet"
    log_banner "Check https://docs.docker.com/engine/install/ubuntu/ for supported versions"
    return 1
  fi

  if ! apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
    log_banner "ERROR: Failed to install Docker packages"
    return 1
  fi
  
  log_banner "Docker packages installed successfully"

  if ! systemctl is-active --quiet docker; then
    log_banner "Starting Docker service..."
    if ! systemctl start docker; then
      log_banner "ERROR: Failed to start Docker service"
      return 1
    fi
  fi

  if docker --version >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version)
    log_banner "Docker installed: $DOCKER_VERSION"
  else
    log_banner "Warning: Docker installed but version check failed"
  fi

  local target_user="${SUDO_USER:-}"
  if [[ -n "$target_user" && "$target_user" != "root" ]]; then
    if usermod -aG docker "$target_user"; then
      log_banner "User $target_user added to docker group"
      log_banner "Note: Log out and back in (or reboot) to use docker without sudo"
    else
      log_banner "Warning: Failed to add user to docker group"
    fi
  fi

  log_banner "Docker Engine installation completed"
  return 0
}

# ----------------------------
# Cleanup and reporting
# ----------------------------
show_completion_message() {
  local had_errors=0
  if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
    had_errors=1
  fi

  echo
  if [[ $had_errors -eq 0 ]]; then
    log_banner "========================================="
    log_banner "Ubuntu Setup completed successfully!"
    log_banner "========================================="
  else
    log_banner "========================================="
    log_banner "Ubuntu Setup finished with errors"
    log_banner "========================================="
    log_banner "${#FAILED_STEPS[@]} step(s) failed:"
    local i
    for i in "${!FAILED_STEPS[@]}"; do
      echo "  $((i+1))) ${FAILED_STEPS[$i]} (exit ${FAILED_CODES[$i]})"
    done
    echo
  fi
  
  log_banner "Configuration summary:"
  log_banner "  - QEMU guest agent: Installed"
  log_banner "  - SSH: Root login disabled, password auth enabled"
  log_banner "  - SSH config: /etc/ssh/sshd_config.d/99-ubuntu-setup.conf"
  
  if [[ $FLAG_UFW -eq 1 ]]; then
    log_banner "  - Firewall: SSH allowed from $SUBNET only"
  fi
  
  log_banner "  - Security updates: Enabled (automatic)"
  
  if [[ $FLAG_DOCKER -eq 1 ]]; then
    log_banner "  - Docker: Installed via official repository"
  fi
  
  if [[ $FLAG_PWFEEDBACK -eq 1 ]]; then
    log_banner "  - Sudo feedback: Enabled"
  fi
  
  echo
  log_banner "Next steps:"

  if [[ $FLAG_UFW -eq 1 ]]; then
    log_banner "  1. Verify UFW status: sudo ufw status"
    log_banner "  2. Test SSH access from your network"
    log_banner "  3. Check QEMU agent: systemctl status qemu-guest-agent"
  
    if [[ $FLAG_DOCKER -eq 1 && -n "${SUDO_USER:-}" ]]; then
      log_banner "  4. Log out and back in to use docker without sudo"
    fi
  else
   log_banner "  1. Test SSH access from your network"
   log_banner "  2. Check QEMU agent: systemctl status qemu-guest-agent"
  
   if [[ $FLAG_DOCKER -eq 1 && -n "${SUDO_USER:-}" ]]; then
      log_banner "  3. Log out and back in to use docker without sudo"
    fi
  fi
}

# ----------------------------
# Argument parsing
# ----------------------------
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --subnet)
        shift
        [[ $# -gt 0 ]] || { echo "ERROR: --subnet requires a value"; exit 1; }
        SUBNET="$1"
        ;;
      --docker)
        FLAG_DOCKER=1
        ;;
      --pwfeedback)
        FLAG_PWFEEDBACK=1
        ;;
      --ufw)
        FLAG_UFW=1
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
  log_banner "Ubuntu Setup Script"
  log_banner "========================================="
  log_banner "Starting execution"
  log_banner "Flags: docker=$FLAG_DOCKER pwfeedback=$FLAG_PWFEEDBACK ufw=$FLAG_UFW log=$FLAG_LOG"
  echo

  # Core setup steps
  run_step "Wait for package manager locks" wait_for_apt_locks
  run_step_sh "Update package lists" "apt-get update"
  run_step_sh "Upgrade installed packages" "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"

  # Install essentials
  run_step "Install baseline packages" install_baseline_packages
  run_step "Install QEMU guest agent" install_qemu_agent

  # Security hardening
  run_step "Harden SSH configuration" harden_ssh
  run_step "Enable unattended security updates" enable_unattended_upgrades
  run_step "Apply system performance tweaks" apply_sysctl_tweaks

  # Optional features
  if [[ $FLAG_UFW -eq 1 ]]; then
    configure_subnet
    run_step "Install UFW firewall" install_ufw
    run_step "Configure UFW firewall" configure_ufw
  fi

  if [[ $FLAG_PWFEEDBACK -eq 1 ]]; then
    run_step "Enable sudo password feedback" enable_pwfeedback
  fi

  if [[ $FLAG_DOCKER -eq 1 ]]; then
    run_step "Install Docker Engine" install_docker
  fi

  # Cleanup
  run_step_sh "Remove unused packages" "DEBIAN_FRONTEND=noninteractive apt-get autoremove -y"
  run_step_sh "Clean package cache" "apt-get clean"
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