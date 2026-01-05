# Proxmox Host Setup (`proxmox-setup.sh`)

Automates the initial setup and baseline hardening of a fresh Proxmox VE host.
This script is designed to be safe, repeatable, and transparent, providing a consistent starting point for Proxmox homelab environments.

---

## What This Script Does

### 1. Proxmox Community Setup Script (Optional, Interactive)

Runs the community-maintained Proxmox helper script from the community-scripts project:
https://github.com/community-scripts/ProxmoxVE

What this does:
- Disables the Enterprise repository (unless you have a subscription)
- Enables the No-Subscription repository
- Disables the subscription nag popup
- Updates Proxmox packages and security fixes

How it works:
- Downloads to a temporary file first
- Shows you the first 30 lines before running
- Displays the source URL for verification
- Asks for explicit y/N confirmation

If you skip this step, it's treated as intentional, not a failure.

### 2. Fail2Ban Installation and SSH Protection (Optional)
Installs and configures Fail2Ban to protect SSH access to your Proxmox host.

What Fail2Ban does:
- Monitors SSH authentication logs in real-time
- Automatically bans IPs after repeated failed login attempts
- Protects against brute-force and automated attacks
- Logs all bans and events for review

SSH jail configuration:
- Location: /etc/fail2ban/jail.d/sshd.local
- 5 failed attempts allowed
- 10-minute detection window
- 1-hour ban duration
- Enabled and active immediately

This gives you predictable behavior instead of relying on distribution defaults.

## Prerequisites
Before running the script, you'll need:
- Fresh Proxmox VE installation
- Root access (local console or SSH)
- Active internet connection
- Basic shell familiarity

Run this script directly on the Proxmox host, not inside a VM.
## Installation

### Option A: Clone the Repository
```bash
cd ~
git clone https://github.com/0xCatmeat/proxmox-homelab.git
cd proxmox-homelab/scripts/proxmox-setup
chmod +x proxmox-setup.sh
```
### Option B: Download Only the Script
```bash
cd ~
wget https://raw.githubusercontent.com/0xCatmeat/proxmox-homelab/main/scripts/proxmox-setup/proxmox-setup.sh
chmod +x proxmox-setup.sh
```
## Usage

### Basic setup (recommended first run)
```bash
sudo ./proxmox-setup.sh
```

### Available options
```bash
sudo ./proxmox-setup.sh --help
```

| Option | Description |
|------|------------|
| --skip-community | Skip the community Proxmox setup script |
| --skip-fail2ban | Skip Fail2Ban installation and configuration |
| --log | Always save the log file, even on success |
| --help | Show usage information |

## After Setup

Access the Proxmox Web Interface:
```
https://YOUR_SERVER_IP:8006
```
## Recommended Next Steps
- Enable two-factor authentication
- Configure SSH key authentication
- Review firewall rules
- Set up backups
- Create VMs and apply VM base setup scripts
## Troubleshooting
The script is safe to run multiple times.
It detects already-installed components and skips them.
Use flags to skip steps you've already completed.
## Contributing
Issues and suggestions are welcome via GitHub.