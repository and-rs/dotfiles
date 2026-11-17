mod backend;
#[cfg(test)]
mod tests;
mod view;

use std::{
    sync::{
        LazyLock, Mutex,
        atomic::{AtomicBool, Ordering},
        mpsc::{self, Receiver, RecvTimeoutError, Sender},
    },
    thread,
    time::{Duration, Instant},
};

use amane::{Rectangle, Service};
use zbus::{
    blocking::{Connection, connection::Builder},
    zvariant::OwnedObjectPath,
};

use crate::{
    control_center::{dbus, ui},
    theme::Theme,
};
use backend::{Action, BLUEZ, Error, Reading, Snapshot, apply_action, discovery, read, snapshot};

pub(super) use view::view;

const REFRESH: Duration = Duration::from_secs(2);
const SCAN_TIME: Duration = Duration::from_secs(15);
const ACTION_TIMEOUT: Duration = Duration::from_secs(30);

static VISIBLE: AtomicBool = AtomicBool::new(false);
static WANT_SCAN: AtomicBool = AtomicBool::new(false);
static REQUESTS: LazyLock<(Sender<Request>, Mutex<Receiver<Request>>)> = LazyLock::new(|| {
    let (sender, receiver) = mpsc::channel();
    (sender, Mutex::new(receiver))
});

enum Request {
    Wake,
    Scan,
}

struct State {
    reading: Reading,
    pending: Option<Action>,
    error: Option<Error>,
    scanning: bool,
}

struct Discovery {
    path: OwnedObjectPath,
    until: Instant,
}

impl Discovery {
    fn should_stop(&self, visible: bool, wanted: bool, now: Instant) -> bool {
        !visible || !wanted || now >= self.until
    }

    fn valid_for(&self, snapshot: Option<&Snapshot>) -> bool {
        snapshot
            .is_some_and(|snapshot| snapshot.adapter.powered && snapshot.adapter.path == self.path)
    }
}

impl Service for State {
    fn new() -> Self {
        Self {
            reading: Reading::unavailable(Error::Loading),
            pending: None,
            error: None,
            scanning: false,
        }
    }

    fn listen() {
        let receiver = REQUESTS.1.lock().expect("Bluetooth receiver poisoned");
        let mut bus = None;
        let mut scan: Option<Discovery> = None;
        loop {
            let result = (|| {
                if bus.is_none() {
                    bus = Some(dbus::connection(false)?);
                }
                let connection = bus.as_ref().expect("connected Bluetooth bus");
                if scan.as_ref().is_some_and(|scan| {
                    scan.should_stop(
                        VISIBLE.load(Ordering::SeqCst),
                        WANT_SCAN.load(Ordering::SeqCst),
                        Instant::now(),
                    )
                }) {
                    WANT_SCAN.store(false, Ordering::SeqCst);
                    let result = stop_discovery(connection, BLUEZ, &mut scan);
                    Self::write().scanning = false;
                    result?;
                }
                read(connection)
            })();
            let fresh = match result {
                Ok(reading) => {
                    if scan
                        .as_ref()
                        .is_some_and(|scan| !scan.valid_for(reading.snapshot.as_ref()))
                    {
                        // Close our connection rather than stopping another adapter's scan.
                        bus = None;
                        scan = None;
                        WANT_SCAN.store(false, Ordering::SeqCst);
                        Self::write().scanning = false;
                    }
                    reading
                }
                Err(error) => {
                    // Dropping our connection also releases its discovery session.
                    bus = None;
                    scan = None;
                    WANT_SCAN.store(false, Ordering::SeqCst);
                    Self::write().scanning = false;
                    Reading::unavailable(error)
                }
            };
            publish(fresh);
            match receiver.recv_timeout(REFRESH) {
                Ok(Request::Wake) => {}
                Ok(Request::Scan) => {
                    let result = (|| {
                        if !VISIBLE.load(Ordering::SeqCst) || !WANT_SCAN.load(Ordering::SeqCst) {
                            return Ok(());
                        }
                        let connection = bus.as_ref().ok_or(Error::Unavailable)?;
                        let objects = dbus::objects(connection, BLUEZ, "/")?;
                        let snapshot = snapshot(&objects).ok_or(Error::NoAdapter)?;
                        if !snapshot.adapter.powered {
                            return Err(Error::StateChanged);
                        }
                        discovery(connection, BLUEZ, &snapshot.adapter.path, true)?;
                        scan = Some(Discovery {
                            path: snapshot.adapter.path,
                            until: Instant::now() + SCAN_TIME,
                        });
                        Ok::<_, Error>(())
                    })();
                    if result.is_err() {
                        bus = None;
                        scan = None;
                        WANT_SCAN.store(false, Ordering::SeqCst);
                    }
                    let mut state = Self::write();
                    state.scanning = scan.is_some();
                    state.pending = None;
                    state.error = result.err();
                }
                Err(RecvTimeoutError::Timeout) => {}
                Err(RecvTimeoutError::Disconnected) => return,
            }
        }
    }
}

pub(super) fn set_active(visible: bool) {
    VISIBLE.store(visible, Ordering::SeqCst);
    if !visible {
        WANT_SCAN.store(false, Ordering::SeqCst);
    }
    let _ = REQUESTS.0.send(Request::Wake);
}

fn publish(reading: Reading) {
    let changed = State::read().reading != reading;
    if changed {
        State::write().reading = reading;
    }
}

fn stop_discovery(
    connection: &Connection,
    destination: &str,
    scan: &mut Option<Discovery>,
) -> zbus::Result<()> {
    if let Some(scan) = scan.take() {
        discovery(connection, destination, &scan.path, false)?;
    }
    Ok(())
}

fn request(action: Action) {
    if action == Action::StopScan {
        WANT_SCAN.store(false, Ordering::SeqCst);
        let _ = REQUESTS.0.send(Request::Wake);
        return;
    }
    let allowed = State::read()
        .reading
        .snapshot
        .as_ref()
        .is_some_and(|snapshot| action.allowed(snapshot));
    if !allowed || !VISIBLE.load(Ordering::SeqCst) {
        return;
    }
    {
        let mut state = State::write();
        if state.pending.is_some() {
            return;
        }
        state.pending = Some(action.clone());
        state.error = None;
    }
    if action == Action::Scan {
        WANT_SCAN.store(true, Ordering::SeqCst);
        if REQUESTS.0.send(Request::Scan).is_err() {
            let mut state = State::write();
            state.pending = None;
            state.error = Some(Error::Failed);
            WANT_SCAN.store(false, Ordering::SeqCst);
        }
        return;
    }
    // A slow Connect must not delay discovery cleanup or background reads.
    thread::spawn(move || {
        let result = (|| {
            let connection = Builder::system()?.method_timeout(ACTION_TIMEOUT).build()?;
            let result = apply_action(&connection, BLUEZ, &action);
            if let Ok(reading) = read(&connection) {
                publish(reading);
            }
            result
        })();
        {
            let mut state = State::write();
            state.pending = None;
            state.error = result.err();
        }
        let _ = REQUESTS.0.send(Request::Wake);
    });
}

pub(super) fn indicator(theme: &Theme) -> Rectangle {
    let state = State::read();
    let reading = &state.reading;
    let enabled = reading
        .snapshot
        .as_ref()
        .is_some_and(|snapshot| snapshot.adapter.powered);
    let (glyph, color) = if !enabled {
        ('\u{e0de}', theme.surface4)
    } else if reading.connected {
        ('\u{e0dc}', theme.accent)
    } else {
        ('\u{e0da}', theme.fg)
    };
    ui::icon(glyph, color)
}
