use std::{collections::HashMap, time::Duration};

use zbus::{
    blocking::{Connection, Proxy, connection::Builder},
    zvariant::{OwnedObjectPath, OwnedValue},
};

pub(super) type Objects = HashMap<OwnedObjectPath, HashMap<String, HashMap<String, OwnedValue>>>;

pub(super) fn connection(session: bool) -> zbus::Result<Connection> {
    let builder = if session {
        Builder::session()?
    } else {
        Builder::system()?
    };
    builder.method_timeout(Duration::from_secs(2)).build()
}

pub(super) fn owned(connection: &Connection, name: &str) -> zbus::Result<bool> {
    Proxy::new(
        connection,
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus",
    )?
    .call("NameHasOwner", &(name,))
}

pub(super) fn objects(connection: &Connection, name: &str, path: &str) -> zbus::Result<Objects> {
    Proxy::new(connection, name, path, "org.freedesktop.DBus.ObjectManager")?
        .call("GetManagedObjects", &())
}

pub(super) fn boolean(properties: &HashMap<String, OwnedValue>, name: &str) -> bool {
    properties
        .get(name)
        .and_then(|value| bool::try_from(value).ok())
        .unwrap_or(false)
}
