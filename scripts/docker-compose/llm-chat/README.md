# LLM Chat Stack

Complete local AI workspace with Ollama for model inference, Lobe Chat as a modern web interface, and SearXNG for web search capabilities. Run powerful language models entirely on your own hardware with full privacy and control.

## What This Stack Provides

**Ollama** - Local LLM engine that runs open-source models directly on your hardware  
**Lobe Chat** - Modern, feature-rich web UI for interacting with your local models  
**SearXNG** - Privacy-focused metasearch engine for web search capabilities  
**Valkey** - Redis-compatible cache for fast search performance

Benefits:
- Complete privacy - all data stays on your machine
- No API costs - unlimited usage
- Web search integration - AI can access current information
- Works offline - no internet required after setup (except for web search)
- Fast responses - runs on your local hardware
- Multiple model support - switch between models easily

## Prerequisites

Before deploying this stack:
- VM set up with the vm-setup scripts (Ubuntu or Debian)
- Docker installed (use `--docker` flag with vm-setup scripts)

## Quick Start

### 1. Download the stack

```bash
git clone https://github.com/0xCatmeat/proxmox-homelab.git
cd proxmox-homelab/scripts/docker-compose/llm-chat
```

### 2. Review configuration (optional)

```bash
# Copy the environment file
cp .env.example .env

# Edit if needed
vim .env
```
Default configuration:
- Ollama accessible to all containers (OLLAMA_ORIGINS=*)
- Lobe Chat uses internal Docker networking
- SearXNG enabled for web search
- No password protection (add ACCESS_CODE for security)

### 3. Start the services

```bash
docker compose up -d
```

### 4. Pull a model

```bash
docker exec -it llm-chat-ollama ollama pull <MODEL_NAME>
```

### 5. Access Lobe Chat

Open your browser and navigate to:

```
http://YOUR_VM_IP:3210
```

You're ready to start chatting with your local LLM!

## Available Models

Browse all available models at [Ollama](https://ollama.com/search).

### Managing Models

**List installed models:**

```bash
docker exec -it llm-chat-ollama ollama list
```

**Pull a model:**

```bash
docker exec -it llm-chat-ollama ollama pull <MODEL_NAME>
```

**Remove a model:**

```bash
docker exec -it llm-chat-ollama ollama rm <MODEL_NAME>
```

**Check model info:**

```bash
docker exec -it llm-chat-ollama ollama show <MODEL_NAME>
```

## Configuration

### Environment Variables

Key settings in `.env`:

**OLLAMA_ORIGINS**
- Controls CORS access to Ollama
- Default: `*` (allow all)
- Security: Restrict to specific origins if exposed to network

**OLLAMA_PROXY_URL**
- How Lobe Chat connects to Ollama
- Default: `http://ollama:11434` (Docker network)
- Don't change unless modifying service names

**SEARXNG_URL**
- How Lobe Chat connects to SearXNG
- Default: `http://searxng:8080` (Docker network)
- Don't change unless modifying service names

**SEARCH_PROVIDERS**
- Enables search functionality
- Default: `searxng`
- Uses the included SearXNG instance

**ACCESS_CODE** (Recommended)
- Password protection for Lobe Chat
- Uncomment and set a strong password
- Required if exposing to your local network

**UWSGI_WORKERS / UWSGI_THREADS**
- SearXNG performance tuning
- Default: 4 workers, 4 threads
- Increase for better performance on powerful systems

### Port Configuration

Default port (change in `docker-compose.yml` if needed):

- **Lobe Chat**: 3210 (only exposed port)

Internal ports (Docker network only):
- **Ollama**: 11434
- **SearXNG**: 8080
- **Valkey**: 6379

## Using Lobe Chat

### First-Time Setup

1. Access Lobe Chat at `http://YOUR_VM_IP:3210`
2. If you set an ACCESS_CODE, enter it when prompted
3. Click the model dropdown (top of screen)
4. Select the model(s) you pulled

### Enabling Web Search

1. Open a chat conversation
2. Look for the search icon/button in the toolbar
3. Click it to enable "smart online search"
4. AI will now automatically search the web when it needs current information

Web search is a per-conversation toggle - you decide when you need it.

### Features

- **Multiple conversations** - Create separate chats for different topics
- **Model switching** - Change models mid-conversation
- **Web search** - Access current information from the internet
- **Conversation export** - Save your chats
- **Custom system prompts** - Define AI personality/behavior
- **File uploads** - Send images to vision-capable models
- **Code highlighting** - Syntax highlighting for code responses

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
docker compose restart llm-chat-searxng
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

# Just Ollama
docker compose logs -f ollama

# Just Lobe Chat
docker compose logs -f lobe-chat

# Just SearXNG
docker compose logs -f searxng

# Just Valkey
docker compose logs -f valkey
```

### Check resource usage

```bash
docker stats llm-chat-ollama llm-chat-lobe llm-chat-searxng llm-chat-valkey
```

## Storage and Data

### Where Data Is Stored

**Ollama models:**
- Location: `ollama-data` Docker volume
- Persists even if containers are removed

**Valkey cache:**
- Location: `valkey-data` Docker volume
- Stores search result cache

**SearXNG configuration:**
- Location: `./searxng` directory
- Mounted from host filesystem

### View Volume Information

**List volumes:**
```bash
docker volume ls | grep llm-chat
```

**Inspect a volume:**
```bash
docker volume inspect llm-chat_ollama-data
```

**Check volume sizes:**
```bash
docker system df -v | grep llm-chat
```

### Backup and Restore

**Backup Ollama models:**
```bash
docker run --rm \
  -v llm-chat_ollama-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/ollama-models.tar.gz /data
```

**Restore Ollama models:**
```bash
docker run --rm \
  -v llm-chat_ollama-data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/ollama-models.tar.gz -C /
```

### Reset Everything

```bash
# Stop and remove containers
docker compose down

# Remove all volumes (deletes models and cache!)
docker compose down -v

# Start fresh
docker compose up -d
```

## Security Recommendations

### For Local Network Access

If you're accessing Lobe Chat from other devices on your network:

1. **Set an ACCESS_CODE**

```bash
vim .env  # Uncomment and set ACCESS_CODE
docker compose down && docker compose up -d
```

2. **Use UFW to restrict access**

```bash
sudo ufw allow from 192.168.1.0/24 to any port 3210
```

3. **Don't expose to internet** - Keep it on your local network only

### For Single-User Systems

If only accessing from the VM itself:
- ACCESS_CODE is optional
- Default configuration is fine
- All data (models, searches, chats) stays local

## Web Search Details

### How It Works

When you enable web search in a conversation:
1. AI determines if it needs current information
2. Lobe Chat queries SearXNG for relevant search results
3. SearXNG aggregates results from multiple search engines
4. Results are cached in Valkey for performance
5. AI processes the results and generates a response

### Privacy

- All search queries go through your local SearXNG instance
- No direct connection to search engines from your browser
- Search queries are not tied to your identity
- Results are cached locally in Valkey

### Customizing SearXNG

You can customize which search engines SearXNG uses:

1. **Edit the settings file:**
```bash
vim ./searxng/settings.yml
```

2. **Restart SearXNG:**
```bash
docker compose restart llm-chat-searxng
```

See [SearXNG documentation](https://docs.searxng.org/) for advanced configuration.

## Advanced Usage

### Custom Model Files

Create custom models with specific behavior:
```bash
# Create a Modelfile
cat > custom-model.txt << EOF
FROM llama3.2
SYSTEM You are a helpful Python programming assistant.
PARAMETER temperature 0.7
PARAMETER top_p 0.9
EOF

# Create the custom model
docker exec -i llm-chat-ollama ollama create python-helper < custom-model.txt
```

### Performance Tuning

**Increase SearXNG workers for better search performance:**
```bash
# Edit .env
UWSGI_WORKERS=8
UWSGI_THREADS=8

# Restart
docker compose restart llm-chat-searxng
```

**Monitor resource usage:**
```bash
# Real-time stats
docker stats

# Check if models fit in RAM
free -h
```

## Troubleshooting

### Lobe Chat Can't Connect to Ollama

**Check if Ollama is running:**
```bash
docker compose ps ollama
```

**Check Ollama logs:**
```bash
docker compose logs ollama
```

**Verify internal network connectivity:**
```bash
docker exec -it llm-chat-lobe curl http://ollama:11434/api/tags
```

### Web Search Not Working

**Verify SearXNG is running:**
```bash
docker compose ps searxng
```

**Check SearXNG logs:**
```bash
docker compose logs searxng
```

**Test SearXNG directly:**
```bash
curl "http://YOUR_VM_IP:8080/search?q=test&format=json" 2>/dev/null | head -50
```

Note: SearXNG is not exposed to the host by default. To test, exec into Lobe Chat container:
```bash
docker exec -it llm-chat-lobe curl "http://searxng:8080/search?q=test&format=json"
```

### Models Download Slowly

**Check available disk space:**
```bash
df -h
```

**Monitor download progress:**
```bash
docker exec -it llm-chat-ollama ollama pull llama3.2
```

### Valkey Issues

**Check if Valkey is running:**
```bash
docker compose ps valkey
```

**Test Valkey connectivity:**
```bash
docker exec -it llm-chat-valkey valkey-cli ping
```

Expected response: `PONG`

### Container Won't Start

**View detailed logs:**
```bash
docker compose logs <service-name>
```

**Check for port conflicts:**
```bash
sudo netstat -tulpn | grep 3210
```

**Verify Docker network:**
```bash
docker network inspect llm-chat_llm-chat-network
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

Your models, cache, and configuration persist in volumes and won't be affected.

## Uninstalling

### Remove Everything

```bash
# Stop and remove containers
docker compose down

# Remove volumes (deletes all models and cache!)
docker volume rm llm-chat_ollama-data llm-chat_valkey-data

# Remove downloaded images
docker rmi ollama/ollama lobehub/lobe-chat searxng/searxng valkey/valkey
```

### Keep Models, Remove Everything Else

```bash
# Stop and remove containers (keeps volumes)
docker compose down

# Remove only the cache volume
docker volume rm llm-chat_valkey-data

# Remove images except Ollama
docker rmi lobehub/lobe-chat searxng/searxng valkey/valkey
```

### What Each Service Does

**Ollama:**
- Runs the AI models
- Processes inference requests
- Manages model storage

**Lobe Chat:**
- Provides the web interface
- Manages conversations
- Coordinates between Ollama and SearXNG
- Handles file uploads and exports

**SearXNG:**
- Aggregates results from multiple search engines
- Protects your privacy (queries not tied to you)
- Provides current information to the AI

**Valkey:**
- Caches search results for performance
- Reduces redundant search engine queries
- Improves response times for repeated searches

## Related Resources

- [Ollama Documentation](https://github.com/ollama/ollama/tree/main/docs)
- [Ollama Model Library](https://ollama.com/library)
- [Lobe Chat Documentation](https://lobehub.com/docs)
- [Lobe Chat GitHub](https://github.com/lobehub/lobe-chat)
- [SearXNG Documentation](https://docs.searxng.org/)
- [SearXNG GitHub](https://github.com/searxng/searxng)

## Getting Help

If you encounter issues:
1. Review container logs: `docker compose logs`
2. Verify all containers are running: `docker compose ps`
3. Check the troubleshooting section above
4. Consult the official documentation for each component

## What's Next?

After getting comfortable with this stack:
- Install AI development tools (see `scripts/dev-tools/`)
- Experiment with different models for different tasks
- Create custom models optimized for your use cases
- Customize SearXNG to use your preferred search engines
- Integrate Ollama API into your own applications

In the files in this project folder I've uploaded all files I have completed so far. I want to use these to create a GitHub repo called 'proxmox-homelab'. This all originated from the 'Mini PC Proxmox Documentation.md' file, because that's where I was originally writing notes for things I was doing, but ultimately wanted to convert those into the scripts I uploaded in this project folder. Please review all the scripts and provide your feedback and highlight any issues you may have noticed. Also review the README files to ensure they accurately reflect the scripts they were written for.

If you have questions please let me know so I can clarify any potential things that confuse you if any.

Please use the tools you have available to you to do the proper research on the tools that are being used in these scripts so you don't have any confusion in that regard, such as the extensions, MCPs, etc.

Also, as I've already mentioned in my hardcoded instructions already, the files I gave you have names like 'llm-chat.env.example' as opposed to '.env.example' just for your own reference to avoid potential confusing when reading the files. It was there to help keep the files slightly more organized in this project folder. The real files have the correct names they need.

With that said, don't worry about the naming scheme of the files I upload for you. When you are working, just use the correct names that the files are meant to have.

While we're focusing on the ai-setup.sh script, I also want to focus on the 'cli-tools-README' file. I want that one to be revised so the formatting/writing matches that of the other README files. Let me know what you think of how it's currently written and if it can be improved.