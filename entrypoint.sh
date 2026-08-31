#!/usr/bin/env bash
set -e

# Map host home directory (e.g. /Users/jeongsaebit) to container home (/home/developer)
# so that all absolute symlinks pointing to ~/.agents, ~/.codex, ~/.claude, ~/.gemini resolve correctly!
if [ -n "${HOST_HOME:-}" ] && [ "$HOST_HOME" != "/home/developer" ]; then
    sudo mkdir -p "$(dirname "$HOST_HOME")" 2>/dev/null || true
    sudo ln -sfn /home/developer "$HOST_HOME" 2>/dev/null || true
fi

# Print isolation banner.
# The agent config directories are mounted read-write on purpose, so that skills,
# plugins and agent settings can be edited from inside the sandbox. That is a
# deliberate hole in the isolation, so say so rather than claiming otherwise.
echo "============================================================"
echo " 🔒 Isolated Docker Sandbox"
echo " Working directory bound to: $(pwd)"
echo " Project files restricted to this workspace only."
echo ""
echo " ⚠️  Host agent configs are mounted READ-WRITE, not isolated:"
echo "     ~/.claude  ~/.gemini  ~/.codex  ~/.agents  ~/.hermes  ~/.config/gh"
echo "     An agent here can edit host settings/hooks/skills (which run"
echo "     on the host later) and use host GitHub credentials."
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

# Auto-configure a container-only ~/.gitconfig.
# The host's ~/.gitconfig is never mounted: it typically references host-only
# tools (pager, editor, credential helper paths) that don't exist in the image,
# and Docker Desktop's bind mount exposes /workspace as owned by a different
# uid than the container's user, which git refuses to touch without
# safe.directory. Both break every git command (status, diff, commit) until
# fixed here.
GIT_CFG="$HOME/.gitconfig"
if [ ! -f "$GIT_CFG" ]; then
    {
        echo "[safe]"
        # `*` rather than just /workspace: the uid mismatch is an artifact of the
        # bind mount, so it applies equally to submodules, nested repos and
        # worktrees, which a single /workspace entry would not cover. Everything
        # reachable here is already inside the container.
        echo "    directory = *"
        echo "[init]"
        echo "    defaultBranch = main"
        echo "[credential \"https://github.com\"]"
        echo "    helper = !gh auth git-credential"
        echo "[credential \"https://gist.github.com\"]"
        echo "    helper = !gh auth git-credential"
    } > "$GIT_CFG"
fi
# Always keep author identity in sync with what was passed in from the host
# (agent-docker.env / run.sh), without clobbering any other local edits.
if [ -n "${GIT_USER_NAME:-}" ]; then
    git config --global user.name "$GIT_USER_NAME"
fi
if [ -n "${GIT_USER_EMAIL:-}" ]; then
    git config --global user.email "$GIT_USER_EMAIL"
fi

# Report skills whose symlink does not resolve inside the container.
# Shared skills are often chained (~/.claude/skills/x -> ~/.agents/skills/x ->
# ~/.codex/skills/x), so a skill silently disappears whenever any directory in
# that chain is not mounted, or when it points outside $HOME entirely. Agents
# just show a shorter skill list, giving no hint that anything is missing.
for skills_dir in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
    [ -d "$skills_dir" ] || continue
    broken=""
    for skill in "$skills_dir"/*; do
        [ -e "$skill" ] && continue          # resolves fine
        [ -L "$skill" ] || continue          # not a dangling symlink; ignore
        broken="$broken $(basename "$skill")"
    done
    if [ -n "$broken" ]; then
        echo "⚠️  Unresolved skills in ${skills_dir#$HOME/}:$broken"
        echo "    Their symlink target is not reachable in the container."
        echo "    Check that every directory in the chain is mounted (run.sh)."
    fi
done

# Execute passed command (Default: agy with auto-approved permissions in sandbox)
if [ "$#" -eq 0 ]; then
    exec agy --dangerously-skip-permissions
else
    exec "$@"
fi
