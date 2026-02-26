# Claude-Code-Sandbox

**Isolated environment for running Claude Code with network filtering and filesystem restrictions.**

## Architecture
```
┌──────────────────────────────────────────────┐
│ Host Machine                                 │
│  ├─ IDE (VS Codium, Jetbrains, etc.)         │
│  ├─ Git (version control)                    │
│  └─ Browser (for Claude auth)                │
└────────────┬─────────────────────────────────┘
             │
             │ Volume mounts
             ↓
┌──────────────────────────────────────────────┐
│ Podman Pod - Internal Network ONLY           │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ Claude Code Container                  │  │
│  │  ❌ No direct internet access          │  │
│  │  ✅ Can only talk to Squid proxy       │  │
│  │  ✅ /workspace = project directory     │  │
│  │  ✅ ~/.claude = persistent auth        │  │
│  └────────────┬───────────────────────────┘  │
│               │ traffic via proxy            │
│               ↓                              │
│  ┌────────────────────────────────────────┐  │
│  │ Squid Proxy Container                  │  │
│  │  ✅ Blocks RFC1918 (local networks)    │  │
│  │  ✅ Blocks localhost & metadata APIs   │  │
│  │  ✅ Allows internet (github, npm, etc) │  │
│  │  ✅ Full traffic logging               │  │
│  └────────────┬───────────────────────────┘  │
│               │                              │
└───────────────┼──────────────────────────────┘
                │ Only proxy container
                │ has external network access
                ↓
          [ Internet ]
```

## Security Model

### Defense Layers

1. **Network Isolation** (OS-level)
   - Container on `internal: true` network - **no IP forwarding to internet**
   - No direct route exists to external networks

2. **Proxy Filtering** (Application-level)
   - Squid ACLs block private IP ranges (10.0.0.0/8, 192.168.0.0/16, 172.16.0.0/12)
   - Blocks cloud metadata services (169.254.169.254)
   - Blocks localhost (127.0.0.0/8)

3. **Filesystem Isolation** (Container-level)
   - Only `/workspace` writable
   - Home directory not mounted
   - No access to `/etc`, system files
   - SELinux labels prevent escape

### What's Blocked
```bash
# These all FAIL inside the container:
curl http://192.168.1.1          # Local network - BLOCKED
curl http://10.0.0.1             # Private network - BLOCKED  
curl http://127.0.0.1            # Localhost - BLOCKED
curl http://169.254.169.254      # Cloud metadata - BLOCKED
curl --noproxy '*' https://google.com  # Direct internet - NO ROUTE
```

### What's Allowed
```bash
# These work (through the proxy):
curl https://github.com          # ✅ Allowed
curl https://registry.npmjs.org  # ✅ Allowed
curl https://pypi.org            # ✅ Allowed
curl https://api.anthropic.com   # ✅ Allowed
```

## Quick Start

### Prerequisites

- **Podman** (or Docker) installed
- **Podman Compose** plugin
- Claude Pro/Max subscription OR Anthropic API key

### Installation
```bash
# Build and start
podman compose up -d

# Enter the sandbox
podman compose exec claude-code bash

# First time: Log in to Claude
claude login

# Start working
cd /workspace
claude
```

## Project Structure
```
claude-code-sandbox/
├── podman-compose.yml         # Main configuration
├── Containerfile              # Claude Code container image
├── squid-config/
│   └── squid.conf             # Proxy filtering rules
├── .gitignore                 # Don't commit secrets
├── .README.md                 # This file
└── workspace/                 # Your project directory
```

## Configuration

### Basic Setup (podman-compose.yml)

```yaml
networks:
  internal_net:
    internal: true              # ← Critical: No external routing
    
services:
  claude-code:
    volumes:
      - ~/projects/my-project:/workspace:Z    # Your project
      - ~/.claude:/root/.claude:Z             # Persistent auth
      - /etc/localtime:/etc/localtime:ro      # Timezone
```

**Important:** Change `~/projects/my-project` to your actual project path.

### Advanced: Whitelist-Only Mode

For maximum security, only allow specific domains:

Edit `squid-config/squid.conf`:
```conf
# After the existing ACL definitions, add:
acl allowed_domains dstdomain .anthropic.com
acl allowed_domains dstdomain .github.com
acl allowed_domains dstdomain .npmjs.org
acl allowed_domains dstdomain .pypi.org

# Replace the blanket allow with:
http_access allow docker_network allowed_domains
http_access deny all
```

Rebuild: `podman compose down && podman compose up -d`


## Monitoring Traffic
```bash
# View proxy logs (see what Claude is accessing)
podman compose logs -f squid-proxy

# View blocked requests
podman compose exec squid-proxy grep "TCP_DENIED" /var/log/squid/access.log
```

## Security Considerations

### What This DOES Protect Against

✅ Prompt injection leading to data exfiltration  
✅ Malicious dependencies accessing local network  
✅ Accidental credential exposure  
✅ AI hallucinating dangerous commands  
✅ Supply chain attacks via package managers  

### What This DOES NOT Protect Against

❌ Malicious code you explicitly tell Claude to write  
❌ Attacks on whitelisted domains (github.com, etc.)  
❌ Social engineering attacks against you  
❌ Attacks on the Anthropic API itself  


## License

MIT License - See LICENSE file

---

**⚠️ Disclaimer:** This setup improves security but is not foolproof. Always review AI-generated code before execution, especially in security-sensitive contexts. Use at your own risk.
