# Contributing to iae

Thanks for helping out! iae is a small bash project; keep changes focused.

## Setup

```sh
git clone https://github.com/KitsuneSemCalda/iae.git
cd iae && ./install.sh
```

Needs `tmux`, `tig` or `lazygit`, and `shellcheck` for linting.

## Before opening a PR

```sh
bash -n iae install.sh lib/layout.sh lib/tools.sh tests/*.sh
shellcheck -x -P SCRIPTDIR iae install.sh lib/layout.sh lib/tools.sh tests/*.sh
./tests/tools.sh && ./tests/layout.sh && ./tests/smoke.sh && ./tests/startup.sh
```

The tests run on an isolated tmux server (`tmux -L`), so they never touch your
real sessions. CI runs the same checks.

## Guidelines

- Use [Conventional Commits](https://www.conventionalcommits.org) (`feat:`, `fix:`, `docs:`, `test:`, `ci:`, `chore:`), one logical change per commit.
- Never hardcode pane indexes (tmux `base-index` varies); find panes by their `@iae-role` option or pane ID.
- Go through the `omarchy` command (`omarchy default editor`, `omarchy agent --inline`, `omarchy cmd present`) rather than the `omarchy-*` binaries, and keep a non-Omarchy fallback.
- Prefer the user's/Omarchy's defaults over hardcoding a tool; offer an `IAE_*` override instead.
- Add or update tests for behavior changes, and update the README for user-facing ones.
