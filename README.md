<div align="center">

# 🤖 Agent-Docker

**The Universal, Isolated Docker Sandbox for Autonomous AI Coding Agents**

[English](README.md) | [한국어 (Korean)](README_KR.md)

</div>

---

**Agent-Docker** is a unified, secure Docker runtime environment designed to run CLI-based AI coding agents (**Google Antigravity, Anthropic Claude Code, OpenAI Codex, OpenCode, and Hermes Agent**) inside a strict filesystem sandbox.

It protects your host machine (home directory, SSH keys, credentials, and unrelated repositories) while granting agents **unattended auto-approval permissions**, a **pre-baked full-stack developer toolchain**, and built-in **Camoufox Anti-Detect Stealth Browser MCP**.

---

## 🌟 Key Features

* **🛡️ Strict Filesystem Sandbox**: Agents are strictly confined to the directory where you launch them (`$(pwd)`). Access to your host OS, parent paths, and home directory is blocked by default.
* **⚡ Unattended Full-Auto Mode**: Run agents with automated permission approvals (`--dangerously-skip-permissions`, `--dangerously-bypass-approvals-and-sandbox`, `--auto`) with complete peace of mind because the execution environment is containerized.
* **🦊 Built-in Camoufox Anti-Detect Browser & MCP**: Includes a C++ patched stealth Firefox engine that bypasses Cloudflare Turnstile, Akamai, and bot detection systems. Automatically configured as an MCP server across all agents.
* **🧰 Pre-Baked Modern Toolchain & Cache Continuity**: Ships with Python 3.12 (`uv`/`uvx`), Node.js 22 (`pnpm`), Rust (`cargo`/`rustc`), `ast-grep` (`sg`), `gh` (GitHub CLI), `ripgrep`, `fd`, `jq`, and `build-essential`. Package caches (`uv`, `npm`, `cargo`) persist across sessions in dedicated Docker volumes.
* **🖥️ Native Herdr Multiplexer Integration**: Uses `exec -a <agent>` process spoofing and IPC socket passthrough so terminal managers like [Herdr](https://herdr.dev) and tmux automatically recognize active agents, track status, and send desktop notifications.

---

## 📦 Supported AI Agents

| Agent | Dedicated CLI | Master Subcommand | Auto-Mounted Auth Path |
| :--- | :--- | :--- | :--- |
| **Google Antigravity** | `agy-docker` | `agent-docker agy` | `~/.gemini` |
| **Anthropic Claude Code** | `claude-docker` | `agent-docker claude` | `~/.claude` |
| **OpenAI Codex** | `codex-docker` | `agent-docker codex` | `~/.codex` |
| **OpenCode** | `opencode-docker` | `agent-docker opencode` | `~/.config/opencode` |
| **Hermes Agent** | `hermes-docker` | `agent-docker hermes` | `~/.hermes` |

---

## 🚀 Quick Start

### 1. Installation (One-Liner)

```bash
git clone https://github.com/j3bit/agent-docker.git ~/.config/agent-docker
~/.config/agent-docker/install.sh
```

### 2. Usage

Navigate to any project directory and run your agent of choice:

```bash
cd ~/Dev/my-project

# Launch Google Antigravity
agent-docker agy
# or
agy-docker

# Launch Anthropic Claude Code
agent-docker claude
# or
claude-docker

# Launch OpenAI Codex
agent-docker codex

# Open an interactive Bash debugging shell in the container
agent-docker --shell

# Rebuild the Docker sandbox image (using cache)
agent-docker --build

# Force re-download and update all agents & tools to latest versions
agent-docker --update
```

---

## 🔒 Security & Sandbox Architecture

```text
[Host Machine]
  ~/.ssh, ~/.aws, ~/Documents, Host Filesystem ──► 🛡️ 100% Protected (Blocked)
  ~/.gemini, ~/.claude, ~/.codex, ~/.config/gh ──► 🔐 Credentials Auto-Mounted Read/Write
  $(pwd) (Current Project Directory)          ──► 📂 Bound to /workspace inside Container

[Docker Container (/workspace)]
  Developer User (Matched UID/GID to Host)
  ├── Pre-baked runtimes: uv (Python), Node 22 (pnpm), Rust (cargo), ast-grep
  ├── Camoufox Anti-Detect Browser & MCP Server (xvfb, GUI libs, CJK fonts)
  └── AI Agent CLI (Runs in auto-approval mode within sandbox boundary)
```

1. **Volume Bind Mount (`-v "$PWD:/workspace"`)**: Only the active project folder is exposed to `/workspace`.
2. **Credential Passthrough**: Seamlessly mounts authentication directories from `$HOME` without re-login.
3. **UID/GID Mapping**: Matches the container user to the host user to prevent root file permission locks.
4. **Multiplexer IPC Passthrough**: Forwards `HERDR_SOCKET` and sets process names so Herdr tracks agent states in real-time.

---

## 📂 Repository Structure

```text
~/.config/agent-docker/
├── Dockerfile              # Unified multi-agent base image with all toolchains
├── Dockerfile.agy          # Clean AGY-only reference image
├── entrypoint.sh          # Container entrypoint with automatic MCP auto-configuration
├── run.sh                 # Intelligent launcher, credential router, and Herdr bridge
├── install.sh             # One-click symlink creation & build installer
├── docker-compose.yml     # Compose definition with persistent cache volumes
├── README.md              # English documentation
└── README_KR.md           # Korean documentation
```

---

## 📄 License

Distributed under the [MIT License](LICENSE).
