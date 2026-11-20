use std::collections::HashMap;

use zbus::{
    blocking::{Connection, Proxy},
    zvariant::OwnedValue,
};

use super::{
    icons::{Icons, Pixmap},
    watcher,
};

pub(super) type Properties = HashMap<String, OwnedValue>;

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub(super) struct Id {
    pub owner: String,
    pub path: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct Item {
    pub id: Id,
    pub interface: String,
    pub title: String,
    pub tooltip: String,
    pub status: String,
    pub icon: Option<super::icons::Icon>,
    pub menu: Option<String>,
    pub menu_only: bool,
    pub error: Option<String>,
}

impl Item {
    pub(super) fn visible(&self) -> bool {
        self.status != "Passive"
    }
    pub(super) fn attention(&self) -> bool {
        self.status == "NeedsAttention"
    }
}

pub(super) fn string(properties: &Properties, key: &str) -> String {
    properties
        .get(key)
        .and_then(|value| <&str>::try_from(value).ok())
        .unwrap_or_default()
        .into()
}

pub(super) fn boolean(properties: &Properties, key: &str, default: bool) -> bool {
    properties
        .get(key)
        .and_then(|v| bool::try_from(v).ok())
        .unwrap_or(default)
}

pub(super) fn integer(properties: &Properties, key: &str) -> i32 {
    properties
        .get(key)
        .and_then(|v| i32::try_from(v).ok())
        .unwrap_or_default()
}

pub(super) fn read(connection: &Connection, entry: &str, icons: &mut Icons) -> zbus::Result<Item> {
    let (service, path) = watcher::split_item(entry)
        .ok_or_else(|| zbus::Error::Failure("Invalid tray registration".into()))?;
    let id = Id {
        owner: watcher::owner(connection, service)?,
        path: path.into(),
    };
    let mut last_error = None;
    for interface in [
        "org.kde.StatusNotifierItem",
        "org.freedesktop.StatusNotifierItem",
    ] {
        let proxy = Proxy::new(
            connection,
            id.owner.as_str(),
            path,
            "org.freedesktop.DBus.Properties",
        )?;
        match proxy.call::<_, _, Properties>("GetAll", &(interface,)) {
            Ok(properties) if !properties.is_empty() => {
                if !matches!(
                    string(&properties, "Status").as_str(),
                    "Active" | "Passive" | "NeedsAttention"
                ) {
                    return Err(zbus::Error::Failure("Tray item has no valid Status".into()));
                }
                drop(proxy);
                return Ok(from_properties(id, interface, &properties, icons));
            }
            Err(error) => last_error = Some(error),
            _ => {}
        }
    }
    Err(last_error.unwrap_or_else(|| zbus::Error::Failure("Tray item has no properties".into())))
}

fn from_properties(id: Id, interface: &str, properties: &Properties, icons: &mut Icons) -> Item {
    let mut title = string(properties, "Title");
    if title.is_empty() {
        title = string(properties, "Id");
    }
    if title.is_empty() {
        title = "Unnamed application".into();
    }
    let status = string(properties, "Status");
    let theme_path = string(properties, "IconThemePath");
    let prefix = if status == "NeedsAttention" {
        "AttentionIcon"
    } else {
        "Icon"
    };
    let load_icon = |icons: &mut Icons, prefix: &str| {
        let pixmaps: Vec<Pixmap> = properties
            .get(&format!("{prefix}Pixmap"))
            .and_then(|v| v.try_clone().ok())
            .and_then(|v| v.try_into().ok())
            .unwrap_or_default();
        icons.resolve(
            &string(properties, &format!("{prefix}Name")),
            &theme_path,
            &pixmaps,
        )
    };
    let icon = load_icon(icons, prefix).or_else(|| load_icon(icons, "Icon"));
    let tooltip = properties
        .get("ToolTip")
        .and_then(|v| v.try_clone().ok())
        .and_then(|v| <(String, Vec<Pixmap>, String, String)>::try_from(v).ok())
        .map(|(_, _, title, description)| {
            if description.is_empty() {
                title
            } else {
                format!("{title}\n{description}")
            }
        })
        .unwrap_or_default();
    let menu = properties
        .get("Menu")
        .and_then(|v| <&zbus::zvariant::ObjectPath>::try_from(v).ok())
        .filter(|path| path.as_str() != "/")
        .map(ToString::to_string);
    Item {
        id,
        interface: interface.into(),
        title,
        tooltip,
        status,
        icon,
        menu,
        menu_only: boolean(properties, "ItemIsMenu", false),
        error: None,
    }
}

#[derive(Clone, Copy, Debug)]
pub(super) enum Action {
    Secondary,
    ContextMenu,
    Scroll(i32, bool),
}

pub(super) fn act(connection: &Connection, item: &Item, action: Action) -> zbus::Result<()> {
    let proxy = Proxy::new(
        connection,
        item.id.owner.as_str(),
        item.id.path.as_str(),
        item.interface.as_str(),
    )?;
    // Wayland does not expose global pointer coordinates. DBusMenu is rendered
    // locally; applications requiring coordinates receive the protocol fallback.
    match action {
        Action::Secondary => proxy.call("SecondaryActivate", &(0_i32, 0_i32)),
        Action::ContextMenu => proxy.call("ContextMenu", &(0_i32, 0_i32)),
        Action::Scroll(delta, horizontal) => {
            let orientation = if horizontal { "horizontal" } else { "vertical" };
            proxy.call("Scroll", &(delta, orientation))
        }
    }
}
