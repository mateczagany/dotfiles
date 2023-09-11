#!/usr/bin/env bash

current=$(tmux display-message -p '#S')
selected=$(tmux list-sessions | grep -v $current | fzf)

if [[ -z $selected ]]; then
    exit 0
fi

selected_name=$(echo $selected | cut -d ":" -f1)
tmux switch-client -t $selected_name
