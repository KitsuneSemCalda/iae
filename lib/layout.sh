#!/usr/bin/env bash
# Layout state machine for iae: picks between "wide", "grid" and "compact"
# pane arrangements based on terminal size, and can reflow a running session
# from one arrangement to another without restarting the programs inside it.
#
# Panes are identified by a per-pane user option (@iae-role: editor, agent,
# shell or git) instead of by position or index, since panes move between
# windows across a reflow. The option survives join-pane/break-pane because
# those relocate the pane itself rather than recreating it — unlike pane
# titles, it can't be clobbered by a program inside the pane setting its own
# terminal title.

WIDE_MIN_COLS=180
WIDE_MIN_LINES=45
GRID_MIN_COLS=120
GRID_MIN_LINES=34

WIDE_AGENT_PCT=35
WIDE_SHELL_PCT=35
WIDE_GIT_PCT=60

GRID_PCT=50

COMPACT_AGENT_PCT=50
COMPACT_GIT_PCT=60

detect_layout() {
  local cols=$1 lines=$2
  if [ "$cols" -ge "$WIDE_MIN_COLS" ] && [ "$lines" -ge "$WIDE_MIN_LINES" ]; then
    echo wide
  elif [ "$cols" -ge "$GRID_MIN_COLS" ] && [ "$lines" -ge "$GRID_MIN_LINES" ]; then
    echo grid
  else
    echo compact
  fi
}

tag_pane_role() {
  tmux set-option -p -t "$1" @iae-role "$2"
}

find_pane_by_role() {
  local session=$1 role=$2
  tmux list-panes -s -t "$session" -F '#{pane_id} #{@iae-role}' |
    awk -v r="$role" '$2 == r { print $1; exit }'
}

# Builds a brand new session with the given state's pane arrangement.
# Prints nothing; the caller doesn't need pane IDs after this, since a
# reflow always re-derives them from @iae-role.
layout_build_initial() {
  local session=$1 state=$2 project_dir=$3 editor_cmd=$4 git_tool=$5 cols=$6 lines=$7
  local agent_cmd=${8:-"omarchy agent --inline"}

  local editor_pane
  editor_pane=$(tmux new-session -d -s "$session" -x "$cols" -y "$lines" -c "$project_dir" -n main -P -F '#{pane_id}')
  tag_pane_role "$editor_pane" editor
  tmux send-keys -t "$editor_pane" "$editor_cmd ." C-m

  local agent_pane shell_pane git_pane
  case "$state" in
    wide)
      agent_pane=$(tmux split-window -t "$editor_pane" -h -l "${WIDE_AGENT_PCT}%" -c "$project_dir" -P -F '#{pane_id}')
      tmux select-pane -t "$editor_pane"
      shell_pane=$(tmux split-window -t "$editor_pane" -v -l "${WIDE_SHELL_PCT}%" -c "$project_dir" -P -F '#{pane_id}')
      git_pane=$(tmux split-window -t "$shell_pane" -h -l "${WIDE_GIT_PCT}%" -c "$project_dir" -P -F '#{pane_id}')
      ;;
    grid)
      agent_pane=$(tmux split-window -t "$editor_pane" -h -l "${GRID_PCT}%" -c "$project_dir" -P -F '#{pane_id}')
      tmux select-pane -t "$editor_pane"
      shell_pane=$(tmux split-window -t "$editor_pane" -v -l "${GRID_PCT}%" -c "$project_dir" -P -F '#{pane_id}')
      git_pane=$(tmux split-window -t "$agent_pane" -v -l "${GRID_PCT}%" -c "$project_dir" -P -F '#{pane_id}')
      ;;
    compact)
      agent_pane=$(tmux split-window -t "$editor_pane" -v -l "${COMPACT_AGENT_PCT}%" -c "$project_dir" -P -F '#{pane_id}')
      tmux rename-window -t "$editor_pane" work
      shell_pane=$(tmux new-window -d -t "$session" -n inspect -c "$project_dir" -P -F '#{pane_id}')
      git_pane=$(tmux split-window -t "$shell_pane" -h -l "${COMPACT_GIT_PCT}%" -c "$project_dir" -P -F '#{pane_id}')
      ;;
  esac

  tag_pane_role "$agent_pane" agent
  tag_pane_role "$shell_pane" shell
  tag_pane_role "$git_pane" git
  tmux send-keys -t "$agent_pane" "$agent_cmd" C-m

  if git -C "$project_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    tmux send-keys -t "$git_pane" "$git_tool" C-m
  else
    tmux send-keys -t "$git_pane" "echo 'iae: not a git repository, $git_tool not started (run git init if you want one)'" C-m
  fi

  tmux set-option -t "$session" @iae-layout "$state"
  tmux select-pane -t "$editor_pane"
}

# Moves the four tracked panes (wherever they currently are) into the given
# state's arrangement, without touching the programs running inside them.
# No-ops if any tracked pane has been closed since — reconstructing a
# 4-pane layout out of 3 panes would just be guessing.
layout_reflow() {
  local session=$1 state=$2

  local editor_pane agent_pane shell_pane git_pane
  editor_pane=$(find_pane_by_role "$session" editor)
  agent_pane=$(find_pane_by_role "$session" agent)
  shell_pane=$(find_pane_by_role "$session" shell)
  git_pane=$(find_pane_by_role "$session" git)
  [ -n "$editor_pane" ] && [ -n "$agent_pane" ] && [ -n "$shell_pane" ] && [ -n "$git_pane" ] || return 0

  # Scatter every non-anchor pane into its own window first, so the rebuild
  # below never has to reason about whatever arrangement it's currently in.
  # Pin -t to this session: without it tmux drops the new window into whichever
  # session is current server-wide, stealing panes when other sessions exist.
  local pane
  for pane in "$agent_pane" "$shell_pane" "$git_pane"; do
    tmux break-pane -d -s "$pane" -t "$session:" 2>/dev/null || true
  done

  case "$state" in
    wide)
      tmux join-pane -s "$agent_pane" -t "$editor_pane" -h -l "${WIDE_AGENT_PCT}%"
      tmux join-pane -s "$shell_pane" -t "$editor_pane" -v -l "${WIDE_SHELL_PCT}%"
      tmux join-pane -s "$git_pane" -t "$shell_pane" -h -l "${WIDE_GIT_PCT}%"
      tmux rename-window -t "$editor_pane" main
      ;;
    grid)
      tmux join-pane -s "$agent_pane" -t "$editor_pane" -h -l "${GRID_PCT}%"
      tmux join-pane -s "$shell_pane" -t "$editor_pane" -v -l "${GRID_PCT}%"
      tmux join-pane -s "$git_pane" -t "$agent_pane" -v -l "${GRID_PCT}%"
      tmux rename-window -t "$editor_pane" main
      ;;
    compact)
      tmux join-pane -s "$agent_pane" -t "$editor_pane" -v -l "${COMPACT_AGENT_PCT}%"
      tmux rename-window -t "$editor_pane" work
      tmux join-pane -s "$git_pane" -t "$shell_pane" -h -l "${COMPACT_GIT_PCT}%"
      tmux rename-window -t "$shell_pane" inspect
      ;;
  esac

  tmux select-window -t "$editor_pane"
  tmux set-option -t "$session" @iae-layout "$state"
}

# Registers the resize hook that drives reflow. Scoped to this one session
# (no -g), so it never fires for the user's other, unrelated tmux sessions.
layout_install_resize_hook() {
  local session=$1 script_path=$2
  tmux set-hook -t "$session" window-resized \
    "run-shell -b '$script_path --reflow $session'"
}
