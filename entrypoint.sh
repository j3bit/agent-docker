#!/usr/bin/env bash
set -e

# Map host home directory (e.g. /Users/jeongsaebit) to container home (/home/developer)
# so that all absolute symlinks pointing to ~/.agents, ~/.codex, ~/.claude, ~/.gemini resolve correctly!
if [ -n "${HOST_HOME:-}" ] && [ "$HOST_HOME" != "/home/developer" ]; then
    sudo mkdir -p "$(dirname "$HOST_HOME")" 2>/dev/null || true
    sudo ln -sfn /home/developer "$HOST_HOME" 2>/dev/null || true
fi

# Print isolation banner
echo "============================================================"
echo " 🔒 Isolated Docker Sandbox"
echo " Working directory bound to: $(pwd)"
echo " Filesystem restricted to this workspace only."
echo "============================================================"

# Auto-configure Camoufox MCP Server for all active agents if not present
python3 - <<'EOF' 2>/dev/null || true
import os, json

home = os.environ.get("HOME", "/home/developer")

# 1. Claude Code (~/.claude.json)
# NOTE: Claude Code reads user-scope MCP servers from ~/.claude.json, never from
# ~/.claude/mcp.json -- writing the latter is a silent no-op.
os.makedirs(os.path.join(home, ".claude"), exist_ok=True)
claude_cfg = os.path.join(home, ".claude.json")
try:
    data = json.load(open(claude_cfg)) if os.path.exists(claude_cfg) else {}
    if not isinstance(data, dict):
        data = {}
    servers = data.get("mcpServers")
    if not isinstance(servers, dict):
        servers = {}
        data["mcpServers"] = servers
    if "camoufox" not in servers:
        servers["camoufox"] = {"type": "stdio", "command": "camoufox-mcp", "args": [], "env": {}}
        with open(claude_cfg, "w") as f:
            json.dump(data, f, indent=2)
except Exception:
    pass

# 2. Antigravity (~/.gemini/config/mcp_config.json)
gemini_config_dir = os.path.join(home, ".gemini", "config")
os.makedirs(gemini_config_dir, exist_ok=True)
gemini_mcp = os.path.join(gemini_config_dir, "mcp_config.json")
try:
    data = json.load(open(gemini_mcp)) if os.path.exists(gemini_mcp) else {}
    if "mcpServers" not in data:
        data["mcpServers"] = {}
    if "camoufox" not in data["mcpServers"]:
        data["mcpServers"]["camoufox"] = {"command": "camoufox-mcp"}
        with open(gemini_mcp, "w") as f:
            json.dump(data, f, indent=2)
except Exception:
    pass

# 3. OpenCode (~/.config/opencode/opencode.json)
opencode_dir = os.path.join(home, ".config", "opencode")
os.makedirs(opencode_dir, exist_ok=True)
opencode_cfg = os.path.join(opencode_dir, "opencode.json")
try:
    data = json.load(open(opencode_cfg)) if os.path.exists(opencode_cfg) else {}
    if "mcpServers" not in data:
        data["mcpServers"] = {}
    if "camoufox" not in data["mcpServers"]:
        data["mcpServers"]["camoufox"] = {"command": "camoufox-mcp"}
        with open(opencode_cfg, "w") as f:
            json.dump(data, f, indent=2)
except Exception:
    pass

# 4. Codex (~/.codex/config.toml)
codex_dir = os.path.join(home, ".codex")
os.makedirs(codex_dir, exist_ok=True)
codex_cfg = os.path.join(codex_dir, "config.toml")
try:
    content = open(codex_cfg).read() if os.path.exists(codex_cfg) else ""
    if "camoufox" not in content:
        with open(codex_cfg, "a") as f:
            f.write('\n[mcp_servers.camoufox]\ncommand = "camoufox-mcp"\n')
except Exception:
    pass
EOF

# Execute passed command (Default: agy with auto-approved permissions in sandbox)
if [ "$#" -eq 0 ]; then
    exec agy --dangerously-skip-permissions
else
    exec "$@"
fi
