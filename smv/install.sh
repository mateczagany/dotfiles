#!/usr/bin/env bash
# Link this folder to ~/.config/smv and its bin/ scripts into ~/.local/bin, and add
# the memory guard hook to ~/.claude/settings.json. Safe to run again; never
# replaces a real file, and backs up settings.json before changing it.
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

# Every machine can write its repo's memory folder in ~/.claude/projects (bin/smv
# mounts it), and Claude on the Mac loads MEMORY.md from there when a session starts.
# Claude follows symlinks, so a MEMORY.md linked to ~/.ssh/id_ed25519 would load the
# key. This SessionStart hook deletes symlinks and other non-regular files from every
# memory folder before that, and shows you what it deleted. The tag at the end is how
# this script finds the hook again.
GUARD_TAG=smv-memory-guard
GUARD=$(cat <<'EOF'
find ~/.claude/projects/*/memory -mindepth 1 ! -type f ! -type d -print -delete 2>/dev/null | jq -Rsc 'split("\n") | map(select(length > 0)) | select(length > 0) | {systemMessage: ("smv memory guard: deleted links or special files a machine may have planted in Claude memory folders: " + join(", "))}'; true  # smv-memory-guard
EOF
)

add_memory_guard() {
  local s="$HOME/.claude/settings.json" tmp backup="" verb
  if ! command -v jq >/dev/null; then
    echo "skip    $s: memory guard hook not added (needs jq: brew install jq), then run this again"; return
  fi
  mkdir -p "$HOME/.claude"
  if [ ! -s "$s" ]; then
    echo '{}' > "$s"
    echo "created $s"
    backup=none
  elif ! jq -e 'type == "object"' "$s" >/dev/null 2>&1; then
    echo "skip    $s: memory guard hook not added (the file isn't a JSON object; fix it, then run this again)"; return
  fi
  if jq -e --arg c "$GUARD" '[.hooks.SessionStart[]?.hooks[]? | select(.command? == $c)] | length == 1' "$s" >/dev/null 2>&1; then
    echo "ok      $s: memory guard hook already there"; return
  fi
  if jq -e --arg t "$GUARD_TAG" '[.hooks.SessionStart[]?.hooks[]? | select(.command? // "" | contains($t))] | length > 0' "$s" >/dev/null 2>&1; then
    verb="replaced an older"
  else
    verb="added the"
  fi
  tmp=$(mktemp "$s.XXXXXX")
  # Drop any earlier version of the hook, keep every other hook, append this one.
  if ! jq --arg c "$GUARD" --arg t "$GUARD_TAG" '
      .hooks.SessionStart = [
        (.hooks.SessionStart // [])[]
        | .hooks |= map(select(.command? // "" | contains($t) | not))
        | select(.hooks | length > 0)
      ] + [{hooks: [{type: "command", command: $c}]}]' "$s" > "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    echo "skip    $s: memory guard hook not added (jq could not merge it into .hooks.SessionStart; add the GUARD command from $here/install.sh there by hand)"; return
  fi
  if [ -z "$backup" ]; then
    backup=$(mktemp "$s.bak-smv-$(date +%Y%m%d-%H%M%S)-XXXX")
    cp -p "$s" "$backup"
  fi
  cat "$tmp" > "$s"                                # keeps the file's mode, and a symlink if it is one
  rm -f "$tmp"
  echo "hook    $s: $verb SessionStart hook $GUARD_TAG (backup: $backup)"
  echo "        it deletes links and other non-regular files from ~/.claude/projects/*/memory when a Claude session starts on this Mac"
}

link "$here" "$HOME/.config/smv"
for f in "$here"/bin/*; do
  [ -f "$f" ] && link "$f" "$HOME/.local/bin/$(basename "$f")"
done
add_memory_guard
