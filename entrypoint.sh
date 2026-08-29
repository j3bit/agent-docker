#!/usr/bin/env bash
set -e

# Print isolation banner
echo "============================================================"
echo " 🔒 Antigravity CLI Isolated Docker Sandbox"
echo " Working directory bound to: $(pwd)"
echo " Filesystem restricted to this workspace only."
echo "============================================================"

# Auto-configure Camoufox MCP Server for all active agents if not present
python3 - <<'EOF' 2>/dev/null || true
import os, json

home = os.environ.get("HOME", "/home/developer")

# 1. Claude Code (~/.claude/mcp.json)
claude_dir = os.path.join(home, ".claude")
os.makedirs(claude_dir, exist_ok=True)
claude_mcp = os.path.join(claude_dir, "mcp.json")
try:
    data = json.load(open(claude_mcp)) if os.path.exists(claude_mcp) else {}
    if "mcpServers" not in data:
        data["mcpServers"] = {}
    if "camoufox" not in data["mcpServers"]:
        data["mcpServers"]["camoufox"] = {"command": "camoufox-mcp"}
        with open(claude_mcp, "w") as f:
            json.dump(data, f, indent=2)
except Exception:
    pass

# 2. Antigravity (~/.gemini/antigravity-cli/mcp/camoufox.json)
gemini_mcp_dir = os.path.join(home, ".gemini", "antigravity-cli", "mcp")
os.makedirs(gemini_mcp_dir, exist_ok=True)
gemini_mcp = os.path.join(gemini_mcp_dir, "camoufox.json")
if not os.path.exists(gemini_mcp):
    try:
        with open(gemini_mcp, "w") as f:
            json.dump({
                "mcpServers": {
                    "camoufox": {
                        "command": "camoufox-mcp"
                    }
                }
            }, f, indent=2)
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
