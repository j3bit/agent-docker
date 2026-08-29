#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"

INSTALL_ALL=0
SELECTED_ANY=0
NO_BUILD=0

INSTALL_AGY=false
INSTALL_CLAUDE=false
INSTALL_CODEX=false
INSTALL_OPENCODE=false
INSTALL_HERMES=false

show_help() {
  echo "Usage: ./install.sh [OPTIONS]"
  echo ""
  echo "Install Agent-Docker CLI and optionally select specific agents to build."
  echo "If no agent options are specified, ALL agents are installed by default."
  echo ""
  echo "Options:"
  echo "  -a, --all               Install all AI agents (Default)"
  echo "      --agy               Install Google Antigravity (agy)"
  echo "      --claude            Install Anthropic Claude Code (claude)"
  echo "      --codex             Install OpenAI Codex (codex)"
  echo "      --opencode          Install OpenCode (opencode)"
  echo "      --hermes            Install Hermes Agent (hermes)"
  echo "      --no-build          Only create CLI symlinks without building Docker image"
  echo "  -h, --help              Show this help message"
  echo ""
  echo "Examples:"
  echo "  ./install.sh                    # Install all agents"
  echo "  ./install.sh --claude --codex   # Install only Claude Code and Codex"
  echo "  ./install.sh --agy              # Install only Antigravity"
  echo ""
}

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -a|--all)
      INSTALL_ALL=1
      shift
      ;;
    --agy|--antigravity)
      INSTALL_AGY=true
      SELECTED_ANY=1
      shift
      ;;
    --claude|--claudecode)
      INSTALL_CLAUDE=true
      SELECTED_ANY=1
      shift
      ;;
    --codex)
      INSTALL_CODEX=true
      SELECTED_ANY=1
      shift
      ;;
    --opencode)
      INSTALL_OPENCODE=true
      SELECTED_ANY=1
      shift
      ;;
    --hermes)
      INSTALL_HERMES=true
      SELECTED_ANY=1
      shift
      ;;
    --no-build)
      NO_BUILD=1
      shift
      ;;
    *)
      echo "❌ Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# If no specific agent was selected or --all was specified, activate all
if [ "$SELECTED_ANY" -eq 0 ] || [ "$INSTALL_ALL" -eq 1 ]; then
  INSTALL_AGY=true
  INSTALL_CLAUDE=true
  INSTALL_CODEX=true
  INSTALL_OPENCODE=true
  INSTALL_HERMES=true
fi

echo "============================================================"
echo " 🤖 Installing Agent-Docker Universal AI Sandbox CLI"
echo "============================================================"
echo "Selected Agents to Install:"
[ "$INSTALL_AGY" = "true" ]      && echo "  ✓ Google Antigravity (agy)"
[ "$INSTALL_CLAUDE" = "true" ]   && echo "  ✓ Anthropic Claude Code (claude)"
[ "$INSTALL_CODEX" = "true" ]    && echo "  ✓ OpenAI Codex (codex)"
[ "$INSTALL_OPENCODE" = "true" ] && echo "  ✓ OpenCode (opencode)"
[ "$INSTALL_HERMES" = "true" ]   && echo "  ✓ Hermes Agent (hermes)"
echo "============================================================"

# Ensure ~/.local/bin exists
mkdir -p "$BIN_DIR"

# Master command symlink (always installed)
ln -sf "$SCRIPT_DIR/run.sh" "$BIN_DIR/agent-docker"
echo "🔗 Created: $BIN_DIR/agent-docker"

# Create short symlinks for selected agents only
if [ "$INSTALL_AGY" = "true" ]; then
  ln -sf "$SCRIPT_DIR/run.sh" "$BIN_DIR/agy-docker"
  echo "🔗 Created: $BIN_DIR/agy-docker"
fi

if [ "$INSTALL_CLAUDE" = "true" ]; then
  ln -sf "$SCRIPT_DIR/run.sh" "$BIN_DIR/claude-docker"
  echo "🔗 Created: $BIN_DIR/claude-docker"
fi

if [ "$INSTALL_CODEX" = "true" ]; then
  ln -sf "$SCRIPT_DIR/run.sh" "$BIN_DIR/codex-docker"
  echo "🔗 Created: $BIN_DIR/codex-docker"
fi

if [ "$INSTALL_OPENCODE" = "true" ]; then
  ln -sf "$SCRIPT_DIR/run.sh" "$BIN_DIR/opencode-docker"
  echo "🔗 Created: $BIN_DIR/opencode-docker"
fi

if [ "$INSTALL_HERMES" = "true" ]; then
  ln -sf "$SCRIPT_DIR/run.sh" "$BIN_DIR/hermes-docker"
  echo "🔗 Created: $BIN_DIR/hermes-docker"
fi

# Check PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo ""
  echo "⚠️  [Notice] $BIN_DIR is not in your current PATH."
  echo "   Add the following line to your ~/.zshrc or ~/.bashrc:"
  echo '   export PATH="$HOME/.local/bin:$PATH"'
fi

# Run Docker Build with custom build-args
if [ "$NO_BUILD" -eq 0 ]; then
  echo ""
  echo "🔨 Building Docker sandbox image with selected agents..."
  "$SCRIPT_DIR/run.sh" --build \
    --build-arg INSTALL_AGY="$INSTALL_AGY" \
    --build-arg INSTALL_CLAUDE="$INSTALL_CLAUDE" \
    --build-arg INSTALL_CODEX="$INSTALL_CODEX" \
    --build-arg INSTALL_OPENCODE="$INSTALL_OPENCODE" \
    --build-arg INSTALL_HERMES="$INSTALL_HERMES"
fi

echo ""
echo "============================================================"
echo " 🎉 Agent-Docker successfully installed!"
echo " Run 'agent-docker --help' or 'agent-docker claude' to start."
echo "============================================================"
