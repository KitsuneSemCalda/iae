#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TARGET_DIR="${1:-$HOME/.local/bin}"

mkdir -p "$TARGET_DIR"
ln -sfn "$SCRIPT_DIR/iae" "$TARGET_DIR/iae"

echo "iae: link criado em $TARGET_DIR/iae -> $SCRIPT_DIR/iae"

case ":$PATH:" in
  *":$TARGET_DIR:"*) ;;
  *)
    echo "iae: aviso - '$TARGET_DIR' não está no seu PATH, o comando 'iae' não vai ser encontrado" >&2
    ;;
esac
