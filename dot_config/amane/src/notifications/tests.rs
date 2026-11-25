use std::{collections::HashMap, fs, sync::mpsc, thread};

use zbus::{
    blocking::{Connection, Proxy},
    zvariant::{OwnedValue, Value},
};

use super::*;

pub(super) fn notice(title: &str, timeout: Option<Duration>) -> Notice {
    Notice {
        owner: OwnedUniqueName::try_from(":1.22").unwrap(),
        app: "Test".into(),
        title: title.into(),
        body: body::Body::parse(String::new()),
        actions: vec![("open".into(), "Open".into())],
        reply: Some("Write a reply".into()),
        resident: false,
        transient: false,
        critical: false,
        timeout,
        image: Arc::default(),
    }
}

#[test]
fn active_replacement_restarts_timeout_and_queue_advances_without_losing_history() {
    let mut state = Notifications::default();
    let now = Instant::now();
    let second = Duration::from_secs(1);
    let first = state.submit(0, notice("First", Some(second)), now);
    let queued = state.submit(0, notice("Second", Some(second)), now);
    assert_eq!(state.popup.as_ref().unwrap().id, first);
    let replaced = state.submit(first, notice("Updated", Some(second * 2)), now);
    assert_eq!(replaced, first);
    state.tick(now + second);
    assert_eq!(state.popup.as_ref().unwrap().id, first);
    state.tick(now + second * 2);
    assert_eq!(state.popup.as_ref().unwrap().id, queued);
    assert_eq!(state.deadline(), Some(now + second * 3));
    let entry = state.entry(first).unwrap();
    assert_eq!(entry.notice.title, "Updated");
    assert!(!entry.live);
}

#[test]
fn hiding_popup_advances_queue_and_keeps_history_actions_live() {
    let (sender, events) = mpsc::channel();
    let mut state = Notifications {
        events: Some(sender),
        ..Notifications::default()
    };
    let now = Instant::now();
    let mut first = notice("First", Some(Duration::from_secs(1)));
    first.actions.push(("default".into(), "Open".into()));
    let first = state.submit(0, first, now);
    let second = state.submit(0, notice("Second", None), now);
    state.hide_popup_from_ui(first, now);
    assert_eq!(state.popup.unwrap().id, second);
    let later = now + Duration::from_secs(2);
    state.tick(later);
    assert!(state.entry(first).unwrap().live);
    assert!(
        !events
            .try_iter()
            .any(|event| matches!(event, Event::Closed(..) | Event::Action(..)))
    );
    state.invoke(first, "default", later);
    assert!(
        events
            .try_iter()
            .any(|event| matches!(event, Event::Action(id, _) if id == first))
    );
}

#[test]
fn undo_defers_close_and_clear_only_closes_live_entries() {
    let now = Instant::now();
    let (sender, events) = mpsc::channel();
    let mut state = Notifications {
        events: Some(sender),
        ..Notifications::default()
    };
    let id = state.submit(0, notice("Pending", None), now);
    state.dismiss(id, now);
    state.undo(id);
    state.tick(now + design::notifications::UNDO);
    assert!(state.entry(id).unwrap().live);
    assert!(
        !events
            .try_iter()
            .any(|event| matches!(event, Event::Closed(..)))
    );
    state.dismiss(id, now);
    state.tick(now + design::notifications::UNDO);
    assert!(state.entry(id).is_none());
    let live = state.submit(0, notice("Live", None), now);
    let closed = state.submit(0, notice("Closed", None), now);
    state.close(closed, CloseReason::Requested, false, now);
    state.clear();
    let closed_events: Vec<_> = events
        .try_iter()
        .filter_map(|event| match event {
            Event::Closed(id, reason) => Some((id, reason)),
            _ => None,
        })
        .collect();
    assert_eq!(
        closed_events,
        [
            (id, CloseReason::Dismissed),
            (closed, CloseReason::Requested),
            (live, CloseReason::Dismissed),
        ]
    );
    assert!(state.entries.is_empty());
}

#[test]
fn history_is_bounded_and_transient_entries_are_not_retained() {
    let now = Instant::now();
    let mut state = Notifications::default();
    let mut transient = notice("Transient", Some(Duration::from_secs(1)));
    transient.transient = true;
    let id = state.submit(0, transient, now);
    state.tick(now + Duration::from_secs(1));
    assert!(state.entry(id).is_none());
    let first = state.submit(0, notice("Persistent", None), now);
    for _ in 0..HISTORY_LIMIT {
        state.submit(0, notice("Next", None), now);
    }
    assert_eq!(state.entries.len(), HISTORY_LIMIT);
    assert!(state.entry(first).is_none());
    assert_eq!(state.popup.as_ref().unwrap().id, first + 1);
}

fn notify(proxy: &Proxy<'_>, replaces: u32, timeout: i32) -> u32 {
    notify_with_hints(proxy, replaces, timeout, HashMap::new())
}

fn notify_with_hints(
    proxy: &Proxy<'_>,
    replaces: u32,
    timeout: i32,
    hints: HashMap<&str, OwnedValue>,
) -> u32 {
    proxy
        .call(
            "Notify",
            &(
                "Test",
                replaces,
                "",
                "Title",
                "Body",
                &["open", "Open", "inline-reply", "Type a reply"][..],
                hints,
                timeout,
            ),
        )
        .unwrap()
}

#[test]
#[ignore = "run under an isolated dbus-run-session; claims org.freedesktop.Notifications"]
fn fake_notification_session_expires_and_routes_actions_and_replies() {
    drop(Notifications::read());
    let deadline = Instant::now() + Duration::from_secs(3);
    while !Notifications::read().running {
        assert!(
            Instant::now() < deadline,
            "notification server did not start"
        );
        thread::sleep(Duration::from_millis(5));
    }
    let client = Connection::session().unwrap();
    let other = Connection::session().unwrap();
    assert!(
        !bus::claim(&other).unwrap(),
        "must not replace the running server"
    );
    let proxy = Proxy::new(&client, bus::NAME, bus::PATH, bus::NAME).unwrap();
    let rival = Proxy::new(&other, bus::NAME, bus::PATH, bus::NAME).unwrap();
    let (name, _, _, version): (String, String, String, String) =
        proxy.call("GetServerInformation", &()).unwrap();
    assert_eq!((&*name, &*version), ("Amane", "1.2"));
    let caps: Vec<String> = proxy.call("GetCapabilities", &()).unwrap();
    assert!(caps.iter().any(|value| value == "inline-reply"));
    assert!(caps.iter().any(|value| value == "icon-static"));
    assert!(caps.iter().any(|value| value == "body-markup"));
    assert!(caps.iter().any(|value| value == "body-hyperlinks"));
    assert!(!caps.iter().any(|value| value == "body-images"));

    let mut closed = proxy.receive_signal("NotificationClosed").unwrap();
    let expiring = notify(&proxy, 0, 30);
    let message = closed.next().unwrap();
    assert_eq!(
        message.body().deserialize::<(u32, u32)>().unwrap(),
        (expiring, CloseReason::Expired as u32)
    );
    assert!(!Notifications::read().entry(expiring).unwrap().live);
    if std::env::var_os("XDG_RUNTIME_DIR").is_some() {
        let raw = Value::from((
            1_i32,
            1_i32,
            4_i32,
            true,
            8_i32,
            4_i32,
            vec![70_u8, 80, 90, 255],
        ));
        let image = notify_with_hints(
            &proxy,
            0,
            0,
            HashMap::from([("image-data", OwnedValue::try_from(raw).unwrap())]),
        );
        let deadline = Instant::now() + Duration::from_secs(3);
        let path = loop {
            let path = Notifications::read()
                .entry(image)
                .unwrap()
                .notice
                .image
                .get()
                .map(|preview| preview.path().to_owned());
            if let Some(path) = path {
                break path;
            }
            assert!(Instant::now() < deadline, "the D-Bus image was not cached");
            thread::sleep(Duration::from_millis(5));
        };
        Notifications::write().hide_popup_from_ui(image, Instant::now());
        assert!(Notifications::read().entry(image).unwrap().live);
        proxy
            .call::<_, _, ()>("CloseNotification", &(image,))
            .unwrap();
        let message = closed.next().unwrap();
        assert_eq!(
            message.body().deserialize::<(u32, u32)>().unwrap(),
            (image, CloseReason::Requested as u32)
        );
        assert!(!Notifications::read().entry(image).unwrap().live);
        assert!(
            path.is_file(),
            "dismissed notifications still own their thumbnails"
        );
        Notifications::write().clear();
        assert!(
            !fs::exists(&path).unwrap(),
            "clearing history releases the thumbnail"
        );
    }
    let id = notify(&proxy, 0, 0);
    assert_eq!(notify(&proxy, id, 0), id);
    let other_id = notify(&rival, id, 0);
    assert_ne!(other_id, id);
    rival.call::<_, _, ()>("CloseNotification", &(id,)).unwrap();
    assert!(Notifications::read().entry(id).unwrap().live);

    let mut reply = proxy.receive_signal("NotificationReplied").unwrap();
    {
        let mut state = Notifications::write();
        assert_eq!(
            state.entry(id).unwrap().notice.reply.as_deref(),
            Some("Type a reply")
        );
        state.reply_to = Some(id);
        state.reply(id, " accepted ", Instant::now());
    }
    let message = reply.next().unwrap();
    assert_eq!(
        message.header().destination().unwrap().as_str(),
        client.unique_name().unwrap().as_str()
    );
    assert_eq!(
        message.body().deserialize::<(u32, String)>().unwrap(),
        (id, "accepted".into())
    );
    let mut actions = rival.receive_signal("ActionInvoked").unwrap();
    Notifications::write().invoke(other_id, "open", Instant::now());
    assert_eq!(
        actions
            .next()
            .unwrap()
            .body()
            .deserialize::<(u32, String)>()
            .unwrap(),
        (other_id, "open".into())
    );
}
