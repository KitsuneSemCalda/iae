#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

usage() {
  echo "Usage: install.sh [--uninstall] [target-dir]   (default target-dir: ~/.local/bin)"
}

UNINSTALL=0
case "${1:-}" in
  -h | --help) usage; exit 0 ;;
  --uninstall) UNINSTALL=1; shift ;;
  -*) echo "install.sh: unknown option '$1'" >&2; usage >&2; exit 2 ;;
esac

TARGET_DIR="${1:-$HOME/.local/bin}"

if [ "$UNINSTALL" = 1 ]; then
  if [ -L "$TARGET_DIR/iae" ]; then
    rm "$TARGET_DIR/iae"
    echo "iae: removed $TARGET_DIR/iae"
  else
    echo "iae: no symlink at $TARGET_DIR/iae, nothing to remove"
  fi
  exit 0
fi

mkdir -p "$TARGET_DIR"
ln -sfn "$SCRIPT_DIR/iae" "$TARGET_DIR/iae"

echo "iae: linked $TARGET_DIR/iae -> $SCRIPT_DIR/iae"

case ":$PATH:" in
  *":$TARGET_DIR:"*) ;;
  *)
    echo "iae: warning - '$TARGET_DIR' is not on your PATH, the 'iae' command won't be found" >&2
    ;;
esac
