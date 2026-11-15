use std::{
    os::fd::OwnedFd,
    sync::{
        LazyLock, Mutex,
        mpsc::{self, Receiver, SyncSender},
    },
    time::Duration,
};

use amane::Service;

static TOGGLES: LazyLock<(SyncSender<()>, Mutex<Receiver<()>>)> = LazyLock::new(|| {
    let (sender, receiver) = mpsc::sync_channel(1);
    (sender, Mutex::new(receiver))
});

#[derive(Default)]
pub struct Caffeine {
    pub active: bool,
}

impl Service for Caffeine {
    fn new() -> Self {
        Self::default()
    }

    fn listen() {
        // One owner for every monitor. D-Bus work never holds the UI state lock.
        let mut inhibitor = None;
        let receiver = TOGGLES.1.lock().expect("caffeine receiver poisoned");
        for () in receiver.iter() {
            match toggle(&mut inhibitor, acquire) {
                Ok(()) => Self::write().active = inhibitor.is_some(),
                Err(error) => eprintln!("caffeine: {error}"),
            }
        }
    }
}

pub fn request_toggle() {
    // Ignore excess clicks while the worker is busy.
    let _ = TOGGLES.0.try_send(());
}

fn toggle(
    inhibitor: &mut Option<OwnedFd>,
    acquire: impl FnOnce() -> Result<OwnedFd, String>,
) -> Result<(), String> {
    if inhibitor.take().is_some() {
        return Ok(());
    }
    *inhibitor = Some(acquire()?);
    Ok(())
}

fn acquire() -> Result<OwnedFd, String> {
    let connection = zbus::blocking::connection::Builder::system()
        .and_then(|builder| builder.method_timeout(Duration::from_secs(2)).build())
        .map_err(|error| error.to_string())?;
    let reply = connection
        .call_method(
            Some("org.freedesktop.login1"),
            "/org/freedesktop/login1",
            Some("org.freedesktop.login1.Manager"),
            "Inhibit",
            &("idle:sleep", "amane_shell", "Caffeine", "block"),
        )
        .map_err(|error| error.to_string())?;
    let descriptor: zbus::zvariant::OwnedFd = reply
        .body()
        .deserialize()
        .map_err(|error| error.to_string())?;
    // Logind ties inhibition to this descriptor, not the D-Bus connection.
    // Closing it, including on a crash, releases the inhibitor without a helper.
    Ok(descriptor.into())
}

#[cfg(test)]
mod tests {
    use std::{
        io::{ErrorKind, Read},
        os::unix::net::UnixStream,
    };

    use super::*;

    #[test]
    fn repeated_toggles_share_one_inhibitor_and_close_it_on_disable() {
        let (owned, mut peer) = UnixStream::pair().unwrap();
        peer.set_nonblocking(true).unwrap();
        let mut inhibitor = None;
        toggle(&mut inhibitor, || Ok(owned.into())).unwrap();
        assert!(inhibitor.is_some());
        assert_eq!(
            peer.read(&mut [0]).unwrap_err().kind(),
            ErrorKind::WouldBlock
        );

        toggle(&mut inhibitor, || panic!("must not acquire twice")).unwrap();
        assert!(inhibitor.is_none());
        assert_eq!(peer.read(&mut [0]).unwrap(), 0);
    }

    #[test]
    fn acquisition_failure_stays_off_and_can_be_retried() {
        let mut inhibitor = None;
        assert_eq!(
            toggle(&mut inhibitor, || Err("denied".into())),
            Err("denied".into())
        );
        assert!(inhibitor.is_none());
        let (owned, _) = UnixStream::pair().unwrap();
        toggle(&mut inhibitor, || Ok(owned.into())).unwrap();
        assert!(inhibitor.is_some());
    }

    #[test]
    #[ignore = "briefly acquires a real logind idle/sleep inhibitor"]
    fn logind_releases_inhibition_when_descriptor_closes() {
        fn listed() -> bool {
            let connection = zbus::blocking::Connection::system().unwrap();
            let reply = connection
                .call_method(
                    Some("org.freedesktop.login1"),
                    "/org/freedesktop/login1",
                    Some("org.freedesktop.login1.Manager"),
                    "ListInhibitors",
                    &(),
                )
                .unwrap();
            let inhibitors: Vec<(String, String, String, String, u32, u32)> =
                reply.body().deserialize().unwrap();
            inhibitors.iter().any(|(what, who, _, mode, _, pid)| {
                what.split(':').any(|kind| kind == "idle")
                    && what.split(':').any(|kind| kind == "sleep")
                    && who == "amane_shell"
                    && mode == "block"
                    && *pid == std::process::id()
            })
        }

        let descriptor = acquire().unwrap();
        assert!(listed());
        drop(descriptor);
        let deadline = std::time::Instant::now() + Duration::from_secs(2);
        while listed() {
            assert!(std::time::Instant::now() < deadline);
            std::thread::sleep(Duration::from_millis(10));
        }
    }
}
