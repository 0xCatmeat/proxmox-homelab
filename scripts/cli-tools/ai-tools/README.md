# AI Development Tools (`ai-tools.sh`)

Installer for terminal-based AI coding assistants. Handles Node.js setup via nvm when needed, skips tools that are already installed, and provides authentication guidance for first use.

## What This Script Does

Installs one or more AI CLI tools:
- **Claude Code**
- **Gemini CLI**
- **OpenAI Codex**

The script verifies Node.js requirements, offers automatic installation via nvm if it's missing, detects existing installations to prevent redundant work, and provides clear next steps for authentication and usage.

## Prerequisites

Before running the script:
- Active internet connection
- Regular user account (do NOT run as root)
- Node.js 20+ for Gemini CLI
- Node.js 22+ for Codex

Node.js is not required beforehand. The script offers to install it automatically via nvm if it's not already installed.

## Installation

### Download the Script

Clone the repository:
```bash
git clone https://github.com/0xCatmeat/proxmox-homelab.git
cd proxmox-homelab/scripts/cli-tools/ai-tools
chmod +x ai-tools.sh
```

Or download directly:
```bash
wget https://raw.githubusercontent.com/0xCatmeat/proxmox-homelab/main/scripts/cli-tools/ai-tools/ai-tools.sh
chmod +x ai-tools.sh
```

## Usage

### Interactive Mode (Recommended)

```bash
./ai-tools.sh
```

The script prompts you to select which tools to install and handles Node.js setup automatically.

### Command Line Options

```bash
# Install specific tools
./ai-tools.sh --claude-code
./ai-tools.sh --gemini-cli
./ai-tools.sh --codex

# Install everything
./ai-tools.sh --all

# Keep log file
./ai-tools.sh --all --log

# Show help
./ai-tools.sh --help
```

### Available Options

| Option          | Description                   |
| --------------- | ----------------------------- |
| `--claude-code` | Install Claude Code           |
| `--gemini-cli`  | Install Gemini CLI            |
| `--codex`       | Install Codex                 |
| `--all`         | Install all three tools       |
| `--log`         | Keep log file even on success |
| `--help`        | Show usage information        |

## What to Expect During Installation

### Phase 1: Tool Selection

If you run without flags, the script displays information about each tool and prompts for which ones to install. Tools already present are automatically skipped.

### Phase 2: Node.js Check

For Gemini CLI and Codex:
- Script checks for Node.js 20+ (Gemini) or 22+ (Codex)
- If not found, offers to install via nvm
- Asks for confirmation before installing

### Phase 3: Tool Installation

**Claude Code:**
- Downloads and runs official installer from Anthropic
- Installs native binary (no npm required)
- Adds `claude` command to PATH

**Gemini CLI:**
- Installs via npm: `npm install -g @google/gemini-cli`
- Adds `gemini` command to PATH
- Requires Node.js 20+

**Codex:**
- Installs via npm: `npm install -g @openai/codex`
- Adds `codex` command to PATH
- Requires Node.js 22+

### Phase 4: Completion

Shows which tools were installed successfully and provides instructions for first use.

## After Installation

### Authenticate Each Tool

Each tool requires authentication before first use.

**Claude Code:**
```bash
claude
```
Follow OAuth prompts to sign in with Claude Pro/Max subscription or API key.

**Gemini CLI:**
```bash
gemini
```
Select authentication method:
- Google account
- Gemini API key

**Codex:**
```bash
codex
```
Sign in with ChatGPT account (Plus, Pro, Enterprise) or OpenAI API key.

## Troubleshooting

### Node.js Version Too Old

**Symptom:** Script reports Node.js version below requirements

**Solution:**
```bash
# If using nvm (recommended):
nvm install --lts
nvm use --lts

# Verify:
node --version
```

**For Codex specifically:**
```bash
# Codex requires Node.js 22+
nvm install 22
nvm use 22
node --version
```

### Authentication Fails

**Claude Code:**
- Verify Claude Pro/Max subscription is active
- Or get API key from https://console.anthropic.com
- Run `claude` in a project directory, not your home directory

**Gemini CLI:**
- Use standard Google account (workspace admin accounts may have restrictions)
- For free tier: standard Google login works immediately
- For API key: Get from https://aistudio.google.com/apikey

**Codex:**
- Verify ChatGPT Plus/Pro subscription is active
- Or get API key from https://platform.openai.com/api-keys
- Check quota and billing status if using API keys

## Updating Tools

### Claude Code

Auto-updates by default. Manual update:
```bash
claude upgrade
```

### Gemini CLI

```bash
npm update -g @google/gemini-cli
```

### Codex

```bash
npm update -g @openai/codex
```

### Check Versions

```bash
claude --version
gemini --version
codex --version
```

## Uninstalling

### Remove Individual Tools

**Claude Code:**
```bash
# Check installation location first:
which claude

# Remove binary and config:
rm $(which claude)
rm -rf ~/.claude
```

**Gemini CLI:**
```bash
npm uninstall -g @google/gemini-cli
rm -rf ~/.config/gemini-cli
```

**Codex:**
```bash
npm uninstall -g @openai/codex
rm -rf ~/.codex
```

### Remove Node.js (if installed via nvm)

```bash
# Remove all Node.js versions:
nvm deactivate
nvm uninstall --lts
nvm uninstall 22

# Remove nvm itself:
rm -rf ~/.nvm

# Remove nvm lines from ~/.bashrc manually
```

## Security Notes

### API Key Storage

If using API keys instead of subscriptions, store them as environment variables:

```bash
# Add to ~/.bashrc or ~/.zshrc:
export ANTHROPIC_API_KEY="your-key-here"
export GOOGLE_API_KEY="your-key-here"
export OPENAI_API_KEY="your-key-here"

# Then reload:
source ~/.bashrc
```

### Privacy

Code analyzed by these tools may be sent to respective AI providers:
- Check each provider's privacy policy
- All three providers state they don't train on user code with paid plans
- Verify current policies before using with sensitive data
- Consider self-hosted alternatives for highly sensitive projects

For a completely local AI solution with no data sent to external providers, see the LLM Chat stack in `scripts/docker-compose/llm-chat/`.

## Understanding the Script's Behavior

### Safe to Re-run

The script checks for existing installations:
- If a tool is already installed, it skips installation
- Shows version information for already-installed tools
- Only installs what's missing

### Error Handling

The script continues even if individual steps fail:
- Tracks all failures
- Reports them at completion
- Saves log automatically when errors occur

### Node.js via nvm

The script offers nvm installation because:
- No sudo/root required
- Easy version management
- Doesn't conflict with system packages
- Clean installation and removal

### Node Version Requirements

Different tools have different requirements:
- **Gemini CLI:** Node.js 20+
- **Codex:** Node.js 22+

How the script handles this:
1. If installing only Gemini, installs Node 20
2. If installing only Codex, installs Node 22
3. If installing both, installs Node 22 (satisfies both requirements)

## Related Resources

- [Claude Code Documentation](https://code.anthropic.com/docs)
- [Gemini CLI Documentation](https://geminicli.com/docs)
- [OpenAI Codex Documentation](https://developers.openai.com/codex)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)
- [Gemini CLI GitHub](https://github.com/google-gemini/gemini-cli)
- [OpenAI Codex GitHub](https://github.com/openai/codex)
- [nvm GitHub](https://github.com/nvm-sh/nvm)
