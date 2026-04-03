#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../helpers/icon_map.sh"

workspace="$1"
focused_workspace="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"
workspace_icons=""
workspace_apps="$(aerospace list-windows --workspace "$workspace" --format '%{app-name}' 2>/dev/null | awk 'NF && !seen[$0]++')"

if [ -n "$workspace_apps" ]; then
    while IFS= read -r app_name; do
        [ -z "$app_name" ] && continue
        __icon_map "$app_name"

        if [ -n "$workspace_icons" ]; then
            workspace_icons="$workspace_icons $icon_result"
        else
            workspace_icons="$icon_result"
        fi
    done <<EOF
$workspace_apps
EOF
fi

background_drawing=off
icon_color="${DIM_COLOR:-0x66c0caf5}"
label_color="${DIM_COLOR:-0x66c0caf5}"
label_drawing=off

if [ "$workspace" = "$focused_workspace" ]; then
    background_drawing=on
    icon_color="${ACTIVE_TEXT_COLOR:-0xff1f2335}"
    label_color="${ACTIVE_TEXT_COLOR:-0xff1f2335}"

    if [ -n "$workspace_icons" ]; then
        label_drawing=on
    fi
elif [ -n "$workspace_icons" ]; then
    icon_color="${ICON_COLOR:-0xffc0caf5}"
    label_color="${ICON_COLOR:-0xffc0caf5}"
    label_drawing=on
fi

sketchybar --set "$NAME" \
    background.drawing="$background_drawing" \
    icon="$workspace" \
    icon.color="$icon_color" \
    label="$workspace_icons" \
    label.color="$label_color" \
    label.drawing="$label_drawing"
