use std::{
    io::{self, BufRead, BufReader, Write},
    os::unix::net::UnixStream,
    thread,
    time::Duration,
};

use amane::Service;
use niri_ipc::{
    Action, Event, Reply, Request, Response, Window, Workspace, WorkspaceReferenceArg,
    state::{EventStreamStatePart, WindowsState, WorkspacesState},
};

const COMMAND_TIMEOUT: Duration = Duration::from_secs(2);

#[derive(Default)]
pub struct Niri {
    workspaces: WorkspacesState,
    windows: WindowsState,
    received_workspaces: bool,
    received_windows: bool,
}

impl Niri {
    pub fn ready(&self) -> bool {
        self.received_workspaces && self.received_windows
    }

    pub fn workspaces_on(&self, output: &str) -> Vec<&Workspace> {
        if !self.ready() {
            return Vec::new();
        }
        let mut workspaces: Vec<_> = self
            .workspaces
            .workspaces
            .values()
            .filter(|workspace| workspace.output.as_deref() == Some(output))
            .collect();
        workspaces.sort_by_key(|workspace| (workspace.idx, workspace.id));
        workspaces
    }

    pub fn windows_on(&self, workspace_id: u64) -> impl Iterator<Item = &Window> {
        self.windows
            .windows
            .values()
            .filter(move |window| window.workspace_id == Some(workspace_id))
    }

    pub fn active_window(&self, output: &str) -> Option<&Window> {
        let workspace = self
            .workspaces_on(output)
            .into_iter()
            .find(|workspace| workspace.is_active)?;
        let window = self.windows.windows.get(&workspace.active_window_id?)?;
        // Related events can briefly refer to a window that has already moved.
        if window.workspace_id != Some(workspace.id) {
            return None;
        }
        Some(window)
    }

    fn apply(&mut self, event: Event) {
        match &event {
            Event::WorkspacesChanged { .. } => self.received_workspaces = true,
            Event::WindowsChanged { .. } => self.received_windows = true,
            _ => {}
        }
        if let Some(event) = self.workspaces.apply(event) {
            let _ = self.windows.apply(event);
        }
    }
}

fn relevant(event: &Event) -> bool {
    matches!(
        event,
        Event::WorkspacesChanged { .. }
            | Event::WorkspaceActivated { .. }
            | Event::WorkspaceUrgencyChanged { .. }
            | Event::WorkspaceActiveWindowChanged { .. }
            | Event::WindowsChanged { .. }
            | Event::WindowOpenedOrChanged { .. }
            | Event::WindowClosed { .. }
            | Event::WindowFocusChanged { .. }
            | Event::WindowLayoutsChanged { .. }
    )
}

fn connect() -> io::Result<BufReader<UnixStream>> {
    let path = std::env::var_os(niri_ipc::socket::SOCKET_PATH_ENV)
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "NIRI_SOCKET is not set"))?;
    let stream = UnixStream::connect(path)?;
    stream.set_read_timeout(Some(COMMAND_TIMEOUT))?;
    stream.set_write_timeout(Some(COMMAND_TIMEOUT))?;
    Ok(BufReader::new(stream))
}

fn request(stream: &mut BufReader<UnixStream>, request: Request) -> io::Result<()> {
    serde_json::to_writer(stream.get_mut(), &request)?;
    stream.get_mut().write_all(b"\n")?;
    let mut line = String::new();
    if stream.read_line(&mut line)? == 0 {
        return Err(io::Error::new(
            io::ErrorKind::UnexpectedEof,
            "niri disconnected",
        ));
    }
    match serde_json::from_str::<Reply>(&line)? {
        Ok(Response::Handled) => Ok(()),
        Ok(response) => Err(io::Error::other(format!(
            "unexpected niri reply: {response:?}"
        ))),
        Err(error) => Err(io::Error::other(error)),
    }
}

fn follow() -> io::Result<()> {
    let mut stream = connect()?;
    request(&mut stream, Request::EventStream)?;
    stream.get_mut().set_read_timeout(None)?;
    eprintln!("niri connected");
    for line in stream.lines() {
        let event: Event = serde_json::from_str(&line?)?;
        if relevant(&event) {
            Niri::write().apply(event);
        }
    }
    Err(io::Error::new(
        io::ErrorKind::UnexpectedEof,
        "niri disconnected",
    ))
}

impl Service for Niri {
    fn new() -> Self {
        Self::default()
    }

    fn listen() {
        loop {
            if let Err(error) = follow() {
                *Self::write() = Self::default();
                eprintln!("niri unavailable: {error}; retrying in 2 seconds");
            }
            thread::sleep(Duration::from_secs(2));
        }
    }
}

pub fn focus_workspace(id: u64) {
    // Commands use their own sockets and never wait on the rendering thread.
    thread::spawn(move || {
        let result = connect().and_then(|mut stream| {
            request(
                &mut stream,
                Request::Action(Action::FocusWorkspace {
                    reference: WorkspaceReferenceArg::Id(id),
                }),
            )
        });
        if let Err(error) = result {
            eprintln!("failed to focus workspace {id}: {error}");
        }
    });
}

#[cfg(test)]
pub(crate) mod tests {
    use super::*;

    pub fn workspace(id: u64, idx: u8, output: &str, active: bool) -> Workspace {
        serde_json::from_value(serde_json::json!({
            "id": id, "idx": idx, "name": null, "output": output,
            "is_urgent": false, "is_active": active, "is_focused": active,
            "active_window_id": null
        }))
        .unwrap()
    }

    pub fn window(id: u64, workspace_id: u64, column: usize, row: usize) -> Window {
        serde_json::from_value(serde_json::json!({
            "id": id, "title": format!("window {id}"), "app_id": "test", "pid": null,
            "workspace_id": workspace_id, "is_focused": false, "is_floating": false,
            "is_urgent": false, "focus_timestamp": null,
            "layout": {
                "pos_in_scrolling_layout": [column, row], "tile_size": [800.0, 600.0],
                "window_size": [800, 600], "tile_pos_in_workspace_view": null,
                "window_offset_in_tile": [0.0, 0.0]
            }
        }))
        .unwrap()
    }

    fn initial() -> Niri {
        let mut state = Niri::default();
        state.apply(Event::WorkspacesChanged {
            workspaces: vec![
                workspace(10, 2, "A", false),
                workspace(20, 1, "B", true),
                workspace(30, 1, "A", true),
            ],
        });
        assert!(!state.ready());
        state.apply(Event::WindowsChanged {
            windows: vec![window(1, 30, 1, 1), window(2, 20, 1, 1)],
        });
        state
    }

    #[test]
    fn snapshots_are_filtered_and_sorted_per_output() {
        let state = initial();
        assert!(state.ready());
        let ids: Vec<_> = state.workspaces_on("A").iter().map(|ws| ws.id).collect();
        assert_eq!(ids, [30, 10]);
        assert_eq!(state.windows_on(30).count(), 1);
    }

    #[test]
    fn active_per_output_is_not_global_focus() {
        let mut state = initial();
        state.apply(Event::WorkspaceActivated {
            id: 10,
            focused: true,
        });
        assert!(state.workspaces.workspaces[&10].is_focused);
        assert!(!state.workspaces.workspaces[&20].is_focused);
        assert!(state.workspaces.workspaces[&20].is_active);
        state.apply(Event::WorkspaceActivated {
            id: 30,
            focused: false,
        });
        assert!(state.workspaces.workspaces[&30].is_active);
        assert!(state.workspaces.workspaces[&10].is_focused);
        state.apply(Event::WindowFocusChanged { id: Some(1) });
        assert!(state.windows.windows[&1].is_focused);
        state.apply(Event::WindowFocusChanged { id: Some(2) });
        assert!(!state.windows.windows[&1].is_focused);
        state.apply(Event::WindowFocusChanged { id: None });
        assert!(state.windows.windows.values().all(|win| !win.is_focused));
    }

    #[test]
    fn tolerates_cross_event_references_and_tracks_window_changes() {
        let mut state = initial();
        state.apply(Event::WorkspaceActiveWindowChanged {
            workspace_id: 30,
            active_window_id: Some(3),
        });
        assert!(state.active_window("A").is_none());
        let mut win = window(3, 30, 2, 1);
        state.apply(Event::WindowOpenedOrChanged {
            window: win.clone(),
        });
        assert_eq!(state.active_window("A").unwrap().id, 3);
        win.title = Some("renamed".into());
        state.apply(Event::WindowOpenedOrChanged {
            window: win.clone(),
        });
        assert_eq!(
            state.active_window("A").unwrap().title.as_deref(),
            Some("renamed")
        );
        win.workspace_id = Some(20);
        state.apply(Event::WindowOpenedOrChanged { window: win });
        assert!(state.active_window("A").is_none());
        assert_eq!(state.windows_on(20).count(), 2);
        state.apply(Event::WindowClosed { id: 3 });
        assert_eq!(state.windows_on(20).count(), 1);
    }

    #[test]
    fn snapshots_replace_old_state_and_reconnect_starts_empty() {
        let mut state = initial();
        state.apply(Event::WorkspacesChanged {
            workspaces: vec![workspace(30, 4, "B", true)],
        });
        assert!(state.workspaces_on("A").is_empty());
        assert_eq!(state.workspaces_on("B")[0].idx, 4);
        state.apply(Event::WindowsChanged {
            windows: Vec::new(),
        });
        assert_eq!(state.windows_on(30).count(), 0);
        state = Niri::default();
        assert!(!state.ready());
        assert!(state.workspaces_on("B").is_empty());
        state.apply(Event::WindowsChanged {
            windows: vec![window(9, 40, 1, 1)],
        });
        assert!(!state.ready());
        state.apply(Event::WorkspacesChanged {
            workspaces: vec![workspace(40, 1, "A", true)],
        });
        assert_eq!(state.windows_on(40).count(), 1);
    }

    #[test]
    fn urgency_and_layout_updates_are_applied() {
        let mut state = initial();
        state.apply(Event::WorkspaceUrgencyChanged {
            id: 30,
            urgent: true,
        });
        assert!(state.workspaces.workspaces[&30].is_urgent);
        let mut layout = window(1, 30, 2, 2).layout;
        layout.tile_size = (400.0, 300.0);
        state.apply(Event::WindowLayoutsChanged {
            changes: vec![(1, layout.clone())],
        });
        assert_eq!(state.windows.windows[&1].layout, layout);
        assert!(!relevant(&Event::OverviewOpenedOrClosed { is_open: true }));
    }

    #[test]
    fn commands_use_ids_and_check_the_reply() {
        let (client, server) = UnixStream::pair().unwrap();
        let server = thread::spawn(move || {
            let mut server = BufReader::new(server);
            let mut line = String::new();
            server.read_line(&mut line).unwrap();
            let request: Request = serde_json::from_str(&line).unwrap();
            assert!(matches!(
                request,
                Request::Action(Action::FocusWorkspace {
                    reference: WorkspaceReferenceArg::Id(30),
                })
            ));
            server
                .get_mut()
                .write_all(b"{\"Err\":\"missing workspace\"}\n")
                .unwrap();
        });
        let error = request(
            &mut BufReader::new(client),
            Request::Action(Action::FocusWorkspace {
                reference: WorkspaceReferenceArg::Id(30),
            }),
        )
        .unwrap_err();
        assert!(error.to_string().contains("missing workspace"));
        server.join().unwrap();
    }

    #[test]
    fn accepts_handled_replies_and_preserves_buffered_events() {
        let (client, server) = UnixStream::pair().unwrap();
        let server = thread::spawn(move || {
            let mut server = BufReader::new(server);
            let mut line = String::new();
            server.read_line(&mut line).unwrap();
            assert!(matches!(
                serde_json::from_str::<Request>(&line).unwrap(),
                Request::EventStream
            ));
            server
                .get_mut()
                .write_all(b"{\"Ok\":\"Handled\"}\n{\"WindowFocusChanged\":{\"id\":null}}\n")
                .unwrap();
        });
        let mut client = BufReader::new(client);
        request(&mut client, Request::EventStream).unwrap();
        let mut line = String::new();
        client.read_line(&mut line).unwrap();
        assert!(matches!(
            serde_json::from_str::<Event>(&line).unwrap(),
            Event::WindowFocusChanged { id: None }
        ));
        server.join().unwrap();
    }

    #[test]
    fn unresponsive_commands_time_out() {
        let (client, _server) = UnixStream::pair().unwrap();
        client
            .set_read_timeout(Some(Duration::from_millis(50)))
            .unwrap();
        let error = request(&mut BufReader::new(client), Request::EventStream).unwrap_err();
        assert!(matches!(
            error.kind(),
            io::ErrorKind::WouldBlock | io::ErrorKind::TimedOut
        ));
    }
}
