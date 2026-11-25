use super::*;
use std::sync::Arc;
use zbus::{
    blocking::{Proxy, connection::Builder},
    zvariant::{OwnedObjectPath, OwnedValue, Structure, Value},
};

#[test]
fn watcher_entries_validate_service_and_object_paths() {
    assert_eq!(
        watcher::split_item(":1.42"),
        Some((":1.42", "/StatusNotifierItem"))
    );
    assert_eq!(
        watcher::split_item("org.example.App/Tray"),
        Some(("org.example.App", "/Tray"))
    );
    for invalid in ["", "not_a_bus_name", "/Tray", ":1.42/not-valid"] {
        assert!(watcher::split_item(invalid).is_none(), "{invalid}");
    }
}

#[derive(Default)]
struct FakeState {
    status: String,
    failed: bool,
    disabled: bool,
    revision: u32,
    events: Vec<String>,
}

struct FakeItem(Arc<Mutex<FakeState>>);

#[zbus::interface(name = "org.kde.StatusNotifierItem")]
impl FakeItem {
    #[zbus(property)]
    fn title(&self) -> &str {
        "Test application"
    }

    #[zbus(property)]
    fn id(&self) -> &str {
        "test_application"
    }

    #[zbus(property)]
    fn status(&self) -> zbus::fdo::Result<String> {
        let state = self.0.lock().unwrap();
        if state.failed {
            return Err(zbus::fdo::Error::Failed("Deliberately broken item".into()));
        }
        Ok(state.status.clone())
    }

    #[zbus(property)]
    fn menu(&self) -> OwnedObjectPath {
        OwnedObjectPath::try_from("/Menu").unwrap()
    }

    #[zbus(property)]
    fn icon_pixmap(&self) -> Vec<icons::Pixmap> {
        vec![(1, 1, vec![255, 10, 20, 30])]
    }

    #[zbus(property)]
    fn attention_icon_pixmap(&self) -> Vec<icons::Pixmap> {
        vec![(1, 1, vec![255, 200, 100, 50])]
    }

    #[zbus(property)]
    fn tool_tip(&self) -> (String, Vec<icons::Pixmap>, String, String) {
        (
            "".into(),
            vec![],
            "Test application".into(),
            "Test description".into(),
        )
    }

    fn activate(&self, x: i32, y: i32) {
        self.0
            .lock()
            .unwrap()
            .events
            .push(format!("activate:{x}:{y}"));
    }

    fn secondary_activate(&self, x: i32, y: i32) {
        self.0
            .lock()
            .unwrap()
            .events
            .push(format!("secondary:{x}:{y}"));
    }

    fn context_menu(&self, x: i32, y: i32) {
        self.0
            .lock()
            .unwrap()
            .events
            .push(format!("context:{x}:{y}"));
    }

    fn scroll(&self, delta: i32, orientation: &str) {
        self.0
            .lock()
            .unwrap()
            .events
            .push(format!("scroll:{delta}:{orientation}"));
    }
}

struct FakeMenu(Arc<Mutex<FakeState>>);

fn properties(values: Vec<(&str, Value<'_>)>) -> items::Properties {
    values
        .into_iter()
        .map(|(key, value)| (key.into(), value.try_into().unwrap()))
        .collect()
}

fn child(id: i32, properties: items::Properties) -> OwnedValue {
    Value::from(Structure::from((id, properties, Vec::<OwnedValue>::new())))
        .try_into()
        .unwrap()
}

#[zbus::interface(name = "com.canonical.dbusmenu")]
impl FakeMenu {
    fn about_to_show(&self, id: i32) -> bool {
        self.0.lock().unwrap().events.push(format!("about:{id}"));
        false
    }

    fn get_layout(
        &self,
        parent_id: i32,
        _depth: i32,
        _names: Vec<String>,
    ) -> (u32, (i32, items::Properties, Vec<OwnedValue>)) {
        let state = self.0.lock().unwrap();
        let children = if parent_id == 6 {
            vec![child(
                8,
                properties(vec![("label", "Submenu _action".into())]),
            )]
        } else {
            vec![
                child(
                    1,
                    properties(vec![
                        ("label", "_Open".into()),
                        ("enabled", (!state.disabled).into()),
                    ]),
                ),
                child(2, properties(vec![("type", "separator".into())])),
                child(
                    3,
                    properties(vec![
                        ("label", "Checkbox".into()),
                        ("toggle-type", "checkmark".into()),
                        ("toggle-state", 1_i32.into()),
                    ]),
                ),
                child(
                    4,
                    properties(vec![
                        ("label", "Radio".into()),
                        ("toggle-type", "radio".into()),
                        ("toggle-state", 0_i32.into()),
                    ]),
                ),
                child(
                    5,
                    properties(vec![("label", "Hidden".into()), ("visible", false.into())]),
                ),
                child(
                    6,
                    properties(vec![
                        ("label", "Options".into()),
                        ("children-display", "submenu".into()),
                    ]),
                ),
                child(
                    7,
                    properties(vec![
                        ("label", "Disabled".into()),
                        ("enabled", false.into()),
                    ]),
                ),
            ]
        };
        (
            state.revision,
            (parent_id, items::Properties::new(), children),
        )
    }

    fn event(&self, id: i32, event_id: &str, _data: Value<'_>, _timestamp: u32) {
        self.0
            .lock()
            .unwrap()
            .events
            .push(format!("{event_id}:{id}"));
    }
}

#[test]
#[ignore = "run under dbus-run-session; owns fake tray services on the session bus"]
fn fake_tray_lifecycle_actions_and_dynamic_menus() {
    let mut backend = Backend::new().unwrap();
    backend.icons.halo_color = Some(amane::Color::WHITE);
    backend.refresh().unwrap();
    assert!(backend.items.is_empty());
    let host_name = backend.connection.unique_name().unwrap().to_string();
    assert_eq!(
        watcher::owner(&backend.connection, watcher::SERVICE).unwrap(),
        host_name
    );
    let observer = dbus::connection(true).unwrap();
    let watcher_proxy =
        Proxy::new(&observer, watcher::SERVICE, watcher::PATH, watcher::SERVICE).unwrap();
    assert!(
        watcher_proxy
            .get_property::<bool>("IsStatusNotifierHostRegistered")
            .unwrap()
    );
    assert_eq!(
        watcher_proxy
            .get_property::<i32>("ProtocolVersion")
            .unwrap(),
        0
    );

    let shared = Arc::new(Mutex::new(FakeState {
        status: "Active".into(),
        ..Default::default()
    }));
    let app = Builder::session()
        .unwrap()
        .name("org.example.TrayTest")
        .unwrap()
        .serve_at("/Item", FakeItem(shared.clone()))
        .unwrap()
        .serve_at("/Menu", FakeMenu(shared.clone()))
        .unwrap()
        .build()
        .unwrap();
    let app_watcher = Proxy::new(&app, watcher::SERVICE, watcher::PATH, watcher::SERVICE).unwrap();
    app_watcher
        .call::<_, _, ()>("RegisterStatusNotifierItem", &("/Item",))
        .unwrap();
    // Duplicates and a well-known alias must produce only one visible item.
    app_watcher
        .call::<_, _, ()>("RegisterStatusNotifierItem", &("/Item",))
        .unwrap();
    app_watcher
        .call::<_, _, ()>(
            "RegisterStatusNotifierItem",
            &("org.example.TrayTest/Item",),
        )
        .unwrap();
    assert!(
        app_watcher
            .call::<_, _, ()>("RegisterStatusNotifierItem", &("/not-valid",))
            .is_err()
    );
    backend.refresh().unwrap();
    assert_eq!(backend.items.len(), 1);
    let item = backend.items[0].clone();
    assert_eq!(item.title, "Test application");
    assert_eq!(item.tooltip, "Test application\nTest description");
    assert!(item.visible());
    if std::env::var_os("XDG_RUNTIME_DIR").is_some() {
        let icon = item.icon.as_ref().unwrap();
        assert!(icon.halo.as_ref().unwrap_or(&icon.source).is_file());
    }
    backend
        .command(Command::Action(item.id.clone(), items::Action::Activate))
        .unwrap();
    backend
        .command(Command::Action(item.id.clone(), items::Action::Secondary))
        .unwrap();
    backend
        .command(Command::Action(
            item.id.clone(),
            items::Action::Scroll(120, false),
        ))
        .unwrap();
    assert_eq!(
        &shared.lock().unwrap().events[..3],
        ["activate:0:0", "secondary:0:0", "scroll:120:vertical"]
    );
    backend.items[0].menu = None;
    backend.command(Command::Menu(item.id.clone())).unwrap();
    assert!(backend.menu.is_none());
    assert!(
        shared
            .lock()
            .unwrap()
            .events
            .iter()
            .any(|e| e == "context:0:0")
    );
    backend.refresh().unwrap();

    backend.command(Command::Menu(item.id.clone())).unwrap();
    let menu = backend.menu.as_ref().unwrap();
    assert_eq!(
        shared
            .lock()
            .unwrap()
            .events
            .iter()
            .filter(|event| *event == "activate:0:0")
            .count(),
        1
    );
    assert_eq!(menu.entries.len(), 6);
    assert_eq!(menu.entries[0].label, "Open");
    assert!(menu.entries[1].separator);
    assert_eq!(menu.entries[2].toggle_state, 1);
    assert_eq!(menu.entries[3].toggle, "radio");
    assert!(menu.entries[4].submenu);
    assert!(!menu.entries[5].enabled);
    // A formerly enabled item becoming disabled must not dispatch.
    shared.lock().unwrap().disabled = true;
    backend
        .command(Command::MenuClick(item.id.clone(), 1))
        .unwrap();
    backend
        .command(Command::MenuClick(item.id.clone(), 7))
        .unwrap();
    assert!(
        !shared
            .lock()
            .unwrap()
            .events
            .iter()
            .any(|e| e == "clicked:1" || e == "clicked:7")
    );
    backend
        .command(Command::MenuClick(item.id.clone(), 6))
        .unwrap();
    assert_eq!(backend.menu.as_ref().unwrap().parent(), 6);
    assert_eq!(
        backend.menu.as_ref().unwrap().entries[0].label,
        "Submenu action"
    );
    backend.command(Command::Back).unwrap();
    assert_eq!(backend.menu.as_ref().unwrap().parent(), 0);
    backend
        .command(Command::MenuClick(item.id.clone(), 6))
        .unwrap();
    backend
        .command(Command::MenuClick(item.id.clone(), 8))
        .unwrap();
    assert!(backend.menu.is_none());
    assert!(
        shared
            .lock()
            .unwrap()
            .events
            .iter()
            .any(|e| e == "clicked:8")
    );
    assert!(
        shared
            .lock()
            .unwrap()
            .events
            .iter()
            .any(|e| e == "closed:0")
    );

    shared.lock().unwrap().status = "Passive".into();
    backend.refresh().unwrap();
    assert!(!backend.items[0].visible());
    shared.lock().unwrap().status = "NeedsAttention".into();
    backend.refresh().unwrap();
    assert!(backend.items[0].attention());
    assert_ne!(backend.items[0].icon, item.icon);
    let healthy = Arc::new(Mutex::new(FakeState {
        status: "Active".into(),
        ..Default::default()
    }));
    app.object_server()
        .at("/StatusNotifierItem", FakeItem(healthy))
        .unwrap();
    app_watcher
        .call::<_, _, ()>("RegisterStatusNotifierItem", &("org.example.TrayTest",))
        .unwrap();
    shared.lock().unwrap().failed = true;
    backend.refresh().unwrap();
    assert_eq!(backend.items.len(), 2);
    assert!(backend.items[0].error.is_some());
    assert!(backend.items[1].error.is_none());
    assert!(
        backend
            .command(Command::Action(item.id.clone(), items::Action::Secondary))
            .is_err()
    );
    shared.lock().unwrap().failed = false;
    backend.refresh().unwrap();
    assert!(backend.items[0].error.is_none());

    backend.command(Command::Menu(item.id.clone())).unwrap();
    drop(app_watcher);
    drop(app);
    backend.refresh().unwrap();
    assert!(backend.items.is_empty());
    assert!(backend.menu.is_none());
    assert!(
        backend
            .command(Command::Action(item.id.clone(), items::Action::Secondary))
            .is_err()
    );
    assert!(
        watcher_proxy
            .get_property::<Vec<String>>("RegisteredStatusNotifierItems")
            .unwrap()
            .is_empty()
    );
    drop(watcher_proxy);

    // A reused well-known service must never receive an old owner's actions.
    let replacement = Builder::session()
        .unwrap()
        .name("org.example.TrayTest")
        .unwrap()
        .serve_at("/Item", FakeItem(shared.clone()))
        .unwrap()
        .build()
        .unwrap();
    let replacement_watcher = Proxy::new(
        &replacement,
        watcher::SERVICE,
        watcher::PATH,
        watcher::SERVICE,
    )
    .unwrap();
    replacement_watcher
        .call::<_, _, ()>(
            "RegisterStatusNotifierItem",
            &("org.example.TrayTest/Item",),
        )
        .unwrap();
    backend.refresh().unwrap();
    assert_eq!(backend.items.len(), 1);
    assert_ne!(backend.items[0].id.owner, item.id.owner);
    assert!(
        backend
            .command(Command::Action(item.id, items::Action::Secondary))
            .is_err()
    );
    drop(replacement_watcher);
    drop(replacement);
    backend.refresh().unwrap();
    assert!(backend.items.is_empty());

    // An external watcher takes over only after Amane voluntarily releases.
    backend.connection.release_name(watcher::SERVICE).unwrap();
    let external = dbus::connection(true).unwrap();
    let mut external_host = Host::new(&external).unwrap();
    external_host.refresh(&external).unwrap();
    let external_owner = external.unique_name().unwrap().to_string();
    backend.refresh().unwrap();
    assert_eq!(
        watcher::owner(&backend.connection, watcher::SERVICE).unwrap(),
        external_owner
    );
    assert_ne!(external_owner, host_name);
    drop(external_host);
    drop(external);
    backend.refresh().unwrap();
    assert_eq!(
        watcher::owner(&backend.connection, watcher::SERVICE).unwrap(),
        host_name
    );
    assert!(backend.items.is_empty());
}

#[test]
#[ignore = "read-only smoke check against an existing live tray watcher"]
fn live_backend() {
    let connection = dbus::connection(true).unwrap();
    if !dbus::owned(&connection, watcher::SERVICE).unwrap() {
        println!("No live tray watcher. Hosting is exercised only on the isolated test bus.");
        return;
    }
    let proxy = Proxy::new(
        &connection,
        watcher::SERVICE,
        watcher::PATH,
        watcher::SERVICE,
    )
    .unwrap();
    let entries: Vec<String> = proxy.get_property("RegisteredStatusNotifierItems").unwrap();
    let mut icons = Icons::new();
    for entry in entries {
        println!(
            "{:?}",
            items::read(&connection, &entry, &mut icons).unwrap()
        );
    }
}
