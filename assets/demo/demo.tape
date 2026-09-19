# Records assets/demo/iae.gif — run from the repo root:  vhs assets/demo/demo.tape
# Requires: vhs, ttyd, ffmpeg, tmux, tig (or lazygit), nvim.
Output assets/demo/iae.gif

Set Shell bash
Set FontSize 13
Set Width 1800
Set Height 1000
Set Padding 8
Set Theme "Catppuccin Mocha"
Set TypingSpeed 60ms
Set Framerate 24

# Hidden setup: fake agent on PATH, a private tmux server (own TMUX_TMPDIR,
# so the recording never touches your real sessions), and a background
# helper that resizes the session while iae is attached, so nothing is ever
# typed into a pane. wide -> grid -> compact -> wide.
Hide
Type "export PATH=$PWD/assets/demo/bin:$PWD:$PATH PS1='$ '; export TMUX_TMPDIR=$(mktemp -d) IAE_AGENT=omarchy-agent; unset TMUX; clear"
Enter
Type `(sleep 6; s=$(tmux ls -F '#S' | head -1); for sz in '140 38' '100 30' '200 50'; do tmux resize-window -t $s -x ${sz% *} -y ${sz#* }; sleep 5; done) &`
Enter
Type "clear"
Enter
Show

Type "iae"
Sleep 400ms
Enter
Sleep 22s
