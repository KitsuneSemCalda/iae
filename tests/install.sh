#!/usr/bin/env bash
# Installation must survive removal of the checkout, including legacy upgrades.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEMP_ROOT"' EXIT
mkdir -p "$TEMP_ROOT/clone" "$TEMP_ROOT/bin"
cp "$REPO_ROOT/iae" "$REPO_ROOT/install.sh" "$TEMP_ROOT/clone/"
cp -R "$REPO_ROOT/lib" "$TEMP_ROOT/clone/"
ln -s "$TEMP_ROOT/clone/iae" "$TEMP_ROOT/bin/iae"
bash "$TEMP_ROOT/clone/install.sh" "$TEMP_ROOT/bin"
[ ! -L "$TEMP_ROOT/bin/iae" ]
cmp "$REPO_ROOT/iae" "$TEMP_ROOT/clone/iae"
bash "$TEMP_ROOT/clone/install.sh" "$TEMP_ROOT/bin"
mv "$TEMP_ROOT/clone" "$TEMP_ROOT/removed-clone"
[ "$("$TEMP_ROOT/bin/iae" --version)" = 'iae 0.2.0' ]
"$TEMP_ROOT/bin/iae" --help > /dev/null
bash "$TEMP_ROOT/removed-clone/install.sh" --uninstall "$TEMP_ROOT/bin"
[ ! -e "$TEMP_ROOT/bin/iae" ]
# Fresh installs also work; directories at the executable path are protected.
bash "$TEMP_ROOT/removed-clone/install.sh" "$TEMP_ROOT/bin"
bash "$TEMP_ROOT/removed-clone/install.sh" --uninstall "$TEMP_ROOT/bin"
mkdir "$TEMP_ROOT/bin/iae"
if bash "$TEMP_ROOT/removed-clone/install.sh" "$TEMP_ROOT/bin"; then
  echo 'FAIL: accepted a directory as the executable' >&2
  exit 1
fi
[ -d "$TEMP_ROOT/bin/iae" ]
echo 'OK: independent installation, upgrade, uninstall and directory protection'
