use std::{
    collections::{HashMap, HashSet},
    error::Error,
    thread,
    time::Duration,
};

use amane::Service;
use wayland_client::{
    Connection, Dispatch, Proxy, QueueHandle,
    backend::ObjectId,
    protocol::{wl_output, wl_registry},
};
use wayland_protocols_wlr::foreign_toplevel::v1::client::{
    zwlr_foreign_toplevel_handle_v1::{self as handle, ZwlrForeignToplevelHandleV1},
    zwlr_foreign_toplevel_manager_v1::{self as manager, ZwlrForeignToplevelManagerV1},
};

#[derive(Default)]
pub struct Fullscreen {
    outputs: HashSet<String>,
}

impl Fullscreen {
    pub fn hidden_on(&self, output: &str) -> bool {
        self.outputs.contains(output)
    }

    fn publish(outputs: HashSet<String>) {
        let changed = Self::read().outputs != outputs;
        if changed {
            Self::write().outputs = outputs;
        }
    }
}

impl Service for Fullscreen {
    fn new() -> Self {
        Self::default()
    }

    fn listen() {
        loop {
            if let Err(error) = follow() {
                Self::publish(HashSet::new());
                eprintln!("fullscreen tracking unavailable: {error}; retrying in 2 seconds");
            }
            thread::sleep(Duration::from_secs(2));
        }
    }
}

// Pending properties become visible together at the protocol's `done` event.
#[derive(Clone, Default)]
struct WindowInfo {
    active: bool,
    fullscreen: bool,
    outputs: HashSet<ObjectId>,
}

impl WindowInfo {
    fn set_states(&mut self, states: &[u8]) {
        self.active = false;
        self.fullscreen = false;
        for bytes in states.as_chunks::<4>().0 {
            let state = u32::from_ne_bytes(*bytes);
            self.active |= state == handle::State::Activated as u32;
            self.fullscreen |= state == handle::State::Fullscreen as u32;
        }
    }
}

#[derive(Default)]
struct Window {
    pending: WindowInfo,
    current: WindowInfo,
}

impl Window {
    fn done(&mut self) {
        self.current = self.pending.clone();
    }
}

struct Output {
    proxy: wl_output::WlOutput,
    name: Option<String>,
}

#[derive(Default)]
struct Tracker {
    manager: Option<(u32, ZwlrForeignToplevelManagerV1)>,
    outputs: HashMap<u32, Output>,
    windows: HashMap<ObjectId, Window>,
    finished: bool,
}

impl Tracker {
    fn hidden_outputs(&self) -> HashSet<String> {
        self.outputs
            .values()
            .filter(|output| {
                self.windows.values().any(|window| {
                    window.current.active
                        && window.current.fullscreen
                        && window.current.outputs.contains(&output.proxy.id())
                })
            })
            .filter_map(|output| output.name.clone())
            .collect()
    }
}

fn follow() -> Result<(), Box<dyn Error>> {
    let connection = Connection::connect_to_env()?;
    let mut queue = connection.new_event_queue();
    let qh = queue.handle();
    let _registry = connection.display().get_registry(&qh, ());
    let mut tracker = Tracker::default();
    queue.roundtrip(&mut tracker)?;
    if tracker.manager.is_none() {
        return Err("wlr-foreign-toplevel-management v2 or newer is required".into());
    }
    loop {
        queue.blocking_dispatch(&mut tracker)?;
        if tracker.finished {
            return Err("foreign toplevel manager disconnected".into());
        }
        // Protocol handlers only collect state; views own all visibility decisions.
        Fullscreen::publish(tracker.hidden_outputs());
    }
}

impl Dispatch<wl_registry::WlRegistry, ()> for Tracker {
    fn event(
        state: &mut Self,
        registry: &wl_registry::WlRegistry,
        event: wl_registry::Event,
        _: &(),
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        match event {
            wl_registry::Event::Global {
                name,
                interface,
                version,
            } => {
                if interface == wl_output::WlOutput::interface().name && version >= 4 {
                    let proxy = registry.bind(name, 4, qh, name);
                    state.outputs.insert(name, Output { proxy, name: None });
                } else if interface == ZwlrForeignToplevelManagerV1::interface().name
                    && version >= 2
                    && state.manager.is_none()
                {
                    state.manager = Some((name, registry.bind(name, version.min(3), qh, ())));
                }
            }
            wl_registry::Event::GlobalRemove { name } => {
                if let Some(output) = state.outputs.remove(&name) {
                    output.proxy.release();
                }
                if state.manager.as_ref().is_some_and(|(id, _)| *id == name) {
                    state.finished = true;
                }
            }
            _ => {}
        }
    }
}

impl Dispatch<wl_output::WlOutput, u32> for Tracker {
    fn event(
        state: &mut Self,
        _: &wl_output::WlOutput,
        event: wl_output::Event,
        name: &u32,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let wl_output::Event::Name { name: output_name } = event
            && let Some(output) = state.outputs.get_mut(name)
        {
            output.name = Some(output_name);
        }
    }
}

impl Dispatch<ZwlrForeignToplevelManagerV1, ()> for Tracker {
    fn event(
        state: &mut Self,
        _: &ZwlrForeignToplevelManagerV1,
        event: manager::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        match event {
            manager::Event::Toplevel { toplevel } => {
                state.windows.insert(toplevel.id(), Window::default());
            }
            manager::Event::Finished => state.finished = true,
            _ => {}
        }
    }

    wayland_client::event_created_child!(Tracker, ZwlrForeignToplevelManagerV1, [
        0 => (ZwlrForeignToplevelHandleV1, ())
    ]);
}

impl Dispatch<ZwlrForeignToplevelHandleV1, ()> for Tracker {
    fn event(
        state: &mut Self,
        toplevel: &ZwlrForeignToplevelHandleV1,
        event: handle::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let handle::Event::Closed = event {
            state.windows.remove(&toplevel.id());
            toplevel.destroy();
            return;
        }
        let Some(window) = state.windows.get_mut(&toplevel.id()) else {
            return;
        };
        match event {
            handle::Event::State { state } => window.pending.set_states(&state),
            handle::Event::OutputEnter { output } => {
                window.pending.outputs.insert(output.id());
            }
            handle::Event::OutputLeave { output } => {
                window.pending.outputs.remove(&output.id());
            }
            handle::Event::Done => window.done(),
            _ => {}
        }
    }
}

#[cfg(test)]
mod tests {
    use std::os::unix::net::UnixStream;

    use super::*;

    // Allocate real, distinct client object IDs without a compositor or display.
    fn initial() -> (Connection, UnixStream, Tracker) {
        let (client, server) = UnixStream::pair().unwrap();
        let connection = Connection::from_socket(client).unwrap();
        let queue = connection.new_event_queue::<Tracker>();
        let qh = queue.handle();
        let registry = connection.display().get_registry(&qh, ());
        let mut tracker = Tracker::default();
        for (id, name) in [(1, "A"), (2, "B")] {
            tracker.outputs.insert(
                id,
                Output {
                    proxy: registry.bind(id, 4, &qh, id),
                    name: Some(name.to_owned()),
                },
            );
        }
        (connection, server, tracker)
    }

    fn states(states: &[handle::State]) -> Vec<u8> {
        states
            .iter()
            .flat_map(|state| (*state as u32).to_ne_bytes())
            .collect()
    }

    fn fullscreen_window(output: ObjectId) -> Window {
        let mut window = Window::default();
        window.pending.outputs.insert(output);
        window.pending.set_states(&states(&[
            handle::State::Activated,
            handle::State::Fullscreen,
        ]));
        window
    }

    #[test]
    fn only_the_active_fullscreen_output_is_hidden_after_done() {
        let (_connection, _server, mut tracker) = initial();
        let a = tracker.outputs[&1].proxy.id();
        let b = tracker.outputs[&2].proxy.id();
        tracker
            .windows
            .insert(a.clone(), fullscreen_window(a.clone()));
        let mut inactive = fullscreen_window(b.clone());
        inactive
            .pending
            .set_states(&states(&[handle::State::Fullscreen]));
        inactive.done();
        tracker.windows.insert(b, inactive);
        assert!(tracker.hidden_outputs().is_empty());
        tracker.windows.get_mut(&a).unwrap().done();
        assert_eq!(tracker.hidden_outputs(), HashSet::from(["A".to_owned()]));
    }

    #[test]
    fn fullscreen_and_focus_exit_restore_the_bar() {
        let (_connection, _server, mut tracker) = initial();
        let a = tracker.outputs[&1].proxy.id();
        for remaining in [handle::State::Activated, handle::State::Fullscreen] {
            let mut window = fullscreen_window(a.clone());
            window.done();
            tracker.windows.insert(a.clone(), window);
            assert!(tracker.hidden_outputs().contains("A"));
            let window = tracker.windows.get_mut(&a).unwrap();
            window.pending.set_states(&states(&[remaining]));
            window.done();
            assert!(tracker.hidden_outputs().is_empty());
        }
    }

    #[test]
    fn output_moves_are_atomic_and_focus_can_move_between_windows() {
        let (_connection, _server, mut tracker) = initial();
        let a = tracker.outputs[&1].proxy.id();
        let b = tracker.outputs[&2].proxy.id();
        let mut window = fullscreen_window(a.clone());
        window.done();
        tracker.windows.insert(a.clone(), window);
        let window = tracker.windows.get_mut(&a).unwrap();
        window.pending.outputs.remove(&a);
        window.pending.outputs.insert(b.clone());
        assert_eq!(tracker.hidden_outputs(), HashSet::from(["A".to_owned()]));
        tracker.windows.get_mut(&a).unwrap().done();
        assert_eq!(tracker.hidden_outputs(), HashSet::from(["B".to_owned()]));

        let window = tracker.windows.get_mut(&a).unwrap();
        window
            .pending
            .set_states(&states(&[handle::State::Fullscreen]));
        window.done();
        let mut other = fullscreen_window(a);
        other.done();
        tracker.windows.insert(b, other);
        assert_eq!(tracker.hidden_outputs(), HashSet::from(["A".to_owned()]));
    }

    #[test]
    fn closed_removed_and_unknown_outputs_do_not_hide_other_bars() {
        let (_connection, _server, mut tracker) = initial();
        let a = tracker.outputs[&1].proxy.id();
        let mut window = fullscreen_window(a.clone());
        window.done();
        tracker.windows.insert(a.clone(), window);
        tracker.outputs.get_mut(&1).unwrap().name = None;
        assert!(tracker.hidden_outputs().is_empty());
        tracker.outputs.get_mut(&1).unwrap().name = Some("A".to_owned());
        assert!(tracker.hidden_outputs().contains("A"));
        let window = tracker.windows.remove(&a).unwrap();
        assert!(tracker.hidden_outputs().is_empty());
        tracker.windows.insert(a.clone(), window);
        assert!(tracker.hidden_outputs().contains("A"));
        tracker.windows.get_mut(&a).unwrap().pending.outputs.clear();
        tracker.windows.get_mut(&a).unwrap().done();
        assert!(tracker.hidden_outputs().is_empty());
        let window = tracker.windows.get_mut(&a).unwrap();
        window.pending.outputs.insert(a);
        window.done();
        assert!(tracker.hidden_outputs().contains("A"));
        tracker.outputs.remove(&1);
        assert!(tracker.hidden_outputs().is_empty());
        assert!(Tracker::default().hidden_outputs().is_empty());
        assert!(!Fullscreen::default().hidden_on("A"));
    }

    #[test]
    #[ignore = "read-only smoke check against the live Wayland compositor"]
    fn live_protocol() {
        let connection = Connection::connect_to_env().unwrap();
        let mut queue = connection.new_event_queue();
        let _registry = connection.display().get_registry(&queue.handle(), ());
        let mut tracker = Tracker::default();
        // Discover globals, then receive output names and initial toplevel snapshots.
        queue.roundtrip(&mut tracker).unwrap();
        queue.roundtrip(&mut tracker).unwrap();
        assert!(tracker.manager.is_some());
        assert!(!tracker.finished);
        assert!(!tracker.outputs.is_empty());
        assert!(tracker.outputs.values().all(|output| output.name.is_some()));
        eprintln!(
            "{} outputs, {} windows, hidden outputs: {:?}",
            tracker.outputs.len(),
            tracker.windows.len(),
            tracker.hidden_outputs()
        );
    }
}
