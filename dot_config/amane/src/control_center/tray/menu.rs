use zbus::{
    blocking::{Connection, Proxy},
    zvariant::{OwnedValue, Value},
};

use super::items::{self, Item, Properties};

const INTERFACE: &str = "com.canonical.dbusmenu";
type Layout = (i32, Properties, Vec<OwnedValue>);

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct Entry {
    pub id: i32,
    pub label: String,
    pub enabled: bool,
    pub separator: bool,
    pub toggle: String,
    pub toggle_state: i32,
    pub submenu: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct Menu {
    pub item: Item,
    pub stack: Vec<i32>,
    pub entries: Vec<Entry>,
}

impl Menu {
    pub(super) fn parent(&self) -> i32 {
        *self.stack.last().unwrap_or(&0)
    }
}

fn proxy<'a>(connection: &'a Connection, item: &'a Item) -> zbus::Result<Proxy<'a>> {
    Proxy::new(
        connection,
        item.id.owner.as_str(),
        item.menu
            .as_deref()
            .ok_or_else(|| zbus::Error::Failure("No application menu".into()))?,
        INTERFACE,
    )
}

pub(super) fn read(connection: &Connection, menu: &mut Menu, opening: bool) -> zbus::Result<()> {
    let proxy = proxy(connection, &menu.item)?;
    let parent = menu.parent();
    if opening {
        // Some older implementations omit AboutToShow but still expose GetLayout.
        match proxy.call::<_, _, bool>("AboutToShow", &(parent,)) {
            Ok(_) => {}
            Err(error)
                if matches!(
                    zbus::fdo::Error::from(error.clone()),
                    zbus::fdo::Error::UnknownMethod(_)
                ) => {}
            Err(error) => return Err(error),
        }
    }
    let (_, (returned_parent, _, children)): (u32, Layout) =
        proxy.call("GetLayout", &(parent, 1_i32, Vec::<&str>::new()))?;
    if returned_parent != parent {
        return Err(zbus::Error::Failure(
            "Application returned the wrong menu".into(),
        ));
    }
    menu.entries = entries(children)?;
    if opening {
        event(connection, menu, parent, "opened")?;
    }
    Ok(())
}

fn entries(children: Vec<OwnedValue>) -> zbus::Result<Vec<Entry>> {
    if children.len() > 1024 {
        return Err(zbus::Error::Failure("Application menu is too large".into()));
    }
    let mut ids = std::collections::HashSet::new();
    children
        .into_iter()
        .map(|child| {
            let (id, properties, children): Layout = child.try_into()?;
            if id <= 0 || !ids.insert(id) {
                return Err(zbus::Error::Failure(
                    "Invalid or duplicate menu entry".into(),
                ));
            }
            if !items::boolean(&properties, "visible", true) {
                return Ok(None);
            }
            Ok(Some(Entry {
                id,
                label: label(&items::string(&properties, "label")),
                enabled: items::boolean(&properties, "enabled", true),
                separator: items::string(&properties, "type") == "separator",
                toggle: items::string(&properties, "toggle-type"),
                toggle_state: items::integer(&properties, "toggle-state").clamp(-1, 1),
                submenu: items::string(&properties, "children-display") == "submenu"
                    || !children.is_empty(),
            }))
        })
        .filter_map(|result| result.transpose())
        .collect()
}

pub(super) fn event(connection: &Connection, menu: &Menu, id: i32, name: &str) -> zbus::Result<()> {
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u32;
    proxy(connection, &menu.item)?.call("Event", &(id, name, Value::I32(0), timestamp))
}

/// DBusMenu underscores denote mnemonics; doubled underscores are literal.
pub(super) fn label(value: &str) -> String {
    let mut chars = value.chars().peekable();
    let mut label = String::new();
    while let Some(ch) = chars.next() {
        if ch != '_' {
            label.push(ch);
        } else if chars.peek() == Some(&'_') {
            label.push('_');
            chars.next();
        }
    }
    label
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn labels_remove_mnemonics_but_preserve_escaped_underscores() {
        assert_eq!(label("_Open __folder"), "Open _folder");
    }

    #[test]
    fn malformed_children_are_rejected_without_panicking() {
        assert!(entries(vec![OwnedValue::from(42_i32)]).is_err());
        assert!(entries((0..1025).map(OwnedValue::from).collect()).is_err());
    }
}
