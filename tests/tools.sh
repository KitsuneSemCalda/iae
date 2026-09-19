#!/usr/bin/env bash
# Unit tests for lib/tools.sh: how iae picks the editor, agent and git tool,
# with and without the `omarchy` command center. Pure PATH stubs — no tmux.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/tools.sh
source "$REPO_ROOT/lib/tools.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Each case gets its own PATH holding only what it installs, so the host's
# real tools (and Omarchy itself) can't leak in. `sh`/`env` are called by
# absolute path via the shebang, so they don't need to be on it.
mkbin() { # mkbin <dir> <tool>...
  local dir=$1
  shift
  mkdir -p "$dir"
  for t in "$@"; do
    printf '#!/bin/sh\n' >"$dir/$t"
    chmod +x "$dir/$t"
  done
}
fake_omarchy() { # fake_omarchy <dir> <default-editor> <default-agent>
  cat >"$1/omarchy" <<SH
#!/bin/sh
case "\$1 \$2" in
  "default editor") echo "$2" ;;
  "default agent") echo "$3" ;;
  "cmd present") command -v "\$3" >/dev/null 2>&1 ;;
esac
SH
  chmod +x "$1/omarchy"
}
check() { # check <desc> <expected> <actual>
  [ "$2" = "$3" ] || {
    echo "FAIL: $1: expected '$2', got '$3'" >&2
    exit 1
  }
}

unset IAE_EDITOR IAE_AGENT IAE_GIT VISUAL EDITOR

# --- Omarchy present -----------------------------------------------------
B="$WORK/omarchy"
mkbin "$B" helix claude tig
fake_omarchy "$B" helix claude
check "omarchy editor" helix "$(PATH="$B" resolve_editor)"
check "omarchy agent" "omarchy agent --inline" "$(PATH="$B" resolve_agent)"
check "omarchy git" tig "$(PATH="$B" resolve_git_tool)"

# A GUI default editor is skipped in favour of a TUI fallback.
B="$WORK/gui"
mkbin "$B" vim
fake_omarchy "$B" code claude
check "gui editor falls back" vim "$(PATH="$B" resolve_editor)"

# Default agent set but not installed: fall back to a known agent.
B="$WORK/missing-agent"
mkbin "$B" nvim codex
fake_omarchy "$B" nvim claude
check "missing default agent" codex "$(PATH="$B" resolve_agent)"

# No default agent and nothing installed: unresolved.
B="$WORK/no-agent"
mkbin "$B" nvim
fake_omarchy "$B" nvim ""
if PATH="$B" resolve_agent >/dev/null; then
  echo "FAIL: agent should be unresolved" >&2
  exit 1
fi
echo "OK: omarchy resolution"

# --- Plain system (no omarchy) ------------------------------------------
B="$WORK/plain"
mkbin "$B" vim nano lazygit opencode
check "plain editor" vim "$(PATH="$B" resolve_editor)"
check "plain agent" opencode "$(PATH="$B" resolve_agent)"
check "plain git" lazygit "$(PATH="$B" resolve_git_tool)"
check "\$EDITOR wins over vim" nano "$(PATH="$B" EDITOR=nano resolve_editor)"

# --- Overrides ------------------------------------------------------------
check "IAE_AGENT" "myagent --x" "$(PATH="$B" IAE_AGENT="myagent --x" resolve_agent)"
check "IAE_EDITOR" nano "$(PATH="$B" IAE_EDITOR=nano resolve_editor)"
check "IAE_GIT" lazygit "$(PATH="$B" IAE_GIT=lazygit resolve_git_tool)"
echo "OK: fallbacks and overrides"
echo "ALL OK"
