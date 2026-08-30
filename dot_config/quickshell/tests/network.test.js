import { describe, expect, test } from "bun:test"
import model from "../Bar/Status/Network/NetworkModel.js"

describe("NetworkModel", () => {
  test("normalizes an NM snapshot into UI-safe primitives", () => {
    const value = model.snapshot({
      backend: "nmcli",
      available: true,
      canCheckConnectivity: true,
      connectivity: "Full",
      wifiEnabled: true,
      wifiDevice: {
        name: "wlan0",
        state: "connected",
        address: "aa:bb:cc:dd:ee:ff",
        hasLink: true,
        network: { name: "Cafe: Upstairs", connected: true, known: true, security: "WPA2", signalStrength: 1.4 }
      },
      wiredDevice: { name: "enp1s0", state: "disconnected", hasLink: false, linkSpeed: -1 },
      wifiNetworks: [
        { name: "Weak", signalStrength: 0.2 },
        { name: "Known", known: true, signalStrength: 0.1 },
        { name: "Current", connected: true, signalStrength: 0.7 }
      ]
    })

    expect(value.wifiDevice.network.name).toBe("Cafe: Upstairs")
    expect(value.wifiDevice.network.signalStrength).toBe(1)
    expect(value.wiredDevice.linkSpeed).toBe(0)
    expect(value.wifiNetworks.map(network => network.name)).toEqual(["Current", "Known", "Weak"])
    expect(value).not.toHaveProperty("canCheckConnectivity")
  })

  test("rejects malformed protocol output", () => {
    expect(model.parseSnapshot("not json")).toBeNull()
    expect(model.parseSnapshot('{"kind":"result"}')).toBeNull()
    expect(model.parseResult('{"kind":"result","ok":false,"error":"failed"}')).toEqual({ ok: false, error: "failed", snapshot: null, wifiNetworks: [] })
  })

  test("keeps unknown backend data neutral", () => {
    const value = model.snapshot({ backend: "broken", connectivity: "internet", wifiDevice: { name: "wlan0" } })
    expect(value.backend).toBe("none")
    expect(value.connectivity).toBe("Unknown")
    expect(value.wifiDevice.state).toBe("unknown")
    expect(value.wifiDevice.network).toBeNull()
  })
})
