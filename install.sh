#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"

echo "============================================================"
echo " 🤖 Installing Agent-Docker Universal AI Sandbox CLI"
echo "============================================================"

# Ensure ~/.local/bin exists
mkdir -p "$BIN_DIR"

# Create symlinks
SYMLINKS=(
  "agent-docker"
  "agy-docker"
  "claude-docker"
  "codex-docker"
  "opencode-docker"
  "hermes-docker"
)

echo "🔗 Creating command symlinks in $BIN_DIR..."
for cmd in "${SYMLINKS[@]}"; do
  ln -sf "$SCRIPT_DIR/run.sh" "$BIN_DIR/$cmd"
  echo "  ✓ $BIN_DIR/$cmd -> $SCRIPT_DIR/run.sh"
done

# Check PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo ""
  echo "⚠️  [Notice] $BIN_DIR is not in your current PATH."
  echo "   Add the following line to your ~/.zshrc or ~/.bashrc:"
  echo '   export PATH="$HOME/.local/bin:$PATH"'
fi

echo ""
echo "🔨 Building Docker sandbox image..."
"$SCRIPT_DIR/run.sh" --build

echo ""
echo "============================================================"
echo " 🎉 Agent-Docker successfully installed!"
echo " Run 'agent-docker --help' or 'agent-docker claude' to start."
echo "============================================================"
