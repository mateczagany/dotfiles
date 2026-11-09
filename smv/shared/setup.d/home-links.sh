# Link each folder mounted from your Mac home at the same place under /home/dev, so
# ~/... paths in your dotfiles and CLAUDE.md imports mean the same thing on both sides.
awk '$3 == "virtiofs" && $2 ~ /^\/Users\/[^\/]+\/./ { print $2 }' /proc/mounts | sort -u |
while IFS= read -r m; do
  dst=$HOME/${m#/Users/*/}
  if [ -e "$dst" ] || [ -L "$dst" ]; then continue; fi
  mkdir -p "${dst%/*}"
  ln -s "$m" "$dst"
done
