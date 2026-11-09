#!/usr/bin/env bash
# Pick a repo or worktree, then open or switch to its tmux session.

if [[ $# -eq 1 ]]; then
    selected=$1
else
    selected=$(
        {
            find ~/dev/repos ~/dev/datasqrl -mindepth 1 -maxdepth 1 -type d -not -name '.*'
            find ~/dev/repos/*/.worktrees ~/dev/datasqrl/*/.worktrees ~/dev/datasqrl/.worktrees \
                -mindepth 1 -maxdepth 1 -type d 2>/dev/null
            echo "$HOME/dev/datasqrl"
        } | fzf
    )
fi

[[ -n $selected ]] || exit 0
selected=${selected%/}

# api, or api@fix-billing for a worktree; tmux names can't contain . or :
if [[ $selected == */.worktrees/* ]]; then
    name="$(basename "${selected%%/.worktrees/*}")@$(basename "$selected")"
else
    name=$(basename "$selected")
fi
name=${name//[.:]/_}

if ! tmux has-session -t "=$name" 2>/dev/null; then
    tmux new-session -ds "$name" -c "$selected"
    # Claude in the repo's machine, in a second window (git repos only)
    if git -C "$selected" rev-parse --git-dir >/dev/null 2>&1; then
        tmux new-window -d -t "=$name:" -n claude -c "$selected" "$HOME/dev/repos/dotfiles/scripts/smv claude"
    fi
fi

if [[ -n $TMUX ]]; then
    tmux switch-client -t "=$name"
else
    tmux attach-session -t "=$name"
fi
