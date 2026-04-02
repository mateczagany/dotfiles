#!/usr/bin/env bash

set -euo pipefail

ITEM_NAME="bluetooth"
POPUP_PREFIX="${ITEM_NAME}.popup"
OTHER_ITEM="wifi"
SKETCHYBAR="/opt/homebrew/bin/sketchybar"
BLUEUTIL="/opt/homebrew/bin/blueutil"
JQ="/opt/homebrew/bin/jq"
OSASCRIPT="/usr/bin/osascript"
SLEEP="/bin/sleep"
SYSTEM_PROFILER="/usr/sbin/system_profiler"
SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"

escape_applescript() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s\n' "$value"
}

notify() {
  local message
  message="$(escape_applescript "$1")"
  "$OSASCRIPT" -e "display notification \"$message\" with title \"SketchyBar\"" >/dev/null 2>&1 || true
}

paired_devices_json() {
  "$BLUEUTIL" --paired --format json 2>/dev/null || printf '[]\n'
}

bluetooth_profile_json() {
  "$SYSTEM_PROFILER" -json SPBluetoothDataType 2>/dev/null || printf '{"SPBluetoothDataType":[]}\n'
}

popup_state() {
  "$JQ" -r '.popup.drawing' < <("$SKETCHYBAR" --query "$ITEM_NAME")
}

hide_popup() {
  "$SKETCHYBAR" --set "$ITEM_NAME" popup.drawing=off
}

hide_other_popup() {
  "$SKETCHYBAR" --set "$OTHER_ITEM" popup.drawing=off >/dev/null 2>&1 || true
}

should_hide_for_sender() {
  case "${SENDER:-}" in
    mouse.exited.global|front_app_switched|space_change|display_change)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

remove_popup_items() {
  local regex="/${POPUP_PREFIX//./\\.}\\..*/"
  "$SKETCHYBAR" --remove "$regex" >/dev/null 2>&1 || true
}

bluetooth_power() {
  "$BLUEUTIL" --power 2>/dev/null || printf '0\n'
}

device_name_for_address() {
  local address="$1"
  local json="$2"

  "$JQ" -r --arg address "$address" 'map(select(.address == $address) | (.name // .address))[0] // empty' <<<"$json"
}

battery_summary_for_address() {
  local address="$1"
  local profile_json="$2"

  "$JQ" -r --arg address "$address" '
    [
      .SPBluetoothDataType[0]
      | to_entries[]?
      | select(.key | startswith("device_"))
      | .value[]?
      | to_entries[]
      | .value as $props
      | select((($props.device_address // "") | gsub(":"; "-") | ascii_downcase) == $address)
      | [
          ($props.device_batteryLevelMain // empty),
          (($props.device_batteryLevelLeft // empty) | if . == "" then empty else "L " + . end),
          (($props.device_batteryLevelRight // empty) | if . == "" then empty else "R " + . end),
          (($props.device_batteryLevelCase // empty) | if . == "" then empty else "C " + . end)
        ]
      | map(select(length > 0))
      | join(" ")
    ]
    | map(select(length > 0))
    | .[0] // empty
  ' <<<"$profile_json"
}

refresh_item() {
  local json
  local power
  local label
  local icon

  power="$(bluetooth_power)"
  if [[ "$power" != "1" ]]; then
    icon="󰂲"
    label="Off"
  else
    json="$(paired_devices_json)"
    label="$("$JQ" -r '[.[] | select(.connected == true) | (.name // .address)] | join(", ")' <<<"$json")"

    if [[ -n "$label" ]]; then
      icon="󰂱"
    else
      icon="󰂯"
      label="No devices"
    fi
  fi

  "$SKETCHYBAR" --set "$ITEM_NAME" icon="$icon" label="$label"
}

build_popup() {
  local json
  local profile_json
  local power
  local popup_item
  local click_script
  local icon
  local is_connected
  local name
  local address
  local battery_summary
  local label
  local index=1

  power="$(bluetooth_power)"
  json="$(paired_devices_json)"
  profile_json="$(bluetooth_profile_json)"

  remove_popup_items

  if [[ "$power" != "1" ]]; then
    "$SKETCHYBAR" --add item "${POPUP_PREFIX}.1" "popup.$ITEM_NAME" \
                 --set "${POPUP_PREFIX}.1" icon="󰂲" label="Bluetooth is off" click_script=""
    return
  fi

  while IFS=$'\t' read -r is_connected name address; do
    if [[ -z "$address" ]]; then
      continue
    fi

    popup_item="${POPUP_PREFIX}.${index}"
    icon="󰂯"
    click_script="$SCRIPT_PATH connect $address"
    battery_summary="$(battery_summary_for_address "$address" "$profile_json")"
    label="$name"

    if [[ -n "$battery_summary" ]]; then
      label="$label $battery_summary"
    fi

    if [[ "$is_connected" == "1" ]]; then
      icon="󰂱"
      click_script=""
    fi

    "$SKETCHYBAR" --add item "$popup_item" "popup.$ITEM_NAME" \
                 --set "$popup_item" \
                       icon="$icon" \
                       label="$label" \
                       label.max_chars=48 \
                       click_script="$click_script"

    index=$((index + 1))
  done < <(
    "$JQ" -r '
      sort_by([if .connected then 0 else 1 end, (.name // .address)])[]
      | [if .connected then "1" else "0" end, (.name // .address), .address]
      | @tsv
    ' <<<"$json"
  )

  if [[ $index -eq 1 ]]; then
    "$SKETCHYBAR" --add item "${POPUP_PREFIX}.1" "popup.$ITEM_NAME" \
                 --set "${POPUP_PREFIX}.1" icon="󰂯" label="No paired devices" click_script=""
  fi
}

toggle_popup() {
  refresh_item

  if [[ "$(popup_state)" == "on" ]]; then
    hide_popup
    return
  fi

  hide_other_popup
  build_popup
  "$SKETCHYBAR" --set "$ITEM_NAME" popup.drawing=on
}

connect_device() {
  local address="$1"
  local power
  local json
  local name

  if [[ -z "$address" ]]; then
    notify "Invalid Bluetooth device selection."
    return 1
  fi

  power="$(bluetooth_power)"
  if [[ "$power" != "1" ]]; then
    notify "Bluetooth is off."
    return 1
  fi

  json="$(paired_devices_json)"
  name="$(device_name_for_address "$address" "$json")"
  if [[ -z "$name" ]]; then
    name="$address"
  fi

  if ! "$BLUEUTIL" --connect "$address" >/dev/null 2>&1; then
    notify "Failed to connect to $name."
    return 1
  fi

  hide_popup
  "$SLEEP" 1
  refresh_item
}

case "${1:-}" in
  toggle)
    toggle_popup
    ;;
  connect)
    connect_device "${2:-}"
    ;;
  ""|update)
    if should_hide_for_sender; then
      hide_popup
    else
      refresh_item
    fi
    ;;
  *)
    refresh_item
    ;;
esac
