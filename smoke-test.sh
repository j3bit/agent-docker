#!/usr/bin/env bash
# Answer "does agent X actually work in the sandbox?" without launching a TUI.
#
# Each agent gets one throwaway prompt and is expected to echo a marker back.
# Only auth and plumbing are under test here, so read the result as:
#
#   OK      -- reached the model and answered
#   AUTH    -- could not authenticate; a mount or token is missing
#   ACCOUNT -- authenticated, but the account/model was refused (quota, entitlement)
#   CONFIG  -- the agent inherited a host-only model/provider it cannot reach here
#              (a localhost or Apple-Silicon-only endpoint, say). Pick a cloud
#              model with --model, or set one as the default in the host config.
#   FAIL    -- something else; the raw output is printed
#
# Pass agent names to limit the run: ./smoke-test.sh claude codex
set -u

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
IMAGE_NAME="agent-docker-sandbox:latest"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

MOUNTS=()
[ -d "$HOME/.gemini" ] && MOUNTS+=(-v "$HOME/.gemini:/home/developer/.gemini")
[ -d "$HOME/.claude" ] && MOUNTS+=(-v "$HOME/.claude:/home/developer/.claude")
[ -d "$HOME/.codex" ] && MOUNTS+=(-v "$HOME/.codex:/home/developer/.codex")
[ -d "$HOME/.agents" ] && MOUNTS+=(-v "$HOME/.agents:/home/developer/.agents")
[ -d "$HOME/.hermes" ] && MOUNTS+=(-v "$HOME/.hermes:/home/developer/.hermes")
[ -d "$HOME/.config/opencode" ] && MOUNTS+=(-v "$HOME/.config/opencode:/home/developer/.config/opencode")
[ -d "$HOME/.local/share/opencode" ] && MOUNTS+=(-v "$HOME/.local/share/opencode:/home/developer/.local/share/opencode")
[ -f "$SCRIPT_DIR/state/claude.json" ] && MOUNTS+=(-v "$SCRIPT_DIR/state/claude.json:/home/developer/.claude.json")

run_agent() {
  docker run --rm -i "${MOUNTS[@]}" -v "$WORK:/workspace" -w /workspace \
    -e HOST_HOME="$HOME" "$IMAGE_NAME" "$@" 2>&1
}

# classify <marker> <output>
classify() {
  local marker="$1" out="$2"
  if grep -q "$marker" <<<"$out"; then
    echo "OK"
  elif grep -qiE "not logged in|please run /login|unauthorized|401|invalid.*token|no such credential" <<<"$out"; then
    echo "AUTH"
  elif grep -qiE "usage limit|rate.?limit|429|not supported when using|quota|insufficient" <<<"$out"; then
    echo "ACCOUNT"
  elif grep -qiE "cannot connect to api|unable to connect|connection refused|localhost|127\.0\.0\.1" <<<"$out"; then
    echo "CONFIG"
  else
    echo "FAIL"
  fi
}

check() {
  local name="$1" marker="$2"; shift 2
  if ! docker run --rm --entrypoint /bin/sh "$IMAGE_NAME" -c "command -v $name" >/dev/null 2>&1; then
    printf '  %-10s %-8s not installed in this image\n' "$name" "SKIP"
    return
  fi
  local out verdict
  out="$(run_agent "$@")"
  verdict="$(classify "$marker" "$out")"
  printf '  %-10s %s\n' "$name" "$verdict"
  if [ "$verdict" = "FAIL" ]; then
    sed 's/^/      | /' <<<"$out" | tail -6
  fi
}

if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "❌ $IMAGE_NAME not built. Run: agent-docker --build"
  exit 1
fi

WANTED=("$@")
want() {
  [ "${#WANTED[@]}" -eq 0 ] && return 0
  local a; for a in "${WANTED[@]}"; do [ "$a" = "$1" ] && return 0; done
  return 1
}

echo "🔎 Sandbox agent smoke test ($IMAGE_NAME)"

want agy      && check agy      AGY-OK      agy --dangerously-skip-permissions --print "Reply with exactly: AGY-OK"
want claude   && check claude   CLAUDE-OK   claude --dangerously-skip-permissions -p "Reply with exactly: CLAUDE-OK"
want codex    && check codex    CODEX-OK    codex exec --skip-git-repo-check "Reply with exactly: CODEX-OK"
want opencode && check opencode OPENCODE-OK opencode run "Reply with exactly: OPENCODE-OK"
want hermes   && check hermes   HERMES-OK   hermes --yolo -z "Reply with exactly: HERMES-OK"

echo
echo "AUTH means a mount or token is missing. ACCOUNT and CONFIG both mean the"
echo "sandbox itself is fine and the model choice needs attention on the host."
