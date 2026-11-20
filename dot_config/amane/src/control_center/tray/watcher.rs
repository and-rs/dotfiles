use std::{
    collections::BTreeMap,
    sync::{
        Arc, Mutex,
        atomic::{AtomicU64, Ordering},
    },
};

use zbus::{
    blocking::{Connection, Proxy},
    fdo::{RequestNameFlags, RequestNameReply},
    message::Header,
    object_server::SignalEmitter,
};

pub(super) const SERVICE: &str = "org.kde.StatusNotifierWatcher";
pub(super) const PATH: &str = "/StatusNotifierWatcher";

#[derive(Default)]
struct Registrations {
    items: BTreeMap<String, String>,
    hosts: BTreeMap<String, String>,
}

#[derive(Clone, Default)]
pub(super) struct Watcher(Arc<Mutex<Registrations>>);

/// Canonical watcher entries may be either a service or a service/object_path.
pub(super) fn split_item(value: &str) -> Option<(&str, &str)> {
    let (service, path) = match value.find('/') {
        Some(index) => (&value[..index], &value[index..]),
        None => (value, "/StatusNotifierItem"),
    };
    zbus::names::BusName::try_from(service).ok()?;
    zbus::zvariant::ObjectPath::try_from(path).ok()?;
    Some((service, path))
}

pub(super) fn owner(connection: &Connection, service: &str) -> zbus::Result<String> {
    Proxy::new(
        connection,
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus",
    )?
    .call("GetNameOwner", &(service,))
}

async fn async_owner(connection: &zbus::Connection, service: &str) -> zbus::fdo::Result<String> {
    let proxy = zbus::Proxy::new(
        connection,
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus",
    )
    .await?;
    proxy
        .call("GetNameOwner", &(service,))
        .await
        .map_err(Into::into)
}

#[zbus::interface(name = "org.kde.StatusNotifierWatcher")]
impl Watcher {
    async fn register_status_notifier_item(
        &self,
        service: &str,
        #[zbus(header)] header: Header<'_>,
        #[zbus(connection)] connection: &zbus::Connection,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        let entry = if service.starts_with('/') {
            let sender = header.sender().ok_or_else(|| {
                zbus::fdo::Error::InvalidArgs("Registration requires a sender".into())
            })?;
            format!("{sender}{service}")
        } else {
            let (service, path) = split_item(service).ok_or_else(|| {
                zbus::fdo::Error::InvalidArgs("Invalid tray service or path".into())
            })?;
            format!("{service}{path}")
        };
        let (service, _) = split_item(&entry)
            .ok_or_else(|| zbus::fdo::Error::InvalidArgs("Invalid tray path".into()))?;
        let owner = async_owner(connection, service).await?;
        let previous = self
            .0
            .lock()
            .expect("tray registrations poisoned")
            .items
            .insert(entry.clone(), owner.clone());
        if previous.as_ref().is_some_and(|previous| previous != &owner) {
            Self::status_notifier_item_unregistered(&emitter, &entry).await?;
        }
        if previous.as_ref() != Some(&owner) {
            Self::status_notifier_item_registered(&emitter, &entry).await?;
        }
        Ok(())
    }

    async fn register_status_notifier_host(
        &self,
        service: &str,
        #[zbus(connection)] connection: &zbus::Connection,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        zbus::names::BusName::try_from(service)
            .map_err(|_| zbus::fdo::Error::InvalidArgs("Invalid host service".into()))?;
        let owner = async_owner(connection, service).await?;
        let first = {
            let mut registrations = self.0.lock().expect("tray registrations poisoned");
            let first = registrations.hosts.is_empty();
            registrations.hosts.insert(service.into(), owner);
            first
        };
        if first {
            Self::status_notifier_host_registered(&emitter).await?;
        }
        Ok(())
    }

    #[zbus(property(emits_changed_signal = "false"))]
    fn registered_status_notifier_items(&self) -> Vec<String> {
        self.0
            .lock()
            .expect("tray registrations poisoned")
            .items
            .keys()
            .cloned()
            .collect()
    }

    #[zbus(property(emits_changed_signal = "false"))]
    fn is_status_notifier_host_registered(&self) -> bool {
        !self
            .0
            .lock()
            .expect("tray registrations poisoned")
            .hosts
            .is_empty()
    }

    #[zbus(property(emits_changed_signal = "false"))]
    fn protocol_version(&self) -> i32 {
        0
    }

    #[zbus(signal)]
    async fn status_notifier_item_registered(
        emitter: &SignalEmitter<'_>,
        item: &str,
    ) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn status_notifier_item_unregistered(
        emitter: &SignalEmitter<'_>,
        item: &str,
    ) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn status_notifier_host_registered(emitter: &SignalEmitter<'_>) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn status_notifier_host_unregistered(emitter: &SignalEmitter<'_>) -> zbus::Result<()>;
}

impl Watcher {
    fn prune(&self, connection: &Connection) -> zbus::Result<()> {
        let (items, hosts) = {
            let registrations = self.0.lock().expect("tray registrations poisoned");
            (registrations.items.clone(), registrations.hosts.clone())
        };
        for (entry, previous) in items {
            let Some((service, _)) = split_item(&entry) else {
                continue;
            };
            if owner(connection, service).ok().as_ref() != Some(&previous) {
                let removed = {
                    let mut registrations = self.0.lock().expect("tray registrations poisoned");
                    if registrations.items.get(&entry) == Some(&previous) {
                        registrations.items.remove(&entry);
                        true
                    } else {
                        false
                    }
                };
                if removed {
                    connection.emit_signal(
                        None::<&str>,
                        PATH,
                        SERVICE,
                        "StatusNotifierItemUnregistered",
                        &(entry,),
                    )?;
                }
            }
        }
        let mut removed_host = false;
        for (service, previous) in hosts {
            if owner(connection, &service).ok().as_ref() != Some(&previous) {
                let mut registrations = self.0.lock().expect("tray registrations poisoned");
                if registrations.hosts.get(&service) == Some(&previous) {
                    registrations.hosts.remove(&service);
                    removed_host = registrations.hosts.is_empty();
                }
            }
        }
        if removed_host {
            connection.emit_signal(
                None::<&str>,
                PATH,
                SERVICE,
                "StatusNotifierHostUnregistered",
                &(),
            )?;
        }
        Ok(())
    }
}

pub(super) struct Host {
    watcher: Watcher,
    registered_with: Option<String>,
    service: String,
}

impl Host {
    pub(super) fn new(connection: &Connection) -> zbus::Result<Self> {
        static NEXT_HOST: AtomicU64 = AtomicU64::new(0);
        // KDE watchers require the conventional host-service prefix.
        let service = format!(
            "org.kde.StatusNotifierHost-{}-{}",
            std::process::id(),
            NEXT_HOST.fetch_add(1, Ordering::Relaxed)
        );
        connection
            .request_name_with_flags(service.as_str(), RequestNameFlags::DoNotQueue.into())?;
        let watcher = Watcher::default();
        connection.object_server().at(PATH, watcher.clone())?;
        Ok(Self {
            watcher,
            registered_with: None,
            service,
        })
    }

    pub(super) fn refresh(&mut self, connection: &Connection) -> zbus::Result<Vec<String>> {
        // DoNotQueue never steals the name or leaves a queued takeover behind.
        if owner(connection, SERVICE).is_err() {
            let reply =
                connection.request_name_with_flags(SERVICE, RequestNameFlags::DoNotQueue.into())?;
            if !matches!(
                reply,
                RequestNameReply::PrimaryOwner | RequestNameReply::AlreadyOwner
            ) {
                self.registered_with = None;
            }
        }
        let current_owner = owner(connection, SERVICE)?;
        if connection
            .unique_name()
            .is_some_and(|name| name.as_str() == current_owner)
        {
            self.watcher.prune(connection)?;
        }
        let watcher = Proxy::new(connection, current_owner.as_str(), PATH, SERVICE)?;
        if self.registered_with.as_ref() != Some(&current_owner) {
            watcher.call::<_, _, ()>("RegisterStatusNotifierHost", &(self.service.as_str(),))?;
            self.registered_with = Some(current_owner.clone());
        }
        watcher.get_property("RegisteredStatusNotifierItems")
    }
}
