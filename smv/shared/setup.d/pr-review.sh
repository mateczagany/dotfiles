mkdir -p "$HOME/.local/bin"
for f in /opt/claude-skills/pr-review/bin/pr-review-*; do
  [ -e "$f" ] || continue
  ln -sfn "$f" "$HOME/.local/bin/${f##*/}"
done

# $USER isn't set here and $HOME isn't the Mac home, so find the
# mounted Mac home under /Users. Set MAC_HOME to override.
mac_home="${MAC_HOME:-}"
if [ -z "$mac_home" ]; then
  for d in /Users/*; do
    if [ -d "$d/dev/repos/skills/pr-review" ]; then
      mac_home=$d
      break
    fi
  done
fi
if [ -z "$mac_home" ]; then
  echo "pr-review: no Mac home with dev/repos/skills/pr-review under /Users" >&2
  exit 1
fi

# Reports land in the Mac's ~/dev/reviews (rw-mounts), then the skill's own installer.
mkdir -p "$HOME/dev"
[ -L "$HOME/dev/reviews" ] || rmdir "$HOME/dev/reviews" 2>/dev/null || true
[ -e "$HOME/dev/reviews" ] || ln -sfn "$mac_home/dev/reviews" "$HOME/dev/reviews"
bash "$mac_home/dev/repos/skills/pr-review/install.sh" >/dev/null
