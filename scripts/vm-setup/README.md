# VM Setup Scripts

Preconfiguration scripts for fresh Debian or Ubuntu installations into secure, well-configured VMs. Includes QEMU agent, SSH hardening, firewall configuration, and optional Docker installation.

> **Note**: This directory contains separate scripts for Ubuntu (`ubuntu-setup.sh`) and Debian (`debian-setup.sh`) due to OS-specific differences in package management and service configuration.

## What These Scripts Do

- Install QEMU guest agent for Proxmox integration
- Install essential server tools
- Harden SSH (disable root login, keep password auth)
- Configure UFW firewall with subnet restrictions
- Enable unattended security updates
- Apply system performance tweaks
- Optionally install Docker Engine

## Which Script Should I Use?

- **Ubuntu**: Use `ubuntu-setup.sh`
- **Debian**: Use `debian-setup.sh`

Both scripts provide the same functionality but are optimized for their respective distributions.

## Prerequisites

Before running these scripts, ensure:
- Fresh Debian or Ubuntu Server installation
- Root access or sudo privileges
- Active internet connection
- Know your network subnet (or let script auto-detect)

## Installation

### Download and Run

Clone the repository:
```bash
git clone https://github.com/0xCatmeat/proxmox-homelab.git
cd proxmox-homelab/scripts/vm-setup
chmod +x ubuntu-setup.sh  # or debian-setup.sh
```

Or download directly (Ubuntu):
```bash
wget https://raw.githubusercontent.com/0xCatmeat/proxmox-homelab/main/scripts/vm-setup/ubuntu-setup.sh
chmod +x ubuntu-setup.sh
```

Or download directly (Debian):
```bash
wget https://raw.githubusercontent.com/0xCatmeat/proxmox-homelab/main/scripts/vm-setup/debian-setup.sh
chmod +x debian-setup.sh
```

## Usage Examples

> **Note**: The following examples use `ubuntu-setup.sh`. For Debian, simply replace with `debian-setup.sh`.

### Basic usage (interactive, auto-detects subnet)
```bash
sudo ./ubuntu-setup.sh
```

### With UFW firewall (auto-detect subnet)
```bash
sudo ./ubuntu-setup.sh --ufw
```

### Specify subnet manually
```bash
sudo ./ubuntu-setup.sh --ufw --subnet 10.30.50.0/24
```

### With Docker
```bash
sudo ./ubuntu-setup.sh --docker
```

### With UFW and Docker
```bash
sudo ./ubuntu-setup.sh --ufw --docker
```

### Enable sudo password feedback
```bash
sudo ./ubuntu-setup.sh --pwfeedback
```

### Keep log file for review
```bash
sudo ./ubuntu-setup.sh --log
```

### Full options
```bash
sudo ./ubuntu-setup.sh --ufw --subnet 192.168.1.0/24 --docker --pwfeedback --log
```

### View help
```bash
sudo ./ubuntu-setup.sh --help
```

## Command Line Options

| Option | Description |
|--------|-------------|
| `--ufw` | Configure UFW firewall with subnet-restricted SSH access |
| `--subnet CIDR` | Manually specify subnet (e.g., `192.168.1.0/24`). Optional with `--ufw`: auto-detected if not provided |
| `--docker` | Install Docker Engine via official repository |
| `--pwfeedback` | Enable sudo password feedback (show `*` when typing password) |
| `--log` | Keep log file even on success |
| `--help` | Show help message |

## What to Expect During Installation

### Phase 1: Package Installation
The script will:
1. Wait for package manager locks to release (up to 10 minutes)
2. Update and upgrade all packages
3. Install baseline tools including Python 3 for network calculations

### Phase 2: Subnet Configuration (if `--ufw` flag used)
The script will:
1. Check if you provided `--subnet` flag
2. If not, attempt to auto-detect your network subnet using Python's ipaddress module
3. Prompt for confirmation or manual entry
4. Validate subnet format (CIDR notation)
5. Warn if subnet is overly broad (≤/16)

**Common subnet examples**:
- Home network: `192.168.1.0/24`
- Custom network: `10.x.x.0/24`

**Warning**: Very broad subnets like /8 or /16 allow SSH from millions of IPs. The script will warn you before proceeding.

### Phase 3: Core Setup
Fully automated. The script will:
1. Install and start QEMU guest agent
2. Harden SSH configuration using drop-in file
3. Enable automatic security updates
4. Apply system performance tweaks

**SSH Hardening Note**: Configuration is applied via `/etc/ssh/sshd_config.d/99-ubuntu-setup.conf` (Ubuntu) or `/etc/ssh/sshd_config.d/99-debian-setup.conf` (Debian). This keeps customizations separate from the main SSH config.

### Phase 4: UFW Configuration (if `--ufw` flag used)
Before enabling the firewall, the script shows:
- Exact rules being applied
- Your current LAN IP address
- Warning about potential lockout
- Requires explicit y/N confirmation

**Critical**: If your current IP is NOT in the specified subnet, you will lose SSH access when the firewall is enabled. The script provides this warning before proceeding.

### Phase 5: Optional Features
If flags are provided:
- `--docker`: Installs Docker Engine via official apt repository
- `--pwfeedback`: Shows asterisks when typing sudo password
- `--log`: Keeps detailed log file after completion

**Docker Installation Note**: Uses official Docker repository method (not get.docker.com script) for better security and auditability.

### Phase 6: Completion Summary
The script displays:
- Configuration summary
- Next steps
- Any failed steps (script continues even with errors)
- Log file location (if saved)

## After Installation

### 1. Verify Services

Check QEMU agent:
```bash
systemctl status qemu-guest-agent
```

Check firewall status (if UFW was enabled):
```bash
sudo ufw status
```

Verify SSH configuration:
```bash
# Ubuntu
cat /etc/ssh/sshd_config.d/99-ubuntu-setup.conf

# Debian
cat /etc/ssh/sshd_config.d/99-debian-setup.conf
```

### 2. Test SSH Access

From another machine on your network:
```bash
ssh your_username@VM_IP
```

**Important**: Root login is now disabled. Use your regular user account.

### 3. Docker Setup (if installed)

Log out and back in (or reboot), then verify Docker is working:
```bash
docker --version
```
### 4. Recommended Next Steps

**Security**:
- [ ] Set up SSH key authentication
- [ ] Disable password authentication (after keys configured)
- [ ] Review UFW rules: `sudo ufw status numbered`
- [ ] Review SSH hardening config

**Proxmox Integration**:
- [ ] Verify VM shows IP in Proxmox web interface

## Troubleshooting

### Script Fails at Package Manager Locks
**Symptom**: Script times out waiting for apt locks

**Solution**:
- Wait for any background updates to complete
- Check running processes: `ps aux | grep apt`
- Reboot and try again: `sudo reboot`

### SSH Connection Refused After Hardening
**Symptom**: Cannot SSH into VM after script runs

**Check these**:
1. Verify you're connecting from correct subnet (if UFW enabled):
```bash
ip addr show
```

2. Try from Proxmox console directly

3. Check SSH service status:
```bash
systemctl status sshd
```

4. Review SSH logs:
```bash
sudo journalctl -u ssh -n 50
```

5. Check SSH drop-in config:
```bash
# Ubuntu
cat /etc/ssh/sshd_config.d/99-ubuntu-setup.conf

# Debian
cat /etc/ssh/sshd_config.d/99-debian-setup.conf
```

### UFW Blocks Everything
**Symptom**: Lost connection after UFW enabled

**Solution**:
- Access via Proxmox console
- Check rules: `sudo ufw status numbered`
- If needed, reset: `sudo ufw reset`
- Reconfigure with correct subnet

**Prevention**: The script shows a detailed confirmation dialog before enabling UFW. Always verify the subnet matches your network.

### Docker Permission Denied
**Symptom**: `permission denied while trying to connect to Docker daemon`

**Solution**:
- Log out completely and back in (group membership requires new session)
- Or reboot: `sudo reboot`
- Verify group membership: `groups`

### Auto-Detect Gets Wrong Subnet
**Symptom**: Script detects wrong network range

**Solution**:
- The script uses Python's ipaddress module for accurate detection on all CIDR ranges
- If still incorrect, run with manual subnet: `sudo ./ubuntu-setup.sh --ufw --subnet YOUR_SUBNET/24`
- Verify your network: `ip route`

### Broad Subnet Warning
**Symptom**: Script warns about /8 or /16 subnet

**Explanation**: 
- /24 = 254 IPs (typical home network)
- /16 = 65,536 IPs
- /8 = 16 million IPs
- /0 = entire internet (4.3 billion IPs)

**Action**: Confirm you intended this broad range, or specify a narrower subnet.

### Unattended Upgrades Warning
**Symptom**: Script reports warning about unattended-upgrades dry-run

**Impact**: This is typically a transient issue and doesn't prevent automatic security updates from working. The configuration has been written and the service is enabled.

**Solution**:
1. Check logs: `sudo journalctl -u unattended-upgrades -n 50`
2. Verify configuration: `sudo unattended-upgrade --dry-run --debug`
3. Check for configuration issues in `/etc/apt/apt.conf.d/`

The warning indicates a temporary validation issue (mirror sync, network timing, etc.) but updates will still run on schedule.

## Understanding the Script's Safety Mechanisms

- **Error handling**: Script continues even if individual steps fail, tracking failures for final report
- **Package installation order**: Installs python3 before subnet detection to ensure accurate network calculations
- **SSH configuration**: Uses drop-in file to avoid conflicts with system updates
- **UFW confirmation**: Explicit warning and confirmation before enabling firewall, displays current IP
- **Subnet validation**: Validates format (octets 0-255, CIDR 0-32) and warns on overly broad ranges
- **Service verification**: Confirms services actually running before marking step as complete
- **Lock detection**: Waits up to 10 minutes for package manager locks before timing out
- **Configuration testing**: SSH config tested with `sshd -t` before restart to prevent lockouts
- **Graceful failures**: Individual step failures don't stop execution; all failures reported at end

## Advanced Usage

### Review Failed Steps
If script completes with errors, check the log:
```bash
# Ubuntu
cat ubuntu-setup.log

# Debian
cat debian-setup.log
```

The log is automatically saved when errors occur, even without the `--log` flag.

### Modify SSH Hardening
The SSH hardening configuration can be customized after installation:
```bash
# Ubuntu
sudo nano /etc/ssh/sshd_config.d/99-ubuntu-setup.conf

# Debian
sudo nano /etc/ssh/sshd_config.d/99-debian-setup.conf

# Then restart SSH
sudo systemctl restart sshd
```

To revert SSH hardening entirely:
```bash
# Ubuntu
sudo rm /etc/ssh/sshd_config.d/99-ubuntu-setup.conf

# Debian
sudo rm /etc/ssh/sshd_config.d/99-debian-setup.conf

# Then restart SSH
sudo systemctl restart sshd
```

### Add Additional UFW Rules
After setup, add more firewall rules as needed:
```bash
# Allow HTTP from anywhere
sudo ufw allow 80/tcp

# Allow HTTPS from anywhere
sudo ufw allow 443/tcp

# Allow specific port from specific IP
sudo ufw allow from 192.168.1.100 to any port 8080

# Allow specific port from entire subnet
sudo ufw allow from 192.168.1.0/24 to any port 3000
```

## Configuration Details

### Installed Packages

**Both Ubuntu and Debian**:
- **Networking**: curl, wget, dnsutils, iputils-ping, net-tools
- **Editors**: vim
- **Monitoring**: btop
- **Compression**: zip, unzip, p7zip-full
- **Security**: openssh-server, ufw (if `--ufw` flag used)
- **System**: ca-certificates, gnupg, qemu-guest-agent, python3
- **Utilities**: git, psmisc

**Ubuntu only**:
- **System**: software-properties-common

### System Tweaks Applied
Configuration file: `/etc/sysctl.d/99-script-tweaks.conf`
- Increased inotify limits for file watchers
  - `fs.inotify.max_user_instances=1024`
  - `fs.inotify.max_user_watches=524288`
- Reduced swappiness (prefer RAM over swap)
  - `vm.swappiness=10`

### SSH Hardening
**Ubuntu**: `/etc/ssh/sshd_config.d/99-ubuntu-setup.conf`  
**Debian**: `/etc/ssh/sshd_config.d/99-debian-setup.conf`

Configuration:
- Root login disabled (`PermitRootLogin no`)
- Public key authentication enabled (`PubkeyAuthentication yes`)
- Password authentication kept enabled (`PasswordAuthentication yes`)
- Additional hardening options available (commented out in config file)

### UFW Rules (if `--ufw` flag used)
- Default: Deny all incoming
- Default: Allow all outgoing
- SSH (port 22) allowed from specified subnet only

### Docker Installation (if `--docker` flag used)
When Docker is installed:
- Adds Docker's official GPG key to `/etc/apt/keyrings/docker.asc`
- Configures Docker's official apt repository
- Installs: docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin
- Adds current user to docker group
- Starts and enables Docker service

## Security Notes

### Why Drop-in Files for SSH?
The scripts use `/etc/ssh/sshd_config.d/` instead of modifying the main `sshd_config` file:
- **Clean separation**: Your changes are isolated from system defaults
- **Update-safe**: Survives SSH package updates
- **Easy to review**: Single file contains all hardening changes
- **Reversible**: Simply delete the file to revert

### Why Official Docker Repository?
The scripts use Docker's official apt repository instead of the `get.docker.com` convenience script:
- **Auditable**: Package sources are explicit and verifiable
- **Reproducible**: Same installation method every time
- **Secure**: GPG-signed packages from trusted source
- **Professional**: Standard practice for production systems
- **Educational**: Shows the proper way to add third-party repositories

### Subnet Security
- Home networks will typically use /24 (192.168.1.0/24 or 10.0.0.0/24)
- Broader ranges like /16 or /8 may be needed for corporate networks
- Very broad ranges (/0-/8) should trigger extra caution
- Always verify the subnet before confirming UFW rules
- The script shows your current connection IP to help you verify

### UFW is Opt-In
UFW firewall configuration is **opt-in** via the `--ufw` flag. This design decision:
- Prevents accidental lockouts for users unfamiliar with firewalls
- Allows users to configure VMs locally before enabling restrictions
- Requires explicit understanding of firewall implications
- Provides educational value through the confirmation dialog

## Why Separate Scripts for Ubuntu and Debian?

While the scripts are very similar, they're maintained separately due to:
- Different OS-specific package behaviors
- Service configuration variations
- Different default installed tools
- OS-specific troubleshooting requirements

This ensures each script is optimized and tested for its target distribution without conditional complexity.

## Related Resources

- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [UFW Documentation](https://help.ubuntu.com/community/UFW)
- [Docker Documentation](https://docs.docker.com/)
- [SSH Hardening Guide](https://www.ssh.com/academy/ssh/config)
- [Official Ubuntu Documentation](https://help.ubuntu.com/)
- [Debian Administrator's Handbook](https://debian-handbook.info/)

## Contributing

Found a bug or have a suggestion? Please open an issue or submit a pull request on GitHub.
