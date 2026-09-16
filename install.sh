#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET_DIR="${1:-$HOME/.local/bin}"

mkdir -p "$TARGET_DIR"
ln -sfn "$SCRIPT_DIR/iae" "$TARGET_DIR/iae"

echo "iae: linked $TARGET_DIR/iae -> $SCRIPT_DIR/iae"

case ":$PATH:" in
  *":$TARGET_DIR:"*) ;;
  *)
    echo "iae: warning - '$TARGET_DIR' is not on your PATH, the 'iae' command won't be found" >&2
    ;;
esac
