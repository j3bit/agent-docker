<div align="center">

# 🤖 Agent-Docker

**The Universal, Isolated Docker Sandbox for Autonomous AI Coding Agents**

[English](README.md) | [한국어 (Korean)](README_KR.md)

</div>

---

**Agent-Docker** is a unified Docker runtime environment designed to run CLI-based AI coding agents (**Google Antigravity, Anthropic Claude Code, OpenAI Codex, OpenCode, and Hermes Agent**) inside a filesystem sandbox.

It keeps your host project files out of reach while granting agents **unattended auto-approval permissions**, a **pre-baked full-stack developer toolchain**, and built-in **Camoufox Anti-Detect Stealth Browser MCP**.

> **⚠️ Read [Security & Sandbox Architecture](#-security--sandbox-architecture) before relying on this for isolation.** Your agent config directories are mounted **read-write by design** so that skills and plugins stay editable from inside the sandbox. That is a deliberate hole, not full isolation.

---

## 🌟 Key Features

* **🛡️ Workspace-Scoped Filesystem**: Agents see only the directory you launch them from (`$(pwd)`), bound to `/workspace`. Your other repositories, `~/.ssh`, `~/.aws`, and `~/Documents` are never mounted.
* **⚡ Unattended Full-Auto Mode**: Run agents with automated permission approvals (`--dangerously-skip-permissions`, `--dangerously-bypass-approvals-and-sandbox`, `--auto`) without a prompt on every tool call.
* **🔑 Persistent Authentication**: Log in once. Agent sessions survive `docker run --rm` via a container-dedicated state directory, so you are not re-onboarded on every launch.
* **🦊 Built-in Camoufox Anti-Detect Browser & MCP**: A C++ patched stealth Firefox engine that bypasses Cloudflare Turnstile, Akamai, and bot detection. Registered as an MCP server for every agent automatically.
* **🧰 Pre-Baked Modern Toolchain & Cache Continuity**: Ships with Python 3.12 (`uv`/`uvx`), Node.js 22 (`pnpm`), Rust (`cargo`/`rustc`), `ast-grep` (`sg`), `gh` (GitHub CLI), `git-lfs`, `ripgrep`, `fd`, `jq`, `bubblewrap`, `socat`, and `build-essential`. Package caches (`uv`, `npm`, `pip`, `cargo`) persist across sessions in dedicated Docker volumes.
* **🖥️ Native Herdr Multiplexer Integration**: Uses `exec -a <agent>` process spoofing and IPC socket passthrough so terminal managers like [Herdr](https://herdr.dev) and tmux automatically recognize active agents, track status, and send desktop notifications.

---

## 📦 Supported AI Agents

| Agent | Dedicated CLI | Master Subcommand | Auto-Mounted Auth Path |
| :--- | :--- | :--- | :--- |
| **Google Antigravity** | `agy-docker` | `agent-docker agy` | `~/.gemini` |
| **Anthropic Claude Code** | `claude-docker` | `agent-docker claude` | `~/.claude` + `state/claude.json` |
| **OpenAI Codex** | `codex-docker` | `agent-docker codex` | `~/.codex` |
| **OpenCode** | `opencode-docker` | `agent-docker opencode` | `~/.config/opencode` |
| **Hermes Agent** | `hermes-docker` | `agent-docker hermes` | `~/.hermes` |

---

## 🚀 Quick Start

### 1. Installation

```bash
git clone https://github.com/j3bit/agent-docker.git ~/.config/agent-docker
cd ~/.config/agent-docker

# Interactive setup: pick which agents to install, then build
./install.sh
```

`install.sh` asks about each agent in turn and writes your answers to `agent-docker.env`.
You can edit that file directly and re-apply it at any time:

```bash
# Show the current configuration
agent-docker config

# Rebuild after editing agent-docker.env
agent-docker --build
```

Installing fewer agents meaningfully reduces build time and image size.

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

## 🩺 Checking That an Agent Works

Launching an agent's TUI to see whether it is healthy is awkward, and tells you
little when it is not. `smoke-test.sh` sends each installed agent one throwaway
prompt and classifies the answer:

```bash
./smoke-test.sh              # all agents
./smoke-test.sh claude codex # only these
```

```text
🔎 Sandbox agent smoke test (agent-docker-sandbox:latest)
  agy        OK
  claude     OK
  codex      OK
  opencode   CONFIG
  hermes     ACCOUNT
```

| Verdict | Meaning |
| :--- | :--- |
| `OK` | Reached the model and answered. |
| `AUTH` | Could not authenticate — a mount or token is missing. **This is a sandbox problem.** |
| `ACCOUNT` | Authenticated, but the account or model was refused (quota, entitlement). |
| `CONFIG` | Inherited a host-only model or provider it cannot reach here. |
| `SKIP` | Not installed in this image. |
| `FAIL` | Something else; the raw output is printed. |

Only `AUTH` and `FAIL` point at the sandbox. `ACCOUNT` and `CONFIG` mean the
container is fine and the model choice needs attention on the host — OpenCode,
for example, defaults to a local Apple-Silicon model that no Linux container can
reach, so pass `--model` with a cloud model or change the host default.

---

## 🔑 Authentication

Host login sessions are mounted through, so most agents work with no extra setup.

**Claude Code** splits its state across two locations, only one of which is safe to share with the host:

| Location | Contents | How it is handled |
| :--- | :--- | :--- |
| `~/.claude/` | settings, skills, hooks, `.credentials.json` | Mounted from the host, read-write |
| `~/.claude.json` | onboarding flag, `oauthAccount`, user-scope MCP servers, project trust | **Container-dedicated**, stored in `state/claude.json` |

The second file is kept separate on purpose: it holds macOS-specific host state that a Linux
container should not overwrite. Without it mounted at all, every `--rm` run would restart
onboarding and ask you to log in again.

### Deterministic login (recommended)

On macOS the OAuth token may live only in the Keychain, which a Linux container cannot read.
If the sandbox greets you with `Not logged in`, generate a long-lived token on the host:

```bash
claude setup-token
```

Then put it in `agent-docker.env`:

```bash
CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-...
```

`agent-docker.env` is git-ignored. `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY`,
`GH_TOKEN`, and `GITHUB_TOKEN` are passed through from your shell environment as well.

---

## 🔧 Git Inside the Sandbox

The host `~/.gitconfig` is deliberately **not** mounted — it typically references host-only
tools (`delta`, `neovide`, a Homebrew `gh` path, a `required = true` LFS filter) that do not
exist in the image and would break every `git` invocation.

Instead the entrypoint generates a container-local `~/.gitconfig`:

* `safe.directory = *` — Docker Desktop exposes the bind mount under a different UID than the container user, which otherwise makes git refuse every command with `detected dubious ownership`. The wildcard covers submodules, nested repositories and worktrees too; everything reachable here is already inside the container.
* `credential.helper = !gh auth git-credential` — uses the container's own `gh`.
* `init.defaultBranch = main`.

Your commit identity is read from the host's global git config and passed through as
`GIT_USER_NAME` / `GIT_USER_EMAIL`, so commits made inside the sandbox are attributed to you.

---

## 🔒 Security & Sandbox Architecture

```text
[Host Machine]
  ~/.ssh, ~/.aws, ~/Documents, other repos  ──► 🛡️ Not mounted
  $(pwd) (Current Project Directory)        ──► 📂 Bound to /workspace
  ~/.gemini ~/.claude ~/.codex              ──► ⚠️ Mounted READ-WRITE
  ~/.agents ~/.hermes ~/.config/gh          ──► ⚠️ Mounted READ-WRITE

[Docker Container (/workspace)]
  Developer User (Matched UID/GID to Host)
  ├── Pre-baked runtimes: uv (Python), Node 22 (pnpm), Rust (cargo), ast-grep
  ├── Camoufox Anti-Detect Browser & MCP Server (xvfb, GUI libs, CJK fonts)
  └── AI Agent CLI (Runs in auto-approval mode within sandbox boundary)
```

1. **Volume Bind Mount (`-v "$PWD:/workspace"`)**: Only the active project folder is exposed.
2. **Credential Passthrough**: Authentication directories from `$HOME` are mounted so you do not have to re-login.
3. **UID/GID Mapping**: Matches the container user to the host user to prevent root file permission locks.
4. **Multiplexer IPC Passthrough**: Forwards `HERDR_SOCKET` and sets process names so Herdr tracks agent states in real-time.

### ⚠️ What this does *not* protect against

The agent config directories are mounted **read-write on purpose**, so that skills, plugins,
and agent settings can be edited from inside the sandbox. The consequence is that an agent
running with auto-approval can:

* modify `~/.claude/settings.json` hooks — **which then execute on your host** the next time you run the agent outside Docker;
* modify or add skills and plugins under `~/.claude` and `~/.agents`;
* use the mounted `~/.config/gh` credentials to push to any repository you have access to.

The container entrypoint prints this warning on every launch. Treat the sandbox as protection
for *your project files and unrelated repositories*, not as a boundary against a hostile agent.
If you need stronger isolation, remove the config mounts from `run.sh` and accept re-login and
loss of shared skills.

### Agent self-updates

Self-updating is disabled: `DISABLE_AUTOUPDATER=1` (Claude Code),
`OPENCODE_DISABLE_AUTOUPDATE=1` and `AGY_CLI_DISABLE_AUTO_UPDATE=true`. Codex needs no
variable — its npm launcher sets `CODEX_MANAGED_BY_NPM`, which already suppresses
self-update.

Agents are installed as root but run as the unprivileged `developer` user, and `--rm` would
discard any runtime update anyway. The image is the unit of versioning — run
`agent-docker --update` periodically, since nothing will now update itself.

---

## 📂 Repository Structure

```text
~/.config/agent-docker/
├── Dockerfile              # Unified multi-agent base image with all toolchains
├── entrypoint.sh           # Container entrypoint: MCP + git auto-configuration
├── run.sh                  # Intelligent launcher, credential router, and Herdr bridge
├── install.sh              # Interactive agent selection & build installer
├── smoke-test.sh           # One-prompt health check for every installed agent
├── agent-docker.env        # Your local config: agents to install, auth tokens (git-ignored)
├── agent-docker.env.example # Template for the above
├── docker-compose.yml      # Compose definition, kept in sync with run.sh
├── state/                  # Persistent container-side agent state (git-ignored)
├── README.md               # English documentation
└── README_KR.md            # Korean documentation
```

---

## 📄 License

Distributed under the [MIT License](LICENSE).
