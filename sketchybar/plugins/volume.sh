#!/usr/bin/env bash

current_volume() {
  osascript -e 'output volume of (get volume settings)' 2>/dev/null
}

render_volume() {
  local volume="$1"

  case "$volume" in
    [7-9][0-9]|100) ICON="󰕾"
    ;;
    [4-6][0-9]) ICON="󰖀"
    ;;
    [1-3][0-9]) ICON="󰕿"
    ;;
    *) ICON="󰖁"
  esac

  sketchybar --set "$NAME" icon="$ICON" label="$volume%"
}

case "${SENDER:-}" in
  volume_change)
    render_volume "$INFO"
    ;;
  *)
    VOLUME="${INFO:-$(current_volume)}"
    [ -z "$VOLUME" ] && exit 0
    render_volume "$VOLUME"
    ;;
esac
