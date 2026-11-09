#!/usr/bin/env bash
# Link this folder to ~/.config/smv and its bin/ scripts into ~/.local/bin.
# Safe to run again; never replaces a real file.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)

link() {  # SOURCE TARGET
  if [ -e "$2" ] && [ ! -L "$2" ]; then
    echo "skip    $2 (a real file is there; move it into $here first)"; return
  fi
  mkdir -p "$(dirname "$2")"
  ln -sfn "$1" "$2"
  echo "linked  $2 -> $1"
}

link "$here" "$HOME/.config/smv"
for f in "$here"/bin/*; do
  [ -f "$f" ] && link "$f" "$HOME/.local/bin/$(basename "$f")"
done
