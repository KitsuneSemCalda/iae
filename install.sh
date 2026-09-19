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
  if [ -f "$TARGET_DIR/iae" ] || [ -L "$TARGET_DIR/iae" ]; then
    rm "$TARGET_DIR/iae"
    echo "iae: removed $TARGET_DIR/iae"
  else
    echo "iae: no installation at $TARGET_DIR/iae, nothing to remove"
  fi
  exit 0
fi

mkdir -p "$TARGET_DIR"
# Build one executable, including its libraries, independent of this checkout.
# Rename a temporary file so upgrading a legacy symlink never writes into it.
STAGED="$(mktemp "$TARGET_DIR/.iae.XXXXXX")"
trap 'rm -f "$STAGED"' EXIT
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    'source "$SCRIPT_DIR/lib/layout.sh"') cat "$SCRIPT_DIR/lib/layout.sh" ;;
    'source "$SCRIPT_DIR/lib/tools.sh"') cat "$SCRIPT_DIR/lib/tools.sh" ;;
    *) printf '%s\n' "$line" ;;
  esac
done < "$SCRIPT_DIR/iae" > "$STAGED"
bash -n "$STAGED"
chmod 755 "$STAGED"
if [ -d "$TARGET_DIR/iae" ]; then
  echo "iae: refusing to replace directory $TARGET_DIR/iae" >&2
  exit 1
fi
mv -f "$STAGED" "$TARGET_DIR/iae"

echo "iae: installed $TARGET_DIR/iae"

case ":$PATH:" in
  *":$TARGET_DIR:"*) ;;
  *)
    echo "iae: warning - '$TARGET_DIR' is not on your PATH, the 'iae' command won't be found" >&2
    ;;
esac
