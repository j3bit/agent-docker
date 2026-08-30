# Universal Multi-Agent Isolated Sandbox (AGY, Claude Code, OpenCode, Hermes, etc.)
FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# 1. Install standard dev tools, runtimes, and dependencies (including headless browser/GUI libs for Camoufox)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    git-lfs \
    bubblewrap \
    socat \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    ripgrep \
    fd-find \
    jq \
    tree \
    sudo \
    gosu \
    xvfb \
    libgtk-3-0 \
    libdbus-glib-1-2 \
    libxtst6 \
    libxss1 \
    libnss3 \
    libasound2t64 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    fonts-noto-cjk \
    fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

# Install modern Node.js (v22 LTS), pnpm, and ast-grep (sg)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g pnpm \
    && npm install -g --force @ast-grep/cli \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (gh)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install Rust toolchain (rustup, rustc, cargo)
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH="/usr/local/cargo/bin:${PATH}"
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal \
    && chmod -R a+w /usr/local/rustup /usr/local/cargo

# Symlink fdfind to fd if needed
RUN ln -s $(which fdfind) /usr/local/bin/fd 2>/dev/null || true

# Install uv & uvx (ultra-fast Python package manager)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# Install Camoufox (Anti-Detect Stealth Browser for AI Agents), Playwright, and Camoufox MCP Server
RUN pip install --no-cache-dir --break-system-packages "camoufox[geoip]" "camoufox-mcp" "mcp<2" playwright \
    && (npm install -g --force @andrew-chen-wang/camoufox-mcp 2>/dev/null || true)

# Build Arguments for Conditional Agent Installation (default: only agy is true)
ARG INSTALL_AGY=true
ARG INSTALL_CLAUDE=false
ARG INSTALL_CODEX=false
ARG INSTALL_OPENCODE=false
ARG INSTALL_HERMES=false

# 2. AI Coding Agents Installation (Conditionally installed based on build args)
#
# Every block verifies that the requested binary is actually resolvable before
# the layer succeeds. Silently swallowing installer errors produces an image
# that builds green but is missing the agent the user asked for, which only
# surfaces much later as "command not found".
#
# `curl | bash` cannot be trusted to report failure: if curl 404s, bash still
# reads an empty script and exits 0. The explicit check below is what actually
# catches a failed install, so keep it on every agent.

# Antigravity CLI (agy)
RUN if [ "$INSTALL_AGY" = "true" ]; then \
      echo "📦 Installing Antigravity CLI (agy)..." \
      && curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- -d /usr/local/bin \
      && { command -v agy > /dev/null \
           || { echo "❌ agy was requested but is not on PATH after install"; exit 1; }; }; \
    fi

# Claude Code CLI (claude)
RUN if [ "$INSTALL_CLAUDE" = "true" ]; then \
      echo "📦 Installing Claude Code CLI (claude)..." \
      && npm install -g @anthropic-ai/claude-code \
      && { command -v claude > /dev/null \
           || { echo "❌ claude was requested but is not on PATH after install"; exit 1; }; }; \
    fi

# OpenAI Codex CLI (codex)
# npm only: there is no official standalone install script (codex.openai.com does
# not resolve), so a curl fallback would just be a silent no-op.
RUN if [ "$INSTALL_CODEX" = "true" ]; then \
      echo "📦 Installing OpenAI Codex CLI (codex)..." \
      && npm install -g @openai/codex \
      && { command -v codex > /dev/null \
           || { echo "❌ codex was requested but is not on PATH after install"; exit 1; }; }; \
    fi

# OpenCode CLI (opencode) -- npm is primary, the official installer is the fallback.
# Note the installer lives at /install, not /install.sh (which 404s).
RUN if [ "$INSTALL_OPENCODE" = "true" ]; then \
      echo "📦 Installing OpenCode CLI (opencode)..." \
      && (npm install -g opencode-ai \
          || curl -fsSL https://opencode.ai/install | bash) \
      && { command -v opencode > /dev/null \
           || { echo "❌ opencode was requested but is not on PATH after install"; exit 1; }; }; \
    fi

# Hermes Agent (hermes)
RUN if [ "$INSTALL_HERMES" = "true" ]; then \
      echo "📦 Installing Hermes Agent (hermes)..." \
      && pip install --no-cache-dir --break-system-packages hermes-agent \
      && { command -v hermes > /dev/null \
           || { echo "❌ hermes was requested but is not on PATH after install"; exit 1; }; }; \
    fi

# Disable agent self-updates. Agents are installed as root into /usr/lib/node_modules
# but run as the unprivileged `developer` user, so a self-update cannot write there
# and fails on every launch. Even with the permissions opened up it would be wasted
# work: containers run with `--rm`, so an update downloaded at runtime is discarded
# on exit and re-downloaded on the next launch. The image is the unit of versioning
# here -- use `agent-docker --update` (docker build --no-cache --pull) to upgrade.
#
# One variable per agent; there is no shared convention. Codex needs none: its npm
# launcher sets CODEX_MANAGED_BY_NPM, which already suppresses self-update.
ENV DISABLE_AUTOUPDATER=1
ENV OPENCODE_DISABLE_AUTOUPDATE=1
ENV AGY_CLI_DISABLE_AUTO_UPDATE=true

# 3. Create a non-root developer user (UID 1000) with passwordless sudo
ARG USER_NAME=developer
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd -g ${USER_GID} ${USER_NAME} 2>/dev/null || true \
    && useradd -m -s /bin/bash -u ${USER_UID} -g ${USER_GID} ${USER_NAME} 2>/dev/null || true \
    && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Pre-fetch Camoufox browser binaries for developer user
RUN su ${USER_NAME} -c "python3 -m camoufox fetch"

# Environment variables for user and binary PATHs
ENV HOME=/home/${USER_NAME}
ENV PATH="/usr/local/cargo/bin:/home/${USER_NAME}/.gemini/antigravity-cli/bin:/home/${USER_NAME}/.local/bin:/usr/local/bin:${PATH}"

# Re-verify every requested agent as the unprivileged runtime user.
# The per-agent checks during installation run as root, so an installer that drops
# its binary somewhere only root can reach (the Antigravity installer reports
# /root/.local/bin, for instance) would satisfy them and still be missing at
# runtime. This is the check that matches how the container is actually used.
RUN for spec in "$INSTALL_AGY:agy" "$INSTALL_CLAUDE:claude" "$INSTALL_CODEX:codex" \
                "$INSTALL_OPENCODE:opencode" "$INSTALL_HERMES:hermes"; do \
      want="${spec%%:*}"; bin="${spec##*:}"; \
      [ "$want" = "true" ] || continue; \
      su ${USER_NAME} -s /bin/sh -c "PATH='$PATH' command -v $bin > /dev/null" \
        || { echo "❌ $bin is installed but not reachable by ${USER_NAME} at runtime"; exit 1; }; \
    done

# Workspace directory
WORKDIR /workspace

# Copy entrypoint script and any custom Linux binaries (if present in bin/)
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY bin/ /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && (chmod +x /usr/local/bin/agy 2>/dev/null || true)

USER ${USER_NAME}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["agy", "--dangerously-skip-permissions"]
