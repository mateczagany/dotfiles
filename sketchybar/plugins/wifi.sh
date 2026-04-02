#!/usr/bin/env bash

set -euo pipefail

ITEM_NAME="wifi"
POPUP_PREFIX="${ITEM_NAME}.popup"
OTHER_ITEM="bluetooth"
SKETCHYBAR="/opt/homebrew/bin/sketchybar"
NETWORKSETUP="/usr/sbin/networksetup"
IPCONFIG="/usr/sbin/ipconfig"
SYSTEM_PROFILER="/usr/sbin/system_profiler"
BASE64="/usr/bin/base64"
OSASCRIPT="/usr/bin/osascript"
SLEEP="/bin/sleep"
JQ="/opt/homebrew/bin/jq"
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

trim_leading_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  printf '%s\n' "$value"
}

get_wifi_device() {
  local saw_wifi=0
  local line

  while IFS= read -r line; do
    case "$line" in
      "Hardware Port: Wi-Fi")
        saw_wifi=1
        ;;
      Device:*)
        if [[ $saw_wifi -eq 1 ]]; then
          printf '%s\n' "${line#Device: }"
          return 0
        fi
        ;;
      "")
        saw_wifi=0
        ;;
    esac
  done < <("$NETWORKSETUP" -listallhardwareports)

  return 1
}

get_wifi_power() {
  local device="$1"
  local output

  output="$("$NETWORKSETUP" -getairportpower "$device" 2>/dev/null || true)"
  printf '%s\n' "${output##* }"
}

get_current_ssid() {
  local device="$1"
  local summary
  local ssid
  local line
  local output

  summary="$("$IPCONFIG" getsummary "$device" 2>/dev/null || true)"
  while IFS= read -r line; do
    line="$(trim_leading_whitespace "$line")"
    case "$line" in
      SSID\ :\ *)
        ssid="${line#SSID : }"
        if [[ -n "$ssid" && "$ssid" != "<redacted>" ]]; then
          printf '%s\n' "$ssid"
          return 0
        fi
        ;;
    esac
  done <<<"$summary"

  ssid="$(
    "$SYSTEM_PROFILER" -json SPAirPortDataType 2>/dev/null | "$JQ" -r --arg device "$device" '
      .SPAirPortDataType[0].spairport_airport_interfaces
      | map(select(._name == $device) | .spairport_current_network_information._name // empty)
      | map(select(length > 0 and . != "<redacted>"))
      | .[0] // empty
    '
  )"
  if [[ -n "$ssid" ]]; then
    printf '%s\n' "$ssid"
    return 0
  fi

  output="$("$NETWORKSETUP" -getairportnetwork "$device" 2>/dev/null || true)"

  case "$output" in
    Current\ Wi-Fi\ Network:*)
      printf '%s\n' "${output#Current Wi-Fi Network: }"
      ;;
    Current\ AirPort\ Network:*)
      printf '%s\n' "${output#Current AirPort Network: }"
      ;;
    *)
      printf '\n'
      ;;
  esac
}

contains_value() {
  local needle="$1"
  shift

  local value
  for value in "$@"; do
    if [[ "$value" == "$needle" ]]; then
      return 0
    fi
  done

  return 1
}

list_popup_networks() {
  local device="$1"
  local current_ssid="$2"
  local line
  local ssid
  local -a preferred_networks=()
  local -a selected_networks=()

  while IFS= read -r line; do
    case "$line" in
      Preferred\ networks\ on\ *)
        continue
        ;;
      "")
        continue
        ;;
      *)
        ssid="$(trim_leading_whitespace "$line")"
        if [[ -n "$ssid" ]]; then
          preferred_networks+=("$ssid")
        fi
        ;;
    esac
  done < <("$NETWORKSETUP" -listpreferredwirelessnetworks "$device" 2>/dev/null || true)

  # Keep the current network visible even if it fell below the top saved entries.
  if [[ -n "$current_ssid" ]]; then
    selected_networks+=("$current_ssid")
  fi

  for ssid in "${preferred_networks[@]}"; do
    if contains_value "$ssid" "${selected_networks[@]}"; then
      continue
    fi

    selected_networks+=("$ssid")
    if [[ ${#selected_networks[@]} -ge 12 ]]; then
      break
    fi
  done

  printf '%s\n' "${selected_networks[@]}"
}

popup_state() {
  "$JQ" -r '.popup.drawing' < <("$SKETCHYBAR" --query "$ITEM_NAME")
}

current_item_ssid() {
  local label

  label="$("$JQ" -r '.label.value // empty' < <("$SKETCHYBAR" --query "$ITEM_NAME"))"
  case "$label" in
    ""|Off|Disconnected|Unavailable)
      printf '\n'
      ;;
    *)
      printf '%s\n' "$label"
      ;;
  esac
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

refresh_item() {
  local device
  local power
  local current_ssid
  local icon
  local label

  device="$(get_wifi_device 2>/dev/null || true)"
  if [[ -z "$device" ]]; then
    icon="󰤮"
    label="Unavailable"
  else
    power="$(get_wifi_power "$device")"
    if [[ "$power" == "Off" ]]; then
      icon="󰤮"
      label="Off"
    else
      current_ssid="$(get_current_ssid "$device")"
      if [[ -n "$current_ssid" ]]; then
        icon="󰤨"
        label="$current_ssid"
      else
        icon="󰤭"
        label="Disconnected"
      fi
    fi
  fi

  "$SKETCHYBAR" --set "$ITEM_NAME" icon="$icon" label="$label"
}

build_popup() {
  local device
  local current_ssid
  local ssid
  local popup_item
  local encoded_ssid
  local icon
  local click_script
  local index=1

  device="$(get_wifi_device 2>/dev/null || true)"
  current_ssid="$(current_item_ssid)"

  remove_popup_items

  if [[ -z "$device" ]]; then
    "$SKETCHYBAR" --add item "${POPUP_PREFIX}.1" "popup.$ITEM_NAME" \
                 --set "${POPUP_PREFIX}.1" icon="󰤮" label="Wi-Fi unavailable" click_script=""
    return
  fi

  while IFS= read -r ssid; do
    if [[ -z "$ssid" ]]; then
      continue
    fi

    popup_item="${POPUP_PREFIX}.${index}"
    icon="󰤯"
    encoded_ssid="$(printf '%s' "$ssid" | "$BASE64")"
    click_script="$SCRIPT_PATH connect $encoded_ssid"

    if [[ "$ssid" == "$current_ssid" ]]; then
      icon="󰤨"
      click_script=""
    fi

    "$SKETCHYBAR" --add item "$popup_item" "popup.$ITEM_NAME" \
                 --set "$popup_item" \
                       icon="$icon" \
                       label="$ssid" \
                       label.max_chars=40 \
                       click_script="$click_script"

    index=$((index + 1))
  done < <(list_popup_networks "$device" "$current_ssid")

  if [[ $index -eq 1 ]]; then
    "$SKETCHYBAR" --add item "${POPUP_PREFIX}.1" "popup.$ITEM_NAME" \
                 --set "${POPUP_PREFIX}.1" icon="󰤭" label="No saved networks" click_script=""
  fi
}

toggle_popup() {
  if [[ "$(popup_state)" == "on" ]]; then
    hide_popup
    return
  fi

  hide_other_popup
  build_popup
  "$SKETCHYBAR" --set "$ITEM_NAME" popup.drawing=on
}

connect_network() {
  local encoded_ssid="$1"
  local device
  local ssid

  device="$(get_wifi_device 2>/dev/null || true)"
  if [[ -z "$device" ]]; then
    notify "Wi-Fi interface not found."
    return 1
  fi

  ssid="$(printf '%s' "$encoded_ssid" | "$BASE64" -D 2>/dev/null || true)"
  if [[ -z "$ssid" ]]; then
    notify "Invalid Wi-Fi network selection."
    return 1
  fi

  if ! "$NETWORKSETUP" -setairportnetwork "$device" "$ssid" >/dev/null 2>&1; then
    notify "Failed to connect to $ssid."
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
    connect_network "${2:-}"
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
