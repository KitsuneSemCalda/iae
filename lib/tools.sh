#!/usr/bin/env bash
# Tool resolution for iae: decides what runs in the editor, agent and git
# panes. On Omarchy this goes through the `omarchy` command center
# (`omarchy default ...`, `omarchy agent`, `omarchy cmd ...`) so iae follows
# whatever the user picked in Omarchy; elsewhere it falls back to env
# overrides and well-known tools on PATH.
#
# Each resolver prints the command line to run and returns 1 (with nothing
# on stdout) when it can't find anything.

on_omarchy() {
  command -v omarchy >/dev/null 2>&1
}

# True when the command's executable (first word) is installed.
tool_present() {
  local cmd=${1%% *}
  [ -n "$cmd" ] || return 1
  if on_omarchy; then
    omarchy cmd present "$cmd"
  else
    command -v "$cmd" >/dev/null 2>&1
  fi
}

# Same allowlist as `omarchy launch editor --inline`: only these are TUIs
# that are safe to run in a pane. A GUI default (code, zed, emacs, ...)
# would detach and leave the pane idle.
is_tui_editor() {
  case "${1##*/}" in
    nvim | vim | nano | micro | hx | helix | fresh) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_editor() {
  local candidate
  candidate="${IAE_EDITOR:-}"
  if [ -z "$candidate" ] && on_omarchy; then
    candidate="$(omarchy default editor 2>/dev/null || true)"
    is_tui_editor "$candidate" || candidate=""
  fi
  for candidate in "$candidate" "${VISUAL:-}" "${EDITOR:-}" nvim vim nano; do
    if tool_present "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

resolve_agent() {
  local candidate
  if [ -n "${IAE_AGENT:-}" ]; then
    echo "$IAE_AGENT"
    return 0
  fi
  if on_omarchy; then
    candidate="$(omarchy default agent 2>/dev/null || true)"
    # `omarchy agent` adds each agent's own unattended-mode flags and errors
    # inside the pane if the default isn't installed, so check it up front.
    if [ -n "$candidate" ] && tool_present "$candidate"; then
      echo "omarchy agent --inline"
      return 0
    fi
  fi
  for candidate in claude codex opencode gemini aider; do
    if tool_present "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

resolve_git_tool() {
  local candidate
  for candidate in ${IAE_GIT:-} tig lazygit; do
    if tool_present "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}
