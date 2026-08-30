#!/usr/bin/env bash

set -u

operation=${1:-status}

have() {
  command -v "$1" >/dev/null 2>&1
}

json_status() {
  local backend=$1 available=$2 connectivity=$3 wifi_enabled=$4 wifi_device=$5 wired_device=$6 connected=$7 networks=$8
  jq -cn \
    --arg backend "$backend" \
    --arg connectivity "$connectivity" \
    --argjson available "$available" \
    --argjson wifiEnabled "$wifi_enabled" \
    --argjson wifiDevice "$wifi_device" \
    --argjson wiredDevice "$wired_device" \
    --argjson connectedNetwork "$connected" \
    --argjson wifiNetworks "$networks" \
    '{kind: "status", backend: $backend, available: $available, connectivity: $connectivity, wifiEnabled: $wifiEnabled, wifiDevice: $wifiDevice, wiredDevice: $wiredDevice, connectedNetwork: $connectedNetwork, wifiNetworks: $wifiNetworks}'
}

empty_status() {
  json_status "none" false "Unknown" false null null null '[]'
}

network_security() {
  local value=${1:-}
  if [[ -z $value || $value == "--" ]]; then
    printf 'Open'
  elif [[ $value == *WPA3* ]]; then
    printf 'WPA3'
  elif [[ $value == *WPA2* || ${value,,} == *psk* ]]; then
    printf 'WPA2'
  elif [[ $value == *WEP* ]]; then
    printf 'WEP'
  elif [[ $value == *EAP* || $value == *802.1X* ]]; then
    printf 'Enterprise'
  else
    printf '%s' "$value"
  fi
}

signal_from_rssi() {
  local rssi=${1:--100}
  rssi=$(grep -oE -- '-?[0-9]+' <<<"$rssi" | head -n 1)
  [[ -n $rssi ]] || rssi=-100
  if ((rssi < -200 || rssi > 200)); then
    rssi=$((rssi / 100))
  fi
  jq -cn --arg value "$rssi" '((($value | tonumber? // -100) + 90) / 60 | if . < 0 then 0 elif . > 1 then 1 else . end)'
}

device_json() {
  local name=$1 type=$2 state=$3 address=$4 link=$5 speed=$6 network=$7
  jq -cn \
    --arg name "$name" --arg type "$type" --arg state "$state" --arg address "$address" \
    --argjson hasLink "$link" --argjson linkSpeed "$speed" --argjson network "$network" \
    '{name: $name, type: $type, state: $state, address: $address, hasLink: $hasLink, linkSpeed: $linkSpeed, network: $network}'
}

wifi_network_json() {
  local name=$1 connected=$2 known=$3 security=$4 strength=$5 bssid=${6:-}
  jq -cn \
    --arg name "$name" --arg security "$security" --arg bssid "$bssid" \
    --argjson connected "$connected" --argjson known "$known" --argjson signalStrength "$strength" \
    '{name: $name, connected: $connected, known: $known, security: $security, signalStrength: $signalStrength, bssid: $bssid}'
}

contains_network() {
  local networks=$1 name=$2
  grep -Fqx -- "$name" <<<"$networks"
}

wireless_link() {
  local device=$1 link ssid rssi
  link=$(iw dev "$device" link 2>/dev/null || true)
  ssid=$(awk '/SSID:/ { sub(/.*SSID: /, ""); print; exit }' <<<"$link")
  rssi=$(awk '/signal:/ { print $2; exit }' <<<"$link")
  printf '%s\n%s\n' "$ssid" "$rssi"
}

generic_wired_json() {
  local device="" line state connection address carrier speed network
  if have nmcli; then
    while IFS=: read -r candidate type candidate_state; do
      if [[ $type == "ethernet" ]]; then
        device=$candidate
        state=$candidate_state
        break
      fi
    done < <(LC_ALL=C nmcli -t -e no -f DEVICE,TYPE,STATE device status 2>/dev/null || true)
  fi

  if [[ -z $device ]] && have ip; then
    device=$(ip -j route get 1.1.1.1 2>/dev/null | jq -r '.[0].dev // ""' 2>/dev/null || true)
    [[ -d /sys/class/net/$device/wireless ]] && device=""
  fi
  [[ -z $device || ! -e /sys/class/net/$device ]] && { printf 'null'; return; }

  carrier=$(<"/sys/class/net/$device/carrier" 2>/dev/null || printf '0')
  speed=$(<"/sys/class/net/$device/speed" 2>/dev/null || printf '0')
  [[ $speed =~ ^[0-9]+$ ]] || speed=0
  connection=""
  address=$(<"/sys/class/net/$device/address" 2>/dev/null || true)
  if have nmcli; then
    connection=$(LC_ALL=C nmcli -g GENERAL.CONNECTION device show "$device" 2>/dev/null | head -n 1 || true)
  fi
  [[ $connection == "--" ]] && connection=""
  if [[ -n $connection ]]; then
    network=$(wifi_network_json "$connection" true true "" 0)
  else
    network=null
  fi
  device_json "$device" wired "${state:-unknown}" "$address" "$([[ $carrier == 1 ]] && printf true || printf false)" "$speed" "$network"
}

nm_available() {
  have nmcli && [[ $(LC_ALL=C nmcli -t -f RUNNING general status 2>/dev/null | head -n 1) == "running" ]]
}

nm_status() {
  local wifi_device="" state="unknown" address="" connection="" ssid="" rssi="-100" strength=0 security="Unknown" bssid="" connectivity_value wifi_enabled known=false connected=null wifi_json=null wired_json
  while IFS=: read -r candidate type candidate_state; do
    if [[ $type == "wifi" ]]; then
      wifi_device=$candidate
      state=$candidate_state
      break
    fi
  done < <(LC_ALL=C nmcli -t -e no -f DEVICE,TYPE,STATE device status 2>/dev/null || true)

  wifi_enabled=false
  [[ $(LC_ALL=C nmcli -g WIFI general 2>/dev/null | head -n 1) == "enabled" ]] && wifi_enabled=true
  connectivity_value=$(LC_ALL=C nmcli -g CONNECTIVITY general 2>/dev/null | head -n 1 || true)
  case "$connectivity_value" in
    full) connectivity_value="Full" ;;
    limited) connectivity_value="Limited" ;;
    portal) connectivity_value="Portal" ;;
    none) connectivity_value="None" ;;
    *) connectivity_value="Unknown" ;;
  esac

  if [[ -n $wifi_device ]]; then
    address=$(LC_ALL=C nmcli -g GENERAL.HWADDR device show "$wifi_device" 2>/dev/null | head -n 1 || true)
    connection=$(LC_ALL=C nmcli -g GENERAL.CONNECTION device show "$wifi_device" 2>/dev/null | head -n 1 || true)
    [[ $connection == "--" ]] && connection=""
    mapfile -t link < <(wireless_link "$wifi_device")
    ssid=${link[0]:-}
    rssi=${link[1]:--100}
    strength=$(signal_from_rssi "$rssi")
    if [[ -n $ssid ]]; then
      known=true
      security=$(network_security "$(LC_ALL=C nmcli -g 802-11-wireless-security.key-mgmt connection show "$connection" 2>/dev/null | head -n 1 || true)")
      connected=$(wifi_network_json "$ssid" true "$known" "$security" "$strength")
    fi
    wifi_json=$(device_json "$wifi_device" wifi "$state" "$address" "$([[ -n $ssid ]] && printf true || printf false)" 0 "$connected")
  fi
  wired_json=$(generic_wired_json)
  json_status nmcli true "$connectivity_value" "$wifi_enabled" "$wifi_json" "$wired_json" "$connected" '[]'
}

iwd_status() {
  local device="" station device_info state ssid bssid security rssi ipv4 address powered strength connected=null wifi_json=null wired_json connectivity_value="None" wifi_enabled=false
  station=$(iwctl station list 2>/dev/null | sed -r 's/\x1B\[[0-9;]*[mK]//g' || true)
  device=$(sed -n -E 's/^ *([^ ]+) +.*(connected|disconnected|connecting).*$/\1/p' <<<"$station" | head -n 1)
  [[ -z $device ]] && { empty_status; return; }
  station=$(iwctl station "$device" show 2>/dev/null | sed -r 's/\x1B\[[0-9;]*[mK]//g' || true)
  value() { sed -n -E "s/^ *\*? *$1[[:space:]]{2,}(.+)$/\1/p" <<<"$station" | sed 's/[[:space:]]*$//' | head -n 1; }
  state=$(value "State")
  ssid=$(value "Connected network")
  bssid=$(value "ConnectedBss")
  security=$(value "Security")
  rssi=$(value "RSSI")
  ipv4=$(value "IPv4 address")
  device_info=$(iwctl device "$device" show 2>/dev/null | sed -r 's/\x1B\[[0-9;]*[mK]//g' || true)
  address=$(sed -n -E 's/^ *\*? *Address[[:space:]]{2,}(.+)$/\1/p' <<<"$device_info" | sed 's/[[:space:]]*$//' | head -n 1)
  powered=$(sed -n -E 's/^ *\*? *Powered[[:space:]]{2,}(.+)$/\1/p' <<<"$device_info" | sed 's/[[:space:]]*$//' | head -n 1)
  [[ ${powered,,} == "on" || ${powered,,} == "yes" ]] && wifi_enabled=true
  strength=$(signal_from_rssi "$rssi")
  if [[ ${state,,} == "connected" && -n $ssid ]]; then
    connected=$(wifi_network_json "$ssid" true true "$(network_security "$security")" "$strength" "$bssid")
    [[ -n $ipv4 ]] && connectivity_value="Full" || connectivity_value="Local"
  fi
  wifi_json=$(device_json "$device" wifi "${state,,}" "$address" "$([[ -n $connected && $connected != null ]] && printf true || printf false)" 0 "$connected")
  wired_json=$(generic_wired_json)
  json_status iwctl true "$connectivity_value" "$wifi_enabled" "$wifi_json" "$wired_json" "$connected" '[]'
}

status() {
  if nm_available; then nm_status
  elif have iwctl; then iwd_status
  else empty_status
  fi
}

result() {
  local ok=$1 error=${2:-} snapshot
  snapshot=$(status)
  jq -cn --argjson ok "$ok" --arg error "$error" --argjson snapshot "$snapshot" '{kind: "result", ok: $ok, error: $error, snapshot: $snapshot}'
}

scan_nm() {
  local device=$1 line marker="" ssid="" signal="0" security="Unknown" bssid="" rows='[]' known_networks known=false
  known_networks=$(LC_ALL=C nmcli -g NAME,TYPE connection show 2>/dev/null | sed -n -E 's/^(.*):802-11-wireless$/\1/p')
  flush() {
    [[ -z $ssid ]] && return
    local entry
    known=false
    contains_network "$known_networks" "$ssid" && known=true
    entry=$(wifi_network_json "$ssid" "$([[ $marker == "*" ]] && printf true || printf false)" "$known" "$(network_security "$security")" "$(jq -cn --arg value "$signal" '((($value | tonumber? // 0) / 100) | if . < 0 then 0 elif . > 1 then 1 else . end)')" "$bssid")
    rows=$(jq -cn --argjson rows "$rows" --argjson entry "$entry" '$rows + [$entry]')
  }
  while IFS= read -r line || [[ -n $line ]]; do
    case "$line" in
      IN-USE:*) flush; marker=${line#*:}; marker=${marker//[[:space:]]/}; ssid=""; signal=0; security="Unknown"; bssid="" ;;
      SSID:*) ssid=$(sed -E 's/^[^:]*:[[:space:]]*//' <<<"$line") ;;
      SIGNAL:*) signal=$(sed -E 's/^[^:]*:[[:space:]]*//' <<<"$line") ;;
      SECURITY:*) security=$(sed -E 's/^[^:]*:[[:space:]]*//' <<<"$line") ;;
      BSSID:*) bssid=$(sed -E 's/^[^:]*:[[:space:]]*//' <<<"$line") ;;
    esac
  done < <(LC_ALL=C nmcli -m multiline -f IN-USE,SSID,SIGNAL,SECURITY,BSSID device wifi list ifname "$device" --rescan yes 2>/dev/null || true)
  flush
  jq -cn --argjson rows "$rows" '{kind: "result", ok: true, error: "", snapshot: null, wifiNetworks: $rows}'
}

scan_iwd() {
  local device=$1 output rows='[]' line parsed ssid signal security entry known_networks known=false
  iwctl station "$device" scan >/dev/null 2>&1 || true
  output=$(iwctl station "$device" get-networks rssi-dbms 2>/dev/null | sed -r 's/\x1B\[[0-9;]*[mK]//g' || true)
  known_networks=$(iwctl known-networks list 2>/dev/null | sed -r 's/\x1B\[[0-9;]*[mK]//g' | sed -n -E 's/^  (.*[^[:space:]])[[:space:]]+(open|psk|8021x|wep)[[:space:]].*$/\1/p')
  while IFS= read -r line; do
    [[ $line == *"Available networks"* || $line == *"Network name"* || $line == *"----"* ]] && continue
    line=${line#*>}
    line=$(sed -E 's/^ +| +$//g' <<<"$line")
    [[ -z $line ]] && continue
    parsed=$(sed -n -E 's/^(.*[^[:space:]])[[:space:]]+(psk|open|8021x|wep)[[:space:]]+(-?[0-9]+)[[:space:]]*$/\1|\2|\3/p' <<<"$line")
    [[ -z $parsed ]] && continue
    IFS='|' read -r ssid security signal <<<"$parsed"
    [[ -z $ssid || -z $signal ]] && continue
    known=false
    contains_network "$known_networks" "$ssid" && known=true
    entry=$(wifi_network_json "$ssid" false "$known" "$(network_security "$security")" "$(signal_from_rssi "$signal")")
    rows=$(jq -cn --argjson rows "$rows" --argjson entry "$entry" '$rows + [$entry]')
  done <<<"$output"
  jq -cn --argjson rows "$rows" '{kind: "result", ok: true, error: "", snapshot: null, wifiNetworks: $rows}'
}

scan() {
  local device
  if nm_available; then
    device=$(LC_ALL=C nmcli -t -e no -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2 == "wifi" {print $1; exit}')
    [[ -n $device ]] && scan_nm "$device" || jq -cn '{kind: "result", ok: false, error: "No Wi-Fi device", snapshot: null, wifiNetworks: []}'
  elif have iwctl; then
    device=$(iwctl station list 2>/dev/null | sed -r 's/\x1B\[[0-9;]*[mK]//g' | sed -n -E 's/^ *([^ ]+) +.*(connected|disconnected|connecting).*$/\1/p' | head -n 1)
    [[ -n $device ]] && scan_iwd "$device" || jq -cn '{kind: "result", ok: false, error: "No Wi-Fi device", snapshot: null, wifiNetworks: []}'
  else
    jq -cn '{kind: "result", ok: false, error: "No supported Wi-Fi backend", snapshot: null, wifiNetworks: []}'
  fi
}

action() {
  local name=${1:-} device=${2:-} ssid=${3:-} enabled=${3:-} password=""
  case "$name" in
    wifi-on)
      if nm_available; then LC_ALL=C nmcli radio wifi on >/dev/null 2>&1 && result true || result false "Unable to enable Wi-Fi"
      elif have iwctl; then iwctl device "$device" set-property Powered on >/dev/null 2>&1 && result true || result false "Unable to enable Wi-Fi"
      else result false "No supported Wi-Fi backend"; fi
      ;;
    wifi-off)
      if nm_available; then LC_ALL=C nmcli radio wifi off >/dev/null 2>&1 && result true || result false "Unable to disable Wi-Fi"
      elif have iwctl; then iwctl device "$device" set-property Powered off >/dev/null 2>&1 && result true || result false "Unable to disable Wi-Fi"
      else result false "No supported Wi-Fi backend"; fi
      ;;
    disconnect)
      if nm_available; then LC_ALL=C nmcli device disconnect "$device" >/dev/null 2>&1 && result true || result false "Unable to disconnect"
      elif have iwctl; then iwctl station "$device" disconnect >/dev/null 2>&1 && result true || result false "Unable to disconnect"
      else result false "No supported Wi-Fi backend"; fi
      ;;
    forget)
      if nm_available; then LC_ALL=C nmcli connection delete id "$ssid" >/dev/null 2>&1 && result true || result false "Unable to forget network"
      elif have iwctl; then iwctl known-networks "$ssid" forget >/dev/null 2>&1 && result true || result false "Unable to forget network"
      else result false "No supported Wi-Fi backend"; fi
      ;;
    connect)
      if nm_available; then
        IFS= read -r password || true
        if [[ -z $password ]]; then
          LC_ALL=C nmcli device wifi connect "$ssid" ifname "$device" >/dev/null 2>&1 && result true || result false "Unable to connect"
        else
          local uuid
          uuid=$(uuidgen 2>/dev/null || printf 'quickshell-%s-%s' "$$" "$RANDOM")
          LC_ALL=C nmcli connection add type wifi ifname "$device" con-name "$uuid" ssid "$ssid" wifi-sec.key-mgmt wpa-psk >/dev/null 2>&1 \
            && printf 'set wifi-sec.psk %s\nsave\nquit\n' "$password" | LC_ALL=C nmcli connection edit "$uuid" >/dev/null 2>&1 \
            && LC_ALL=C nmcli connection up uuid "$uuid" >/dev/null 2>&1 \
            && result true || { LC_ALL=C nmcli connection delete uuid "$uuid" >/dev/null 2>&1 || true; result false "Unable to connect"; }
        fi
      elif have iwctl; then
        # IWD has no non-argv passphrase interface. It can safely join open or
        # already-provisioned networks; password entry stays disabled in QML.
        iwctl station "$device" connect "$ssid" >/dev/null 2>&1 && result true || result false "IWD needs a saved passphrase"
      else result false "No supported Wi-Fi backend"; fi
      ;;
    *) result false "Unknown network action" ;;
  esac
}

case "$operation" in
  status) status ;;
  scan) scan ;;
  action) action "${2:-}" "${3:-}" "${4:-}" ;;
  *) jq -cn '{kind: "result", ok: false, error: "Unknown network operation", snapshot: null}' ;;
esac
