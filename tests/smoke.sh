#!/usr/bin/env bash
# Smoke test: launches the real iae script (not lib/layout.sh directly)
# against a scratch git repo, on an isolated tmux server, then:
#   1. asserts the initial session/pane layout matches what a 80x24
#      terminal (the default when there's no real tty, as in CI) should get
#   2. simulates a live resize and asserts the window-resized hook actually
#      reflows the session, proving the hook was registered with a working
#      script path and argument string, not just that lib/layout.sh works
#      in isolation (see tests/layout.sh for that).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_DIR="$(mktemp -d)"
SOCK="iae-smoke-$$"
tmux() { command tmux -L "$SOCK" "$@"; }

SESSION=""
cleanup() {
  [ -n "$SESSION" ] && tmux kill-session -t "$SESSION" 2>/dev/null || true
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

git -C "$TEST_DIR" init -q

# The omarchy command only exists on real Omarchy installs, and the tmux CLI
# needs to point at our isolated test server instead of the caller's real
# one — stub both so this test runs anywhere, including plain CI runners.
STUB_BIN="$TEST_DIR/bin"
mkdir -p "$STUB_BIN"

# A fake `omarchy` command center: reports nvim/stubagent as the defaults so
# iae's Omarchy code path runs on any machine, and never launches a real agent.
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

# CLI surface: --help / --version exit 0, unknown flags exit 2.
"$REPO_ROOT/iae" --help | grep -q '^Usage: iae' || { echo "FAIL: --help"; exit 1; }
"$REPO_ROOT/iae" --version | grep -q '^iae ' || { echo "FAIL: --version"; exit 1; }
rc=0; "$REPO_ROOT/iae" --bogus 2>/dev/null || rc=$?
[ "$rc" = 2 ] || { echo "FAIL: unknown flag exit code $rc"; exit 1; }
echo "OK: CLI flags"

SESSION="iae-$(basename "$TEST_DIR" | tr '.: ' '_')-$(printf '%s' "$TEST_DIR" | cksum | cut -d' ' -f1)"

# No controlling terminal here, so `stty size` fails and iae falls back to
# 80x24 — which lands in "compact" (two windows) per lib/layout.sh's
# thresholds. The final `tmux attach-session` then fails for the same
# reason (no tty), which is expected: by then the session is already built.
PATH="$STUB_BIN:$PATH" "$REPO_ROOT/iae" "$TEST_DIR" </dev/null >/dev/null 2>&1 || true

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "FAIL: session '$SESSION' was not created" >&2
  exit 1
fi

PANE_COUNT="$(tmux list-panes -s -t "$SESSION" | wc -l)"
if [ "$PANE_COUNT" -ne 4 ]; then
  echo "FAIL: expected 4 panes across the session, got $PANE_COUNT" >&2
  exit 1
fi

LAYOUT="$(tmux show-options -qv -t "$SESSION" @iae-layout)"
if [ "$LAYOUT" != compact ]; then
  echo "FAIL: expected initial layout 'compact' for an 80x24 terminal, got '$LAYOUT'" >&2
  exit 1
fi

WINDOW_COUNT="$(tmux list-windows -t "$SESSION" | wc -l)"
if [ "$WINDOW_COUNT" -ne 2 ]; then
  echo "FAIL: expected 2 windows in compact layout, got $WINDOW_COUNT" >&2
  exit 1
fi

echo "OK: iae created session '$SESSION' in compact layout (4 panes, 2 windows)"

# Grow the terminal past the grid threshold and confirm the resize hook
# actually reflows the running session (registered with a script path and
# session name that both resolve correctly when tmux invokes the hook).
tmux resize-window -t "$SESSION:work" -x 140 -y 40

for _ in 1 2 3 4 5 6 7 8 9 10; do
  LAYOUT="$(tmux show-options -qv -t "$SESSION" @iae-layout)"
  [ "$LAYOUT" = grid ] && break
  sleep 0.3
done

if [ "$LAYOUT" != grid ]; then
  echo "FAIL: resizing past the grid threshold did not reflow the session (layout is '$LAYOUT')" >&2
  exit 1
fi

WINDOW_COUNT="$(tmux list-windows -t "$SESSION" | wc -l)"
PANE_COUNT="$(tmux list-panes -s -t "$SESSION" | wc -l)"
if [ "$WINDOW_COUNT" -ne 1 ] || [ "$PANE_COUNT" -ne 4 ]; then
  echo "FAIL: expected a single 4-pane window after reflowing to grid, got $WINDOW_COUNT window(s)/$PANE_COUNT pane(s)" >&2
  exit 1
fi

echo "OK: live resize past the grid threshold reflowed the session automatically"
