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

if [ "$workspace" = "$focused_workspace" ]; then
    background_drawing=on
else
    background_drawing=off
fi

if [ -n "$workspace_icons" ]; then
    sketchybar --set "$NAME" \
        background.drawing="$background_drawing" \
        icon="$workspace" \
        label="$workspace_icons" \
        label.drawing=on
else
    sketchybar --set "$NAME" \
        background.drawing="$background_drawing" \
        icon="$workspace" \
        label="" \
        label.drawing=off
fi
