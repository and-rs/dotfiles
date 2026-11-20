mod icons;
mod items;
mod menu;
#[cfg(test)]
mod tests;
mod view;
mod watcher;

use std::{
    collections::HashSet,
    sync::{
        LazyLock, Mutex,
        atomic::{AtomicBool, AtomicU64, Ordering},
        mpsc::{self, Receiver, SyncSender},
    },
    time::Duration,
};

use amane::{Rectangle, Service};
use zbus::blocking::Connection;

use crate::{
    control_center::{dbus, ui},
    theme::Theme,
};
use icons::Icons;
use items::{Id, Item};
use menu::Menu;
use watcher::Host;

pub(super) use view::view;

const REFRESH: Duration = Duration::from_secs(2);
const MENU_REFRESH: Duration = Duration::from_millis(500);
static ACTIVE: AtomicBool = AtomicBool::new(false);
static GENERATION: AtomicU64 = AtomicU64::new(0);
static REQUESTS: LazyLock<(SyncSender<Request>, Mutex<Receiver<Request>>)> = LazyLock::new(|| {
    let (tx, rx) = mpsc::sync_channel(64);
    (tx, Mutex::new(rx))
});

struct State {
    items: Vec<Item>,
    menu: Option<Menu>,
    loading: bool,
    error: Option<Error>,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Error {
    Backend,
    Action,
    Busy,
}

impl Error {
    fn message(self) -> &'static str {
        match self {
            Self::Backend => "Could not update the tray. Retrying automatically.",
            Self::Action => "The application could not complete that action.",
            Self::Busy => "The tray is busy. Try again.",
        }
    }
}

enum Command {
    Action(Id, items::Action),
    Menu(Id),
    MenuClick(Id, i32),
    Back,
    Reset,
}

struct Request {
    generation: u64,
    command: Command,
}

struct Backend {
    connection: Connection,
    host: Host,
    icons: Icons,
    items: Vec<Item>,
    menu: Option<Menu>,
}

impl Backend {
    fn new() -> zbus::Result<Self> {
        let connection = dbus::connection(true)?;
        let host = Host::new(&connection)?;
        Ok(Self {
            connection,
            host,
            icons: Icons::new(),
            items: Vec::new(),
            menu: None,
        })
    }

    fn refresh(&mut self) -> zbus::Result<()> {
        let entries = self.host.refresh(&self.connection)?;
        let mut items = Vec::new();
        let mut ids = HashSet::new();
        for entry in entries {
            match items::read(&self.connection, &entry, &mut self.icons) {
                Ok(item) if ids.insert(item.id.clone()) => items.push(item),
                Ok(_) => {}
                Err(error) => {
                    eprintln!("tray item {entry}: {error}");
                    // Preserve a failed item's row without routing actions to a new owner.
                    if let Some((service, path)) = watcher::split_item(&entry)
                        && let Ok(owner) = watcher::owner(&self.connection, service)
                    {
                        let id = Id {
                            owner,
                            path: path.into(),
                        };
                        if ids.insert(id.clone()) {
                            let mut item = self
                                .items
                                .iter()
                                .find(|i| i.id == id)
                                .cloned()
                                .unwrap_or(Item {
                                    id,
                                    interface: "org.kde.StatusNotifierItem".into(),
                                    title: service.into(),
                                    tooltip: String::new(),
                                    status: "Active".into(),
                                    icon: None,
                                    menu: None,
                                    menu_only: false,
                                    error: None,
                                });
                            item.error = Some("Could not read application status.".into());
                            items.push(item);
                        }
                    }
                }
            }
        }
        items.sort_by_key(|item| {
            (
                !item.attention(),
                item.title.to_lowercase(),
                item.id.owner.clone(),
                item.id.path.clone(),
            )
        });
        self.icons
            .retain(items.iter().filter_map(|item| item.icon.as_ref()));
        self.items = items;
        if let Some(menu) = &mut self.menu {
            if let Some(item) = self
                .items
                .iter()
                .find(|i| i.id == menu.item.id && i.menu == menu.item.menu && i.error.is_none())
            {
                menu.item = item.clone();
            } else {
                self.menu = None;
            }
        }
        Ok(())
    }

    fn command(&mut self, command: Command) -> zbus::Result<()> {
        match command {
            Command::Reset => {
                let _ = self.close_menu();
                Ok(())
            }
            Command::Back => {
                if let Some(menu) = &mut self.menu
                    && !menu.stack.is_empty()
                {
                    menu::event(&self.connection, menu, menu.parent(), "closed")?;
                    menu.stack.pop();
                    return menu::read(&self.connection, menu, true);
                }
                self.close_menu()
            }
            Command::Action(id, action) => {
                let item = self
                    .items
                    .iter()
                    .find(|i| i.id == id && i.error.is_none())
                    .ok_or_else(|| zbus::Error::Failure("Tray item disappeared".into()))?;
                items::act(&self.connection, item, action)
            }
            Command::Menu(id) => {
                let item = self
                    .items
                    .iter()
                    .find(|i| i.id == id && i.error.is_none())
                    .ok_or_else(|| zbus::Error::Failure("Tray item disappeared".into()))?
                    .clone();
                let _ = self.close_menu();
                if item.menu.is_none() {
                    return items::act(&self.connection, &item, items::Action::ContextMenu);
                }
                let mut menu = Menu {
                    item,
                    stack: Vec::new(),
                    entries: Vec::new(),
                };
                menu::read(&self.connection, &mut menu, true)?;
                self.menu = Some(menu);
                Ok(())
            }
            Command::MenuClick(id, entry_id) => {
                let Some(menu) = &mut self.menu else {
                    return Ok(());
                };
                if menu.item.id != id {
                    return Ok(());
                }
                // Re-read before dispatch so removed or disabled entries cannot be clicked.
                menu::read(&self.connection, menu, false)?;
                let Some(entry) = menu
                    .entries
                    .iter()
                    .find(|e| e.id == entry_id && e.enabled && !e.separator)
                else {
                    return Ok(());
                };
                if entry.submenu {
                    if menu.stack.len() >= 16 {
                        return Ok(());
                    }
                    menu.stack.push(entry_id);
                    menu::read(&self.connection, menu, true)
                } else {
                    menu::event(&self.connection, menu, entry_id, "clicked")?;
                    self.close_menu()
                }
            }
        }
    }

    fn close_menu(&mut self) -> zbus::Result<()> {
        if let Some(menu) = self.menu.take() {
            for id in menu.stack.iter().rev().copied().chain(std::iter::once(0)) {
                menu::event(&self.connection, &menu, id, "closed")?;
            }
        }
        Ok(())
    }
}

impl Service for State {
    fn new() -> Self {
        Self {
            items: Vec::new(),
            menu: None,
            loading: true,
            error: None,
        }
    }

    fn listen() {
        let receiver = REQUESTS.1.lock().expect("tray receiver poisoned");
        let mut backend: Option<Backend> = None;
        let mut menu_generation = GENERATION.load(Ordering::SeqCst);
        loop {
            let generation = GENERATION.load(Ordering::SeqCst);
            let mut menu_failed = false;
            let result = (|| {
                if backend.is_none() {
                    backend = Some(Backend::new()?);
                }
                let backend = backend.as_mut().expect("tray backend connected");
                if menu_generation != generation || !ACTIVE.load(Ordering::SeqCst) {
                    let _ = backend.close_menu();
                }
                menu_generation = generation;
                backend.icons.halo_color = Some(crate::theme::ThemeState::read().theme.fg);
                backend.refresh()?;
                if let Some(menu) = &mut backend.menu
                    && let Err(error) = menu::read(&backend.connection, menu, false)
                {
                    eprintln!("tray menu refresh: {error}");
                    backend.menu = None;
                    menu_failed = true;
                }
                Ok::<_, zbus::Error>(())
            })();
            {
                let mut state = Self::write();
                state.loading = false;
                match result {
                    Ok(()) => {
                        let backend = backend.as_ref().expect("tray backend connected");
                        state.items = backend.items.clone();
                        if state.error == Some(Error::Backend) {
                            state.error = None;
                        }
                        if menu_failed {
                            state.error = Some(Error::Action);
                        }
                        if GENERATION.load(Ordering::SeqCst) == generation
                            && ACTIVE.load(Ordering::SeqCst)
                        {
                            state.menu = backend.menu.clone();
                        }
                    }
                    Err(error) => {
                        eprintln!("tray refresh: {error}");
                        state.error = Some(Error::Backend);
                        state.menu = None;
                        state.items.clear();
                        if backend.as_ref().is_none_or(|b| b.connection.is_closed()) {
                            state.items.clear();
                            backend = None;
                        } else if let Some(b) = &mut backend {
                            b.menu = None;
                        }
                    }
                }
            }
            let interval = if backend.as_ref().is_some_and(|b| b.menu.is_some()) {
                MENU_REFRESH
            } else {
                REFRESH
            };
            let Ok(request) = receiver.recv_timeout(interval) else {
                continue;
            };
            if request.generation != GENERATION.load(Ordering::SeqCst) {
                continue;
            }
            if !ACTIVE.load(Ordering::SeqCst) && !matches!(request.command, Command::Reset) {
                continue;
            }
            if let Some(backend) = &mut backend {
                let result = backend.command(request.command);
                let mut state = Self::write();
                if request.generation == GENERATION.load(Ordering::SeqCst) {
                    match result {
                        Ok(()) => state.error = None,
                        Err(error) => {
                            eprintln!("tray action: {error}");
                            state.error = Some(Error::Action);
                        }
                    }
                    state.menu = backend.menu.clone();
                }
            }
        }
    }
}

fn request(command: Command) {
    let request = Request {
        generation: GENERATION.load(Ordering::SeqCst),
        command,
    };
    if REQUESTS.0.try_send(request).is_err() {
        State::write().error = Some(Error::Busy);
    }
}

pub(super) fn set_active(active: bool) {
    if ACTIVE.swap(active, Ordering::SeqCst) != active {
        GENERATION.fetch_add(1, Ordering::SeqCst);
        State::write().menu = None;
        request(Command::Reset);
    }
}

pub(super) fn escape() -> bool {
    if State::read().menu.is_some() {
        request(Command::Back);
        return true;
    }
    false
}

pub(super) fn indicator(theme: &Theme) -> Rectangle {
    let state = State::read();
    let visible = state.items.iter().filter(|i| i.visible()).count();
    let color = if state.items.iter().any(Item::attention) {
        theme.accent
    } else if visible > 0 {
        theme.fg
    } else {
        theme.surface4
    };
    let glyph = if visible > 0 { '\u{e136}' } else { '\u{ece0}' };
    ui::icon(glyph, color)
}
