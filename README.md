# Proxmox Homelab

Setup scripts and documentation for a Proxmox-based homelab environment. This repository contains automated, auditable setup scripts and detailed documentation for building a secure, repeatable, and production-style homelab.

## Overview

This project is designed to provide a clean baseline for:

- Proxmox VE hosts
- Debian and Ubuntu virtual machines
- Secure SSH access and network controls
- Optional Docker-based workloads
- Homelab environments that prioritize clarity, safety, and repeatability

All scripts are designed to be:

- Safe to re-run
- Explicit about changes
- Transparent before making risky modifications
- Easy to audit and revert

## Repository Structure

```
proxmox-homelab/
├── .gitignore
├── LICENSE
├── README.md
└── scripts/
    ├── cli-tools/
    │   └── ai-tools/
    │       ├── ai-tools.sh
    │       └── README.md
    ├── docker-compose/
    │   ├── admin-tools/
    │   │   ├── .env.example
    │   │   ├── docker-compose.yml
    │   │   └── README.md
    │   └── llm-chat/
    │       ├── .env.example
    │       ├── docker-compose.yml
    │       ├── README.md
    │       └── settings.yml
    ├── proxmox-setup/
    │   ├── proxmox-setup.sh
    │   └── README.md
    └── vm-setup/
        ├── debian-setup.sh
        ├── ubuntu-setup.sh
        └── README.md
```

## What This Project Does

### Proxmox Host Setup

**Location:** `scripts/proxmox-setup/proxmox-setup.sh`

Purpose:
- Establish a clean and secure Proxmox VE baseline
- Reduce noise from enterprise-only features
- Add basic SSH protection

Key features:
- Verifies the system is a Proxmox VE host before running
- Optionally runs the community-maintained Proxmox post-install script
- Previews the community script before execution and requires confirmation
- Optionally installs and configures Fail2Ban for SSH protection
- Tracks and reports failed steps without stopping execution

Important behavior:
- Skipping the community script or Fail2Ban is treated as intentional, not an error
- Designed to be safe to re-run
- Intended to be run on the Proxmox host itself, not inside a VM

See `scripts/proxmox-setup/README.md` for full details.

### VM Setup Scripts (Debian and Ubuntu)

**Location:** `scripts/vm-setup/`

Separate scripts are maintained for Debian and Ubuntu to account for OS-specific differences without relying on conditional logic.

Scripts:
- `ubuntu-setup.sh`
- `debian-setup.sh`

Purpose:
- Provide a consistent, secure baseline for new VMs
- Integrate cleanly with Proxmox

Shared behavior across both scripts:
- Installs QEMU guest agent for Proxmox integration
- Installs a minimal, practical set of baseline packages
- Hardens SSH using drop-in configuration files
- Enables unattended security updates
- Applies small, safe system performance tweaks
- Continues execution even if individual steps fail
- Produces a clear completion summary and optional log file

Optional features (opt-in via flags):
- UFW firewall with subnet-restricted SSH access
- Docker Engine via the official Docker repository
- Sudo password feedback
- Persistent log file retention

See `scripts/vm-setup/README.md` for full usage examples and explanations.

### Admin Tools Stack

**Location:** `scripts/docker-compose/admin-tools/`

Purpose:
- Centralized administration and productivity tools
- Container monitoring and automated update checking
- Self-hosted password management
- Docker Compose stack management
- Developer utilities and PDF processing

Key features:
- Watchtower for container update monitoring
- Dockge web UI for managing Docker Compose stacks
- Vaultwarden for password management
- IT-Tools collection for developer utilities
- Stirling PDF for document processing

The stack requires Docker and Docker Compose.
See `scripts/docker-compose/admin-tools/README.md` for complete setup guide.

### LLM Chat Stack

**Location:** `scripts/docker-compose/llm-chat/`

Purpose:
- Provide a complete local AI workspace with privacy and control
- Run powerful language models on your own hardware
- Enable web search capabilities for AI responses
- Eliminate API costs and data sharing with cloud providers

Key features:
- Ollama for local LLM inference
- Lobe Chat as a modern web interface
- SearXNG for privacy-focused web search integration
- Valkey for search result caching
- Complete Docker Compose stack for easy deployment
- All data stays local on your machine

The stack requires having Docker installed.

See `scripts/docker-compose/llm-chat/README.md` for complete setup instructions and usage guide.

## Security Model and Design Choices

### SSH Hardening

- Root login is disabled
- Configuration is applied using `/etc/ssh/sshd_config.d/` drop-in files
- The main SSH configuration file is never modified
- Password authentication remains enabled by default for safety and initial access
- Additional hardening options are provided but commented out

### Firewall Configuration

- UFW is opt-in only
- Firewall rules are displayed before being applied
- SSH is restricted to a specific subnet when enabled
- Subnets are validated and auto-detected where possible
- Broad subnets trigger explicit warnings and confirmation prompts
- The script displays the current connection IP to help prevent lockouts

### Docker Installation

- Installed only when explicitly requested
- Uses Docker's official apt repository
- Avoids convenience scripts for better auditability
- Adds the invoking user to the docker group
- Does not assume immediate logout or reboot

### Error Handling

- Scripts do not abort on the first failure
- All failed steps are tracked and reported at the end
- Logs are automatically saved when failures occur
- This behavior is intentional to avoid partial configuration states

## Recommended Workflow

### New Proxmox Host

1. Install Proxmox VE
2. SSH or log in locally
3. Run `proxmox-setup.sh`
4. Review output and reboot if kernel or system packages were updated

### New Virtual Machine

1. Create VM in Proxmox
2. Install Debian or Ubuntu
3. SSH into the VM
4. Run the matching VM setup script
5. Enable firewall and Docker only when ready

## License

This project is open source and available under the MIT License.

## Notes

- These scripts were designed for homelab environments, not production enterprise systems
- Always review scripts before running them with root privileges
- Test in a non-critical environment first
- Backup important data before running any automation scripts
- Running them twice is safe, but you should still test them on a fresh install first.

## Related Resources

### Core Infrastructure
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [Proxmox Community Scripts](https://github.com/community-scripts/ProxmoxVE)
- [Docker Documentation](https://docs.docker.com/)

### Security & Hardening
- [UFW Documentation](https://help.ubuntu.com/community/UFW)
- [Fail2Ban Documentation](https://www.fail2ban.org/)
- [OpenSSH Guidelines](https://infosec.mozilla.org/guidelines/openssh)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)

### Self-Hosted Services
- [Watchtower](https://containrrr.dev/watchtower/)
- [Dockge](https://github.com/louislam/dockge)
- [Vaultwarden](https://github.com/dani-garcia/vaultwarden/wiki)
- [IT-Tools](https://github.com/CorentinTh/it-tools)
- [Stirling PDF](https://github.com/Stirling-Tools/Stirling-PDF)
- [Ollama](https://github.com/ollama/ollama)
- [Lobe Chat](https://github.com/lobehub/lobe-chat)
- [SearXNG](https://docs.searxng.org/)
- [Valkey](https://valkey.io/)

### AI Development Tools
- [Claude Code](https://code.claude.com/docs/en/overview)
- [Gemini CLI](https://geminicli.com/docs/)
- [OpenAI Codex](https://developers.openai.com/codex)

### Community Resources
- [Awesome-Selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted)
- [Awesome-Sysadmin](https://github.com/awesome-foss/awesome-sysadmin)
- [Awesome-Docker](https://github.com/veggiemonk/awesome-docker)
