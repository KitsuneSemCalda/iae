#!/usr/bin/env bash
# Unit-level tests for lib/layout.sh: the wide/grid/compact state machine,
# run against an isolated tmux server so they can't disturb the caller's
# real sessions.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SOCK="iae-test-$$"
tmux() { command tmux -L "$SOCK" "$@"; }

PROJECT_DIR="$(mktemp -d)"
cleanup() {
  tmux kill-server 2>/dev/null || true
  rm -rf "$PROJECT_DIR"
}
trap cleanup EXIT

git -C "$PROJECT_DIR" init -q
# shellcheck source=../lib/layout.sh
source "$REPO_ROOT/lib/layout.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# --- detect_layout boundaries ------------------------------------------------

[ "$(detect_layout 180 45)" = wide ] || fail "180x45 should be wide"
[ "$(detect_layout 179 45)" = grid ] || fail "179x45 should be grid (cols below wide)"
[ "$(detect_layout 180 44)" = grid ] || fail "180x44 should be grid (lines below wide)"
[ "$(detect_layout 120 34)" = grid ] || fail "120x34 should be grid"
[ "$(detect_layout 119 34)" = compact ] || fail "119x34 should be compact (cols below grid)"
[ "$(detect_layout 120 33)" = compact ] || fail "120x33 should be compact (lines below grid)"
echo "OK: detect_layout boundaries"

# --- layout_build_initial: pane/window shape per state -----------------------

assert_panes() {
  local session=$1 expected=$2
  local actual
  actual="$(tmux list-panes -s -t "$session" | wc -l)"
  [ "$actual" -eq "$expected" ] || fail "$session: expected $expected panes, got $actual"
}

assert_windows() {
  local session=$1 expected=$2
  local actual
  actual="$(tmux list-windows -t "$session" | wc -l)"
  [ "$actual" -eq "$expected" ] || fail "$session: expected $expected windows, got $actual"
}

assert_role_exists() {
  local session=$1 role=$2
  [ -n "$(find_pane_by_role "$session" "$role")" ] || fail "$session: no pane tagged '$role'"
}

for state in wide grid compact; do
  session="build-$state"
  layout_build_initial "$session" "$state" "$PROJECT_DIR" bash "echo git" 200 50
  assert_panes "$session" 4
  if [ "$state" = compact ]; then
    assert_windows "$session" 2
  else
    assert_windows "$session" 1
  fi
  for role in editor agent shell git; do
    assert_role_exists "$session" "$role"
  done
  [ "$(tmux show-options -qv -t "$session" @iae-layout)" = "$state" ] \
    || fail "$session: @iae-layout not set to $state"
done
echo "OK: layout_build_initial shapes"

# --- layout_reflow: every transition preserves running processes ------------

session="reflow-cycle"
layout_build_initial "$session" compact "$PROJECT_DIR" bash "echo git" 80 24

declare -A pids
for role in editor agent shell git; do
  pane="$(find_pane_by_role "$session" "$role")"
  pids[$role]="$(tmux display-message -p -t "$pane" '#{pane_pid}')"
done

for state in grid wide compact grid wide compact; do
  layout_reflow "$session" "$state"

  assert_panes "$session" 4
  if [ "$state" = compact ]; then
    assert_windows "$session" 2
  else
    assert_windows "$session" 1
  fi
  [ "$(tmux show-options -qv -t "$session" @iae-layout)" = "$state" ] \
    || fail "$session: @iae-layout not updated to $state"

  for role in editor agent shell git; do
    pane="$(find_pane_by_role "$session" "$role")"
    pid="$(tmux display-message -p -t "$pane" '#{pane_pid}')"
    [ "$pid" = "${pids[$role]}" ] \
      || fail "$session: $role pid changed across reflow to $state (${pids[$role]} -> $pid)"
  done
done
echo "OK: layout_reflow preserves pane processes across wide/grid/compact"

# --- layout_reflow: no-op when the pane set is incomplete --------------------

session="reflow-missing-pane"
layout_build_initial "$session" grid "$PROJECT_DIR" bash "echo git" 200 50
git_pane="$(find_pane_by_role "$session" git)"
tmux kill-pane -t "$git_pane"
layout_reflow "$session" compact
[ "$(tmux show-options -qv -t "$session" @iae-layout)" = grid ] \
  || fail "@iae-layout should stay 'grid' when a tracked pane is missing"
echo "OK: layout_reflow no-ops when a tracked pane was closed"

echo "ALL OK"
