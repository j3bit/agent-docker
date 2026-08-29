#!/usr/bin/env bash
set -e

# Resolve symlink to find real script directory
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
IMAGE_NAME="agy-docker-sandbox:latest"

# Detect agent type from script name ($0)
CALLER_NAME="$(basename "$0")"

# If called as agent-docker (or run.sh) and the first argument is a known agent name, route to that agent!
if [ "$CALLER_NAME" = "agent-docker" ] || [ "$CALLER_NAME" = "run.sh" ]; then
  case "${1:-}" in
    agy|antigravity)
      CALLER_NAME="agy-docker"
      shift
      ;;
    claude|claudecode)
      CALLER_NAME="claude-docker"
      shift
      ;;
    codex)
      CALLER_NAME="codex-docker"
      shift
      ;;
    opencode)
      CALLER_NAME="opencode-docker"
      shift
      ;;
    hermes)
      CALLER_NAME="hermes-docker"
      shift
      ;;
  esac
fi

AGENT_KIND="agy"
AGENT_BIN="agy"
HERDR_KIND="antigravity-cli"
DEFAULT_FLAGS=("--dangerously-skip-permissions")
AUTH_MOUNTS=()

case "$CALLER_NAME" in
  claude*|*claude*)
    AGENT_KIND="claude"
    AGENT_BIN="claude"
    HERDR_KIND="claude"
    DEFAULT_FLAGS=("--dangerously-skip-permissions")
    [ -d "$HOME/.claude" ] && AUTH_MOUNTS+=(-v "$HOME/.claude:/home/developer/.claude")
    ;;
  codex*|*codex*)
    AGENT_KIND="codex"
    AGENT_BIN="codex"
    HERDR_KIND="codex"
    DEFAULT_FLAGS=("--dangerously-bypass-approvals-and-sandbox")
    [ -d "$HOME/.codex" ] && AUTH_MOUNTS+=(-v "$HOME/.codex:/home/developer/.codex")
    ;;
  opencode*|*opencode*)
    AGENT_KIND="opencode"
    AGENT_BIN="opencode"
    HERDR_KIND="opencode"
    DEFAULT_FLAGS=("--auto")
    [ -d "$HOME/.config/opencode" ] && AUTH_MOUNTS+=(-v "$HOME/.config/opencode:/home/developer/.config/opencode")
    ;;
  hermes*|*hermes*)
    AGENT_KIND="hermes"
    AGENT_BIN="hermes"
    HERDR_KIND="hermes"
    DEFAULT_FLAGS=()
    [ -d "$HOME/.hermes" ] && AUTH_MOUNTS+=(-v "$HOME/.hermes:/home/developer/.hermes")
    ;;
  *)
    # Default to agy
    AGENT_KIND="agy"
    AGENT_BIN="agy"
    HERDR_KIND="antigravity-cli"
    DEFAULT_FLAGS=("--dangerously-skip-permissions")
    [ -d "$HOME/.gemini" ] && AUTH_MOUNTS+=(-v "$HOME/.gemini:/home/developer/.gemini")
    ;;
esac

# Mount GitHub CLI (gh) configuration if exists on host
if [ -d "$HOME/.config/gh" ]; then
  AUTH_MOUNTS+=(-v "$HOME/.config/gh:/home/developer/.config/gh")
fi

# Help message
show_help() {
  echo "Usage: $CALLER_NAME [OPTIONS] [TARGET_DIRECTORY] [-- AGENT_FLAGS...]"
  echo ""
  echo "Runs AI Coding Agent ($AGENT_KIND) inside a Docker container with strict filesystem isolation."
  echo "Defaults to the CURRENT WORKING DIRECTORY ($(pwd)) as the isolated workspace."
  echo ""
  echo "Options:"
  echo "  -b, --build       Rebuild the Docker image"
  echo "  -s, --shell       Open an interactive bash shell in the container instead of the agent"
  echo "  -h, --help        Show this help message"
  echo ""
  echo "Examples:"
  echo "  $CALLER_NAME                                  # Mounts current directory ($(pwd))"
  echo "  $CALLER_NAME /path/to/project                 # Mounts specific directory"
  echo "  $CALLER_NAME --shell                          # Open bash in current directory sandbox"
  echo ""
}

# Parse options
BUILD_ONLY=0
OPEN_SHELL=0
TARGET_DIR=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -b|--build)
      BUILD_ONLY=1
      shift
      ;;
    -s|--shell)
      OPEN_SHELL=1
      shift
      ;;
    --)
      shift
      EXTRA_ARGS+=("$@")
      break
      ;;
    -*)
      EXTRA_ARGS+=("$1")
      shift
      ;;
    *)
      if [ -z "$TARGET_DIR" ]; then
        TARGET_DIR="$1"
      else
        EXTRA_ARGS+=("$1")
      fi
      shift
      ;;
  esac
done

# Check Docker daemon
if ! docker info > /dev/null 2>&1; then
  echo "❌ Error: Docker daemon is not running. Please start Docker and try again."
  exit 1
fi

# Build image if requested or if it doesn't exist
if [ "$BUILD_ONLY" -eq 1 ] || ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
  echo "🔨 Building Docker image: $IMAGE_NAME..."
  USER_UID=$(id -u)
  USER_GID=$(id -g)
  docker build \
    --build-arg USER_UID="$USER_UID" \
    --build-arg USER_GID="$USER_GID" \
    -t "$IMAGE_NAME" \
    "$SCRIPT_DIR"
  echo "✅ Docker image built successfully."
  if [ "$BUILD_ONLY" -eq 1 ]; then
    exit 0
  fi
fi

# Determine target workspace directory (Default to current working directory where user ran the command)
if [ -z "$TARGET_DIR" ]; then
  TARGET_DIR="$(pwd)"
fi

# Resolve absolute path for target directory
if [ -d "$TARGET_DIR" ]; then
  TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
elif [ -d "$SCRIPT_DIR/$TARGET_DIR" ]; then
  TARGET_DIR="$(cd "$SCRIPT_DIR/$TARGET_DIR" && pwd)"
else
  echo "📁 Target directory '$TARGET_DIR' does not exist. Creating it..."
  mkdir -p "$TARGET_DIR"
  TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
fi

echo "🚀 Starting Isolated Sandbox [$AGENT_KIND]"
echo "📂 Workspace Mount: $TARGET_DIR -> /workspace"

# Persistent tool and package caches (uv, npm, pip, cargo) across all workspaces
CACHE_MOUNTS=(
  -v "agy-uv-cache:/home/developer/.cache/uv"
  -v "agy-npm-cache:/home/developer/.npm"
  -v "agy-pip-cache:/home/developer/.cache/pip"
  -v "agy-cargo-cache:/home/developer/.cargo/registry"
  -v "agy-cargo-git:/home/developer/.cargo/git"
)

# Dynamic TTY detection
DOCKER_FLAGS=(-i)
if [ -t 0 ] && [ -t 1 ]; then
  DOCKER_FLAGS+=(-t)
fi

# Herdr (AI terminal multiplexer) passthrough & socket forwarding
HERDR_MOUNTS=()
if [ -n "${HERDR_PANE_ID:-}" ]; then
  HERDR_MOUNTS+=(
    -e HERDR_PANE_ID="$HERDR_PANE_ID"
    -e HERDR_WORKSPACE_ID="${HERDR_WORKSPACE_ID:-}"
    -e HERDR_TAB_ID="${HERDR_TAB_ID:-}"
    -e HERDR_SOCKET="${HERDR_SOCKET:-}"
    -e HERDR_AGENT_KIND="$HERDR_KIND"
  )
fi

if [ -d "$HOME/.config/herdr" ]; then
  HERDR_MOUNTS+=(-v "$HOME/.config/herdr:/home/developer/.config/herdr")
fi

for sock in /tmp/herdr*.sock; do
  if [ -e "$sock" ]; then
    HERDR_MOUNTS+=(-v "$sock:$sock")
  fi
done

# Set terminal window/pane title for multiplexers (Herdr, tmux, Ghostty)
if [ -t 1 ]; then
  printf '\033]0;%s: %s\007' "$AGENT_KIND" "$(basename "$TARGET_DIR")"
  printf '\033]2;%s\007' "$AGENT_KIND"
fi

if [ "$OPEN_SHELL" -eq 1 ]; then
  # Interactive bash shell
  docker run "${DOCKER_FLAGS[@]}" --rm \
    -v "$TARGET_DIR:/workspace" \
    -w /workspace \
    "${AUTH_MOUNTS[@]}" \
    "${CACHE_MOUNTS[@]}" \
    "${HERDR_MOUNTS[@]}" \
    -e TERM="xterm-256color" \
    -e GEMINI_API_KEY="${GEMINI_API_KEY:-}" \
    -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
    -e OPENAI_API_KEY="${OPENAI_API_KEY:-}" \
    -e GH_TOKEN="${GH_TOKEN:-}" \
    -e GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
    --entrypoint /bin/bash \
    "$IMAGE_NAME"
else
  # Check if user already passed the agent's default auto-approval flag
  FLAG_FOUND=0
  for default_flag in "${DEFAULT_FLAGS[@]}"; do
    for arg in "${EXTRA_ARGS[@]}"; do
      if [ "$arg" = "$default_flag" ]; then
        FLAG_FOUND=1
        break 2
      fi
    done
  done

  if [ "$FLAG_FOUND" -eq 1 ] || [ "${#DEFAULT_FLAGS[@]}" -eq 0 ]; then
    EXEC_ARGS=("${EXTRA_ARGS[@]}")
  else
    EXEC_ARGS=("${DEFAULT_FLAGS[@]}" "${EXTRA_ARGS[@]}")
  fi

  exec -a "$AGENT_BIN" docker run "${DOCKER_FLAGS[@]}" --rm \
    -v "$TARGET_DIR:/workspace" \
    -w /workspace \
    "${AUTH_MOUNTS[@]}" \
    "${CACHE_MOUNTS[@]}" \
    "${HERDR_MOUNTS[@]}" \
    -e TERM="xterm-256color" \
    -e GEMINI_API_KEY="${GEMINI_API_KEY:-}" \
    -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
    -e OPENAI_API_KEY="${OPENAI_API_KEY:-}" \
    -e GH_TOKEN="${GH_TOKEN:-}" \
    -e GITHUB_TOKEN="${GITHUB_TOKEN:-}" \
    "$IMAGE_NAME" \
    "$AGENT_BIN" "${EXEC_ARGS[@]}"
fi
