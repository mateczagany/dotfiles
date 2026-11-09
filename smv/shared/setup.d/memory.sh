# Claude's memory folder for this repo is the Mac's own, which bin/smv mounts at its
# Mac path, so Claude here and Claude on the Mac read and write one set of memories.
# home-links.sh links it into ~/.claude on a new machine. This does the same on a
# machine that already has its own memory folder, after moving those memories over.
common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
main=$(cd "$(dirname "$common")" && pwd -P) || exit 0
key=$(printf '%s' "$main" | sed 's/[^A-Za-z0-9]/-/g')
src=$(ls -d /Users/*/.claude/projects/"$key"/memory 2>/dev/null | head -n 1)
dst=$HOME/.claude/projects/$key/memory

[ -n "$src" ] || exit 0                          # not mounted yet: smv adds it at the next open
[ "$(readlink "$dst")" = "$src" ] && exit 0
[ -L "$dst" ] && rm -f "$dst"                    # a link to somewhere else

if [ -d "$dst" ]; then
  moved=0
  # Both sides keep an index; add the machine's lines the Mac's lacks.
  if [ -f "$dst/MEMORY.md" ] && [ -f "$src/MEMORY.md" ]; then
    [ -z "$(tail -c 1 "$src/MEMORY.md")" ] || echo >> "$src/MEMORY.md"
    grep -vxF -f "$src/MEMORY.md" "$dst/MEMORY.md" >> "$src/MEMORY.md"
    rm -f "$dst/MEMORY.md"
    moved=$((moved + 1))
  fi
  for f in "$dst"/* "$dst"/.[!.]*; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    [ -e "$src/${f##*/}" ] || [ -L "$src/${f##*/}" ] && continue   # never overwrite the Mac's
    mv "$f" "$src/" && moved=$((moved + 1))
  done
  [ "$moved" -eq 0 ] || echo "memory.sh: moved $moved memory files from this machine into the Mac's folder, $src" >&2
  if ! rmdir "$dst" 2>/dev/null; then
    echo "memory.sh: both this machine and the Mac have $(ls -A "$dst" | tr '\n' ' ' | sed 's/ $//'); merge them from $dst into $src and delete $dst, then start Claude again" >&2
    exit 1
  fi
fi
mkdir -p "${dst%/*}"
ln -s "$src" "$dst" 2>/dev/null || [ -L "$dst" ]
