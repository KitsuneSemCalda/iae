#!/usr/bin/env bash
# Startup-time guardrail: building the 4-role workspace must stay under a
# fixed budget in every layout state, so iae never feels slower than a
# hand-built tmux setup. Runs on an isolated tmux server.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SOCK="iae-startup-$$"
tmux() { command tmux -L "$SOCK" "$@"; }
BUDGET_MS="${IAE_STARTUP_BUDGET_MS:-1000}"

PROJECT_DIR="$(mktemp -d)"
cleanup() {
  tmux kill-server 2>/dev/null || true
  rm -rf "$PROJECT_DIR"
}
trap cleanup EXIT

git -C "$PROJECT_DIR" init -q
# shellcheck source=../lib/layout.sh
source "$REPO_ROOT/lib/layout.sh"

now_ms() { date +%s%3N; }

for state in wide grid compact; do
  start="$(now_ms)"
  layout_build_initial "startup-$state" "$state" "$PROJECT_DIR" true "true" 200 50
  elapsed=$(($(now_ms) - start))
  echo "startup $state: ${elapsed}ms (budget ${BUDGET_MS}ms)"
  [ "$elapsed" -le "$BUDGET_MS" ] || {
    echo "FAIL: $state startup ${elapsed}ms exceeds ${BUDGET_MS}ms" >&2
    exit 1
  }
done
echo "OK: startup time within budget"
