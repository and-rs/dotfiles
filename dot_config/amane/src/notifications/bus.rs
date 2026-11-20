use std::{
    collections::HashMap,
    sync::mpsc,
    time::{Duration, Instant},
};

use amane::Service;
use zbus::{
    blocking::{Connection, connection::Builder},
    fdo::{self, RequestNameFlags, RequestNameReply},
    message::Header,
    names::OwnedUniqueName,
    object_server::SignalEmitter,
    zvariant::OwnedValue,
};

use super::{CloseReason, Event, Notice, Notifications, images};
use crate::design;

pub(super) const NAME: &str = "org.freedesktop.Notifications";
pub(super) const PATH: &str = "/org/freedesktop/Notifications";
pub(super) const BODY_LIMIT: usize = 4096;
const LABEL_LIMIT: usize = 256;
const ACTION_LIMIT: usize = 12;

pub(super) struct Server;

fn sender(header: &Header<'_>) -> fdo::Result<OwnedUniqueName> {
    header
        .sender()
        .map(|name| name.to_owned().into())
        .ok_or_else(|| fdo::Error::AccessDenied("notification requires a bus sender".into()))
}

#[zbus::interface(name = "org.freedesktop.Notifications")]
impl Server {
    fn get_capabilities(&self) -> Vec<&str> {
        vec![
            "actions",
            "body",
            "persistence",
            "inline-reply",
            "icon-static",
        ]
    }

    #[zbus(out_args("name", "vendor", "version", "spec_version"))]
    fn get_server_information(&self) -> (&str, &str, &str, &str) {
        ("Amane", "Amane", env!("CARGO_PKG_VERSION"), "1.2")
    }

    #[allow(clippy::too_many_arguments)]
    fn notify(
        &self,
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        actions: Vec<String>,
        hints: HashMap<String, OwnedValue>,
        expire_timeout: i32,
        #[zbus(header)] header: Header<'_>,
    ) -> fdo::Result<u32> {
        let owner = sender(&header)?;
        let hint_bool =
            |key: &str| hints.get(key).and_then(|v| bool::try_from(v).ok()) == Some(true);
        let critical = hints.get("urgency").and_then(|v| u8::try_from(v).ok()) == Some(2);
        let timeout = match expire_timeout {
            0 => None,
            millis if millis > 0 => Some(Duration::from_millis(millis as u64)),
            _ if critical => None,
            _ => Some(design::notifications::POPUP_TIMEOUT),
        };
        let mut reply = None;
        let actions = actions
            .as_chunks::<2>()
            .0
            .iter()
            .take(ACTION_LIMIT)
            .filter_map(|[key, label]| {
                if key == "inline-reply" {
                    reply = Some(
                        hints
                            .get("x-kde-reply-placeholder-text")
                            .and_then(|value| <&str>::try_from(value).ok())
                            .filter(|text| !text.is_empty())
                            .or_else(|| (!label.is_empty()).then_some(label.as_str()))
                            .unwrap_or("Reply…")
                            .chars()
                            .take(LABEL_LIMIT)
                            .collect(),
                    );
                    return None;
                }
                (!key.is_empty() && key.len() <= LABEL_LIMIT)
                    .then(|| (key.clone(), label.chars().take(LABEL_LIMIT).collect()))
            })
            .collect();
        let notice = Notice {
            owner,
            app: app_name.chars().take(LABEL_LIMIT).collect(),
            title: summary.chars().take(LABEL_LIMIT).collect(),
            body: body.chars().take(BODY_LIMIT).collect(),
            actions,
            reply,
            resident: hint_bool("resident"),
            transient: hint_bool("transient"),
            critical,
            timeout,
            image: images::capture(&hints, &app_icon),
        };
        Ok(Notifications::write().submit(replaces_id, notice, Instant::now()))
    }

    fn close_notification(&self, id: u32, #[zbus(header)] header: Header<'_>) -> fdo::Result<()> {
        let owner = sender(&header)?;
        let mut state = Notifications::write();
        if state
            .entry(id)
            .is_some_and(|entry| entry.live && entry.notice.owner == owner)
        {
            state.close(id, CloseReason::Requested, false, Instant::now());
        }
        Ok(())
    }

    #[zbus(signal)]
    async fn notification_closed(
        emitter: &SignalEmitter<'_>,
        id: u32,
        reason: u32,
    ) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn action_invoked(
        emitter: &SignalEmitter<'_>,
        id: u32,
        action_key: &str,
    ) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn notification_replied(
        emitter: &SignalEmitter<'_>,
        id: u32,
        text: &str,
    ) -> zbus::Result<()>;
}

pub(super) fn claim(connection: &Connection) -> zbus::Result<bool> {
    match connection.request_name_with_flags(NAME, RequestNameFlags::DoNotQueue.into()) {
        Ok(RequestNameReply::PrimaryOwner | RequestNameReply::AlreadyOwner) => Ok(true),
        Ok(_) | Err(zbus::Error::NameTaken) => Ok(false),
        Err(error) => Err(error),
    }
}

pub(super) fn run() -> zbus::Result<()> {
    let connection = Builder::session()?.serve_at(PATH, Server)?.build()?;
    let (sender, events) = mpsc::channel();
    // Publish the sender before handling the first call, without holding a lock over D-Bus.
    Notifications::write().events = Some(sender);
    let result = claim(&connection);
    if !matches!(result, Ok(true)) {
        Notifications::write().events = None;
        return result.map(|_| ());
    }
    Notifications::write().running = true;
    loop {
        let deadline = Notifications::read().deadline();
        let event = match deadline {
            Some(deadline) if Instant::now() >= deadline => {
                Notifications::write().tick(Instant::now());
                continue;
            }
            Some(deadline) => {
                match events.recv_timeout(deadline.saturating_duration_since(Instant::now())) {
                    Ok(event) => event,
                    Err(mpsc::RecvTimeoutError::Timeout) => continue,
                    Err(mpsc::RecvTimeoutError::Disconnected) => break,
                }
            }
            None => match events.recv() {
                Ok(event) => event,
                Err(_) => break,
            },
        };
        let result = match event {
            Event::Schedule => continue,
            Event::Closed(id, reason) => connection.emit_signal(
                None::<&str>,
                PATH,
                NAME,
                "NotificationClosed",
                &(id, reason as u32),
            ),
            Event::Action(id, key) => {
                connection.emit_signal(None::<&str>, PATH, NAME, "ActionInvoked", &(id, key))
            }
            Event::Reply(owner, id, text) => connection.emit_signal(
                Some(owner.as_str()),
                PATH,
                NAME,
                "NotificationReplied",
                &(id, text),
            ),
        };
        if let Err(error) = result {
            eprintln!("notification signal failed: {error}");
        }
    }
    Ok(())
}
