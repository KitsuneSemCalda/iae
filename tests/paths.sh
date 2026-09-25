#!/usr/bin/env bash
# Regression test for the resize hook when iae's own executable path
# contains spaces (a supported case: install.sh accepts an arbitrary
# destination directory). Runs a real tmux session, resizes it, and asserts
# the window-resized hook still reflows it — the hook's command string goes
# through tmux's parser and then a shell, and a space in the path used to
# make the second parse split the path itself (see lib/layout.sh).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"
SOCK="iae-paths-$$"
tmux() { command tmux -L "$SOCK" "$@"; }

SESSION=""
cleanup() {
  [ -n "$SESSION" ] && tmux kill-session -t "$SESSION" 2>/dev/null || true
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Copy the script tree under a directory name containing spaces, so
# `readlink -f "${BASH_SOURCE[0]}"` inside iae resolves to a spaced path -
# reproducing the case a user gets by installing to a spaced destination.
SPACED_ROOT="$TEST_DIR/path with spaces"
mkdir -p "$SPACED_ROOT"
cp "$REPO_ROOT/iae" "$SPACED_ROOT/iae"
cp -r "$REPO_ROOT/lib" "$SPACED_ROOT/lib"
chmod +x "$SPACED_ROOT/iae"

PROJECT_DIR="$TEST_DIR/project"
mkdir -p "$PROJECT_DIR"
git -C "$PROJECT_DIR" init -q

STUB_BIN="$TEST_DIR/bin"
mkdir -p "$STUB_BIN"
cat >"$STUB_BIN/omarchy" <<'EOF'
#!/bin/sh
case "$1 $2" in
  "default editor") echo nvim ;;
  "default agent") echo stubagent ;;
  "cmd present") command -v "$3" >/dev/null 2>&1 ;;
  "agent --inline") exec sleep 3600 ;;
esac
EOF
printf '#!/bin/sh\nexec sleep 3600\n' >"$STUB_BIN/stubagent"
chmod +x "$STUB_BIN/omarchy" "$STUB_BIN/stubagent"

REAL_TMUX="$(type -P tmux)"
cat >"$STUB_BIN/tmux" <<EOF
#!/bin/sh
exec "$REAL_TMUX" -L "$SOCK" "\$@"
EOF
chmod +x "$STUB_BIN/tmux"

SESSION="iae-$(basename "$PROJECT_DIR" | tr '.: ' '_')-$(printf '%s' "$PROJECT_DIR" | cksum | cut -d' ' -f1)"

PATH="$STUB_BIN:$PATH" "$SPACED_ROOT/iae" "$PROJECT_DIR" </dev/null >/dev/null 2>&1 || true

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "FAIL: session '$SESSION' was not created from a spaced install path" >&2
  exit 1
fi
echo "OK: iae launched correctly from a path containing spaces"

tmux resize-window -t "$SESSION:work" -x 140 -y 40

LAYOUT=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
  LAYOUT="$(tmux show-options -qv -t "$SESSION" @iae-layout)"
  [ "$LAYOUT" = grid ] && break
  sleep 0.3
done

if [ "$LAYOUT" != grid ]; then
  echo "FAIL: resize hook did not reflow the session when iae's path contains spaces (layout is '$LAYOUT')" >&2
  exit 1
fi

echo "OK: resize hook reflows correctly when iae's own path contains spaces"
