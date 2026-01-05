# Admin Tools Stack

Essential administration and productivity tools for managing your homelab. This stack provides container monitoring, Docker Compose management, password management, developer utilities, and PDF processing to efficiently run and maintain your self-hosted environment.

## What This Stack Provides

**Watchtower** - Automated container update monitoring  
**Dockge** - Web UI for managing Docker Compose stacks  
**Vaultwarden** - Self-hosted password manager (Bitwarden compatible)  
**IT-Tools** - Collection of useful developer and admin utilities  
**Stirling PDF** - Self-hosted PDF tool

Benefits:
- No subscription costs
- Admin tools in one stack
- Everything runs locally on your network
- Monitor and update containers automatically
- Manage passwords securely without cloud providers
- Process PDFs without uploading to third-party services

## Prerequisites

Before deploying this stack:
- VM set up with the `vm-setup` scripts
- Docker installed (use `--docker` flag with `vm-setup` scripts)

## Quick Start

### 1. Create required directories
```bash
# Dockge requires this directory to store compose stacks
sudo mkdir -p /opt/stacks
sudo chown $USER:$USER /opt/stacks
```

### 2. Download the stack
```bash
git clone https://github.com/0xCatmeat/proxmox-homelab.git
cd proxmox-homelab/scripts/docker-compose/admin-tools
```

### 3. Review configuration (optional)
```bash
# Copy the environment file
cp .env.example .env

# Edit if needed
vim .env
```

Default configuration:
- Watchtower checks for updates daily (monitor-only mode)
- Dockge accessible on port 5001
- Vaultwarden accessible on port 8000 (signups enabled initially)
- IT-Tools accessible on port 8080
- Stirling PDF accessible on port 8082

### 4. Start the services
```bash
docker compose up -d
```

### 5. Access the tools

Open your browser and navigate to:

**Dockge**
```
http://YOUR_VM_IP:5001
```

**Vaultwarden**
```
http://YOUR_VM_IP:8000
```

**IT-Tools**
```
http://YOUR_VM_IP:8080
```

**Stirling PDF**
```
http://YOUR_VM_IP:8082
```

## Service Details

### Watchtower

Watchtower automatically monitors your Docker containers and checks for image updates.

**Default behavior:**
- Checks for updates every 24 hours
- Runs in monitor-only mode (logs updates but doesn't auto-apply)
- Cleans up old images after manual updates
- Monitors ALL containers on the host (not just this stack)

Why monitor-only mode is the recommended approach:
- You see what updates are available
- You control when updates happen
- Prevents unexpected breaking changes
- Review release notes before updating

If enabling auto-updates:
- Understand the risk of services breaking
- Test updates in development first
- Have backups ready
- Monitor logs regularly

**Check for available updates:**
```bash
docker logs admin-tools-watchtower
```

Look for messages like:
```
Found new image for container-name
```

**To enable auto-updates** (not recommended):

Edit `.env` and change:
```bash
WATCHTOWER_MONITOR_ONLY=false
```

Then restart:
```bash
docker compose restart watchtower
```

### Dockge

Dockge provides a modern web UI for managing Docker Compose stacks.

**Features:**
- Create/edit compose files through web interface
- Start/stop/restart stacks with one click
- View real-time logs
- Update container images
- Interactive terminal access
- Multi-stack management

**First-time setup:**
1. Access Dockge at `http://YOUR_VM_IP:5001`
2. The interface loads immediately (no account creation needed)
3. You'll see any existing stacks in `/opt/stacks`

**Creating a new stack:**
1. Click "Compose" button
2. Enter stack name
3. Write or paste your docker-compose.yml
4. Click "Deploy"

**Managing existing stacks:**

All your compose stacks stored in `/opt/stacks` appear in Dockge automatically. You can:
- Start/stop/restart stacks
- Edit compose files
- View logs
- Update images
- Access container terminals

**Important notes:**
- Dockge manages stacks in `/opt/stacks` only
- This directory must exist before starting Dockge
- The admin-tools stack itself won't appear in Dockge (it's not in `/opt/stacks`)
- Changes made in Dockge update the actual compose files on disk

### Vaultwarden

Vaultwarden is a lightweight, self-hosted Bitwarden server.

**First-time setup:**
1. Access Vaultwarden at `http://YOUR_VM_IP:8000`
2. Click "Create Account"
3. Enter email and master password
4. Your vault is now ready

WebSocket support is intentionally enabled to improve real-time sync for clients on the local network.

**After creating your account:**

For security, disable new signups:
```bash
# Edit .env
VAULTWARDEN_SIGNUPS_ALLOWED=false

# Restart Vaultwarden
docker compose restart vaultwarden
```

**Using the admin panel** (optional):

Generate an admin token:
```bash
openssl rand -base64 48
```

Add to `.env`:
```bash
VAULTWARDEN_ADMIN_TOKEN=your_generated_token_here
```

Restart and access admin panel:
```bash
docker compose restart vaultwarden
```

Navigate to: `http://YOUR_VM_IP:8000/admin`

**Browser extension:**

Install the official Bitwarden browser extension and point it to your Vaultwarden server:
- Server URL: `http://YOUR_VM_IP:8000`
- Use your Vaultwarden credentials

**Mobile apps:**

Official Bitwarden mobile apps work with Vaultwarden:
- Set custom server URL during setup
- Point to: `http://YOUR_VM_IP:8000`

**Backup your vault:**
```bash
# The vault database is in the vaultwarden-data volume
docker run --rm \
  -v admin-tools_vaultwarden-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/vaultwarden-backup.tar.gz /data
```

### IT-Tools

IT-Tools is a collection of handy utilities for developers and admins.

**Available tools include:**
- Token generator
- Hash calculator (MD5, SHA, etc.)
- Base64 encoder/decoder
- JSON formatter and validator
- UUID generator
- QR code generator
- Lorem ipsum generator
- Color converter
- Case converter
- And many more...

**Usage:**

Simply navigate to `http://YOUR_VM_IP:8080` and browse the available tools. All processing happens in your browser and nothing is sent to external servers.

### Stirling PDF

Stirling PDF provides comprehensive PDF manipulation tools.

**Available operations:**
- Merge multiple PDFs
- Split PDFs into separate files
- Rotate pages
- Compress PDFs
- Convert images to PDF
- Convert PDF to images
- Add/remove passwords
- Add watermarks
- OCR (extract text from images)
- And many more...

**Usage:**
1. Navigate to `http://YOUR_VM_IP:8082`
2. Select the operation you want to perform
3. Upload your PDF file(s)
4. Configure options
5. Download the processed file

**Enable authentication** (optional):
```bash
# Edit .env
STIRLINGPDF_SECURITY=true

# Restart Stirling PDF
docker compose restart stirling-pdf
```

## Configuration

### Environment Variables

Key settings in `.env`:

**WATCHTOWER_POLL_INTERVAL**
- How often to check for updates (in seconds)
- Default: 86400 (24 hours)
- Examples: 3600 (1 hour), 43200 (12 hours)

**WATCHTOWER_MONITOR_ONLY**
- When true: Only logs available updates
- When false: Automatically updates containers
- Default: true (recommended)

**DOCKGE_PORT**
- Web UI port for Dockge
- Default: 5001

**DOCKGE_STACKS_DIR**
- Directory where Dockge stores compose files
- Default: /opt/stacks

**VAULTWARDEN_PORT**
- Web vault port
- Default: 8000

**VAULTWARDEN_SIGNUPS_ALLOWED**
- Allow new user registrations
- Default: true
- Set to false after creating your account

**VAULTWARDEN_ADMIN_TOKEN**
- Token for accessing admin panel
- Generate with: `openssl rand -base64 48`
- Leave commented out to disable admin panel

**ITTOOLS_PORT**
- Web UI port for IT-Tools
- Default: 8080

**STIRLINGPDF_PORT**
- Web UI port for Stirling PDF
- Default: 8082

**STIRLINGPDF_SECURITY**
- Enable authentication for Stirling PDF
- Default: false

## Common Operations

### Stop the stack
```bash
docker compose down
```

### Restart the stack
```bash
docker compose restart
```

### Restart a specific service
```bash
docker compose restart dockge
docker compose restart vaultwarden
docker compose restart watchtower
```

### Update to latest images
```bash
docker compose pull
docker compose up -d
```

### View logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f watchtower
docker compose logs -f dockge
docker compose logs -f vaultwarden
docker compose logs -f it-tools
docker compose logs -f stirling-pdf
```

### Check resource usage
```bash
docker stats admin-tools-watchtower admin-tools-dockge admin-tools-vaultwarden admin-tools-ittools admin-tools-stirlingpdf
```

## Where Data Is Stored

**Dockge:**
- Application data: `dockge-data` Docker volume
- Compose stacks: `/opt/stacks` on host filesystem
- Both persist even if containers are removed

**Vaultwarden:**
- Vault database: `vaultwarden-data` Docker volume
- Includes all passwords, notes, and vault items
- Persists even if container is removed

**Stirling PDF:
- Configs: `stirlingpdf-configs` Docker volume
- No document storage (all processing is temporary)

**Watchtower:**
- No persistent storage

**IT-Tools:**
- No persistent storage

### View Volume Information

**List volumes:**
```bash
docker volume ls | grep admin-tools
```

**Inspect a volume:**
```bash
docker volume inspect admin-tools_vaultwarden-data
docker volume inspect admin-tools_dockge-data
```

**Check volume sizes:**
```bash
docker system df -v | grep admin-tools
```

## Security & Hardening

This stack is intended to run with a few security controls enabled out of the box, and others are left as explicit opt-in choices.

### Container-level hardening (default)

Most services in this stack run with `no-new-privileges:true` enabled:
- Prevents processes inside containers from gaining additional Linux privileges at runtime
- Reduces common post-exploit privilege escalation paths
- Applied to Vaultwarden, IT-Tools, Stirling PDF, and Watchtower

These settings do not prevent a compromised container from accessing what it is already allowed to access, but they help limit escalation and persistence inside the container.

Dockge intentionally does not use these restrictions due to Docker requiring socket access. Any container with Docker socket access effectively has host-level control, so additional in-container restrictions do not meaningfully reduce risk. Treat Dockge access as equivalent to root access on the Docker host.

### For local network access

If these tools are accessed from other devices on your network, additional restrictions are recommended.

1. **Disable Vaultwarden signups after initial setup**
``` bash
vim .env  # Set VAULTWARDEN_SIGNUPS_ALLOWED=false
docker compose restart vaultwarden
```
This prevents new accounts from being created once your primary user account exists.

2. **Restrict access with a firewall**
The examples below assume a `192.168.1.0/24` LAN. Replace this with your actual subnet:
``` bash
sudo ufw allow from 192.168.1.0/24 to any port 5001  # Dockge
sudo ufw allow from 192.168.1.0/24 to any port 8000  # Vaultwarden
sudo ufw allow from 192.168.1.0/24 to any port 8080  # IT-Tools
sudo ufw allow from 192.168.1.0/24 to any port 8082  # Stirling PDF
```

3. **Enable authentication for Stirling PDF if exposed**
``` bash
vim .env  # Set STIRLINGPDF_SECURITY=true
docker compose restart stirling-pdf
```
This is recommended if Stirling PDF is reachable beyond the local host.

### What these measures do and do not cover

These hardening steps are meant to reduce risk, not eliminate it.

They do:
- Reduce privilege escalation paths inside containers
- Limit accidental or malicious persistence
- Encourage safer defaults for network exposure

They do not:
- Protect a compromised Docker host
- Replace firewalls or network segmentation
- Secure services that are intentionally exposed to the internet

## Troubleshooting

### Dockge Won't Start

**Check if /opt/stacks exists:**
```bash
ls -la /opt/stacks
```

If not, create it:
```bash
sudo mkdir -p /opt/stacks
sudo chown $USER:$USER /opt/stacks
docker compose restart dockge
```

**Check Dockge logs:**
```bash
docker compose logs dockge
```

**Verify Docker socket access:**
```bash
docker exec -it admin-tools-dockge ls -la /var/run/docker.sock
```

### Vaultwarden Not Accessible

**Check if Vaultwarden is running:**
```bash
docker compose ps vaultwarden
```

**Check Vaultwarden logs:**
```bash
docker compose logs vaultwarden
```

**Test direct connection:**
```bash
curl http://localhost:8000
```
Expected: HTML response

### Watchtower Not Checking Updates

**View Watchtower logs:**
```bash
docker compose logs watchtower
```

Look for entries like:
```
Session done. Scheduled: <timestamp>
```

Restart Watchtower to trigger immediate check:
```bash
docker compose restart watchtower
```

### Port Already in Use

**Check what's using the port:**
```bash
sudo netstat -tulpn | grep 5001  # Dockge
sudo netstat -tulpn | grep 8000  # Vaultwarden
sudo netstat -tulpn | grep 8080  # IT-Tools
sudo netstat -tulpn | grep 8082  # Stirling PDF
```

Edit `.env` and modify the port:
```bash
DOCKGE_PORT=5002
```

Restart:
```bash
docker compose up -d
```

### Container Won't Start

**View detailed logs:**
```bash
docker compose logs <service-name>
```

**Check container status:**
```bash
docker compose ps
```

**Verify volume permissions:**
```bash
docker volume inspect admin-tools_<volume-name>
```

### Stirling PDF Operations Failing

**Check available memory:**

Stirling PDF needs adequate RAM for large PDFs:
```bash
free -h
```

**View Stirling PDF logs:**
```bash
docker compose logs stirling-pdf
```

## Updating

### Update Container Images
```bash
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d

# Clean up old images
docker image prune -f
```

### Update Configuration

After editing `.env`:
```bash
docker compose up -d
```

## Uninstalling

### Remove Everything
```bash
# Stop and remove containers
docker compose down

# Remove volumes (deletes all data!)
docker volume rm admin-tools_dockge-data admin-tools_vaultwarden-data admin-tools_stirlingpdf-data admin-tools_stirlingpdf-configs

# Remove stacks directory
sudo rm -rf /opt/stacks

# Remove downloaded images
docker rmi containrrr/watchtower louislam/dockge vaultwarden/server corentinth/it-tools frooodle/s-pdf
```

### Keep Data, Remove Everything Else
```bash
# Stop and remove containers (keeps volumes)
docker compose down

# Remove images
docker rmi containrrr/watchtower louislam/dockge vaultwarden/server corentinth/it-tools frooodle/s-pdf
```

Your data remains in volumes and can be reused when you deploy again.

## What Each Service Does

**Watchtower:**
- Monitors Docker containers for image updates
- Runs scheduled checks (default: daily)
- Optionally auto-updates containers
- Cleans up old images

**Dockge:**
- Provides web UI for Docker Compose
- Manages compose stacks in /opt/stacks
- Real-time container logs
- Interactive terminal access
- Stack deployment and management

**Vaultwarden:**
- Stores passwords, notes, and secure items
- Compatible with Bitwarden clients
- Self-hosted alternative to cloud password managers
- Supports browser extensions and mobile apps

**IT-Tools:**
- Collection of developer utilities
- Token/hash generation
- Encoding/decoding tools
- Format converters

**Stirling PDF:**
- PDF manipulation and processing
- Merge, split, compress PDFs
- Convert between formats
- OCR text extraction

## Related Resources

- [Watchtower Documentation](https://containrrr.dev/watchtower/)
- [Dockge GitHub](https://github.com/louislam/dockge)
- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
- [Vaultwarden GitHub](https://github.com/dani-garcia/vaultwarden)
- [IT-Tools GitHub](https://github.com/CorentinTh/it-tools)
- [Stirling PDF GitHub](https://github.com/Stirling-Tools/Stirling-PDF)