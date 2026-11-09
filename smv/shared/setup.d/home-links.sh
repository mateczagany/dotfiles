# Link each folder mounted from your Mac home at the same place under /home/dev, so
# ~/... paths in your dotfiles and CLAUDE.md imports mean the same thing on both sides.
awk '$3 == "virtiofs" && $2 ~ /^\/Users\/[^\/]+\/./ { print $2 }' /proc/mounts | sort -u |
while IFS= read -r m; do
  dst=$HOME/${m#/Users/*/}
  # A folder made here for mounts inside $m before $m itself was mounted holds only
  # folders and links into $m: one link to $m replaces it.
  if [ -d "$dst" ] && [ ! -L "$dst" ] &&
     [ -z "$(find "$dst" -mindepth 1 ! -type d ! -lname "$m/*" -print -quit)" ]; then
    rm -rf "$dst"
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then continue; fi
  mkdir -p "${dst%/*}"
  ln -s "$m" "$dst"
done
