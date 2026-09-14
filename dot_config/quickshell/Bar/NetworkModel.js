function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value))
}

function string(value) {
  return value === undefined || value === null ? "" : String(value)
}

function signal(value) {
  var parsed = Number(value)
  if (!isFinite(parsed)) return 0
  return clamp(parsed, 0, 1)
}

function connectivity(value) {
  var known = ["Full", "Limited", "Portal", "Local", "None", "Unknown"]
  return known.indexOf(string(value)) !== -1 ? string(value) : "Unknown"
}

function device(value, type) {
  if (!value || typeof value !== "object" || !value.name) return null
  return {
    name: string(value.name),
    type: type,
    state: string(value.state || "unknown").toLowerCase(),
    address: string(value.address),
    hasLink: !!value.hasLink,
    linkSpeed: Math.max(0, Math.round(Number(value.linkSpeed) || 0)),
    network: network(value.network)
  }
}

function network(value) {
  if (!value || typeof value !== "object" || !value.name) return null
  return {
    name: string(value.name),
    connected: !!value.connected,
    known: !!value.known,
    security: string(value.security || "Unknown"),
    signalStrength: signal(value.signalStrength),
    bssid: string(value.bssid),
    id: string(value.id || value.bssid || value.name)
  }
}

function row(value) {
  var next = network(value)
  if (!next) return null
  return next
}

function sortRows(values) {
  var rows = Array.isArray(values) ? values.map(row).filter(Boolean) : []
  rows.sort(function(left, right) {
    if (left.connected !== right.connected) return left.connected ? -1 : 1
    if (left.known !== right.known) return left.known ? -1 : 1
    if (left.signalStrength !== right.signalStrength) return right.signalStrength - left.signalStrength
    return left.name.localeCompare(right.name)
  })
  return rows
}

function snapshot(value) {
  var raw = value && typeof value === "object" ? value : {}
  var wifiDevice = device(raw.wifiDevice, "wifi")
  var wiredDevice = device(raw.wiredDevice, "wired")
  var connectedNetwork = network(raw.connectedNetwork) || (wifiDevice ? wifiDevice.network : null)
  if (wifiDevice) wifiDevice.network = connectedNetwork

  return {
    backend: ["nmcli", "iwctl", "none"].indexOf(string(raw.backend)) !== -1 ? string(raw.backend) : "none",
    available: !!raw.available,
    connectivity: connectivity(raw.connectivity),
    wifiEnabled: !!raw.wifiEnabled,
    wifiDevice: wifiDevice,
    wiredDevice: wiredDevice,
    connectedNetwork: connectedNetwork,
    wifiNetworks: sortRows(raw.wifiNetworks),
    stale: !!raw.stale,
    error: string(raw.error)
  }
}

function parseJson(text) {
  try {
    return JSON.parse(String(text || ""))
  } catch (error) {
    return null
  }
}

function parseSnapshot(text) {
  var parsed = parseJson(text)
  return parsed && parsed.kind === "status" ? snapshot(parsed) : null
}

function parseResult(text) {
  var parsed = parseJson(text)
  if (!parsed || parsed.kind !== "result") return null
  return {
    ok: parsed.ok === true,
    error: string(parsed.error),
    snapshot: parsed.snapshot ? snapshot(parsed.snapshot) : null,
    wifiNetworks: sortRows(parsed.wifiNetworks)
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    parseResult: parseResult,
    parseSnapshot: parseSnapshot,
    snapshot: snapshot,
    sortRows: sortRows
  }
}
