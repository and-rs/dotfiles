use zbus::{
    blocking::{Connection, Proxy},
    zvariant::{ObjectPath, OwnedObjectPath},
};

use super::backend::{Backend, Snapshot};
use crate::control_center::dbus;

const SERVICE: &str = Backend::Iwd.service();

pub(super) fn read_snapshot(connection: &Connection) -> zbus::Result<Snapshot> {
    let objects = dbus::objects(connection, SERVICE, "/")?;
    let mut snapshot = Snapshot::default();
    for (path, interfaces) in &objects {
        let Some(station) = interfaces.get("net.connman.iwd.Station") else {
            continue;
        };
        let powered = interfaces
            .get("net.connman.iwd.Device")
            .and_then(|properties| properties.get("Powered"))
            .ok_or_else(|| zbus::Error::Failure("iwd device is missing Powered".into()))?;
        let powered = bool::try_from(powered)?;
        snapshot.present = true;
        snapshot.enabled |= powered;
        if !powered {
            continue;
        }
        let Some(network) = station.get("ConnectedNetwork") else {
            continue;
        };
        let network = <&ObjectPath>::try_from(network)?;
        if network.as_str() == "/" {
            continue;
        }
        let name: String = Proxy::new(
            connection,
            SERVICE,
            network.as_str(),
            "net.connman.iwd.Network",
        )?
        .get_property("Name")?;
        let station = Proxy::new(
            connection,
            SERVICE,
            path.as_str(),
            "net.connman.iwd.Station",
        )?;
        // Read the existing scan cache without initiating discovery.
        let networks: Vec<(OwnedObjectPath, i16)> = station.call("GetOrderedNetworks", &())?;
        let strength = networks
            .iter()
            .find(|(path, _)| path.as_str() == network.as_str())
            .map(|(_, rssi)| rssi_strength(*rssi));
        snapshot.record_connection(name, strength);
    }
    Ok(snapshot)
}

fn rssi_strength(hundredths_dbm: i16) -> f32 {
    ((f32::from(hundredths_dbm) / 100.0 + 100.0) / 50.0).clamp(0.0, 1.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn signal_is_normalized_and_clamped() {
        for (rssi, expected) in [
            (-12000, 0.0),
            (-10000, 0.0),
            (-7500, 0.5),
            (-5000, 1.0),
            (-3000, 1.0),
        ] {
            assert_eq!(rssi_strength(rssi), expected);
        }
    }
}
