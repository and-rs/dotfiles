use std::{
    io::Read,
    net::Shutdown,
    os::unix::net::UnixStream,
    process::{Command, Stdio},
    sync::{
        LazyLock, Mutex,
        mpsc::{self, RecvTimeoutError, SyncSender},
    },
    thread,
    time::{Duration, Instant},
};

use amane::{
    Animation, Center, Column, IpcCall, Keyboard, Layer, LayerWindow, Monitor, Parent, Rectangle,
    Row, Service, Start, Text, Weight, Zone, children,
};

use crate::{
    design::{self, duration, osd, spacing},
    theme::ThemeState,
};

const COMMAND_TIMEOUT: Duration = Duration::from_secs(2);

type Update = (Kind, Level);

static UPDATES: LazyLock<(mpsc::Sender<Update>, Mutex<mpsc::Receiver<Update>>)> =
    LazyLock::new(|| {
        let (sender, receiver) = mpsc::channel();
        (sender, Mutex::new(receiver))
    });

#[derive(Clone, Copy, Debug, PartialEq)]
enum Kind {
    Volume,
    Mic,
    Brightness,
    Keyboard,
}

impl Kind {
    fn label(self) -> &'static str {
        match self {
            Self::Volume => "Volume",
            Self::Mic => "Microphone",
            Self::Brightness => "Brightness",
            Self::Keyboard => "Keyboard",
        }
    }

    fn maximum(self) -> f32 {
        if self == Self::Mic {
            return 140.0;
        }
        100.0
    }

    fn icon(self, level: Level) -> char {
        let percent = level.percent.round();
        match self {
            Self::Volume if level.muted => '\u{e456}',
            Self::Volume if percent < 33.0 => '\u{e454}',
            Self::Volume if percent < 66.0 => '\u{e452}',
            Self::Volume => '\u{e450}',
            Self::Mic if level.muted => '\u{e328}',
            Self::Mic => '\u{e326}',
            Self::Brightness | Self::Keyboard if percent < 25.0 => '\u{e330}',
            Self::Brightness | Self::Keyboard if percent < 50.0 => '\u{e58e}',
            Self::Brightness | Self::Keyboard if percent < 75.0 => '\u{e474}',
            Self::Brightness | Self::Keyboard => '\u{e472}',
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
enum Change {
    Up,
    Down,
    Toggle,
}

#[derive(Clone, Copy, Debug, PartialEq)]
struct Action {
    kind: Kind,
    change: Change,
}

impl Action {
    fn parse(arguments: &[String]) -> Result<Self, String> {
        let [argument] = arguments else {
            return Err("expected one OSD action".into());
        };
        let (kind, change) = match argument.as_str() {
            "volume_up" => (Kind::Volume, Change::Up),
            "volume_down" => (Kind::Volume, Change::Down),
            "volume_mute" => (Kind::Volume, Change::Toggle),
            "mic_up" => (Kind::Mic, Change::Up),
            "mic_down" => (Kind::Mic, Change::Down),
            "mic_mute" => (Kind::Mic, Change::Toggle),
            "brightness_up" => (Kind::Brightness, Change::Up),
            "brightness_down" => (Kind::Brightness, Change::Down),
            "keyboard_up" => (Kind::Keyboard, Change::Up),
            "keyboard_down" => (Kind::Keyboard, Change::Down),
            _ => return Err(format!("unknown OSD action: {argument}")),
        };
        Ok(Self { kind, change })
    }

    fn execute(
        self,
        mut run: impl FnMut(&str, &[&str]) -> Result<String, String>,
    ) -> Result<Level, String> {
        match self.kind {
            Kind::Volume | Kind::Mic => {
                let (device, step, limit) = match self.kind {
                    Kind::Mic => ("@DEFAULT_SOURCE@", "10%", "1.4"),
                    _ => ("@DEFAULT_SINK@", "5%", "1.0"),
                };
                match self.change {
                    Change::Toggle => {
                        run("wpctl", &["set-mute", device, "toggle"])?;
                    }
                    change => {
                        let suffix = match change {
                            Change::Up => "+",
                            _ => "-",
                        };
                        run(
                            "wpctl",
                            &[
                                "set-volume",
                                device,
                                &format!("{step}{suffix}"),
                                "-l",
                                limit,
                            ],
                        )?;
                    }
                }
                parse_audio(&run("wpctl", &["get-volume", device])?)
            }
            Kind::Brightness | Kind::Keyboard => {
                let mut arguments = Vec::new();
                if self.kind == Kind::Keyboard {
                    arguments.extend(["-d", "asus::kbd_backlight"]);
                } else {
                    arguments.extend(["-c", "backlight"]);
                }
                let step = match (self.kind, self.change) {
                    (Kind::Keyboard, Change::Up) => "+33%",
                    (Kind::Keyboard, _) => "33%-",
                    (_, Change::Up) => "+5%",
                    _ => "5%-",
                };
                let mut set = arguments.clone();
                set.extend(["set", step, "-q"]);
                run("brightnessctl", &set)?;
                arguments.push("-m");
                parse_brightness(&run("brightnessctl", &arguments)?)
            }
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
struct Level {
    percent: f32,
    muted: bool,
}

fn parse_audio(output: &str) -> Result<Level, String> {
    let parts: Vec<_> = output.split_whitespace().collect();
    if parts.first() != Some(&"Volume:")
        || !(parts.len() == 2 || (parts.len() == 3 && parts[2] == "[MUTED]"))
    {
        return Err(format!("invalid wpctl output: {output:?}"));
    }
    let percent = parts[1].parse::<f32>().map_err(|error| error.to_string())? * 100.0;
    if !percent.is_finite() || percent < 0.0 {
        return Err("invalid audio level".into());
    }
    Ok(Level {
        percent,
        muted: parts.len() == 3,
    })
}

fn parse_brightness(output: &str) -> Result<Level, String> {
    let fields: Vec<_> = output.trim().split(',').collect();
    let invalid = || format!("invalid brightnessctl output: {output:?}");
    if fields.len() != 5 {
        return Err(invalid());
    }
    let current = fields[2].parse::<u32>().map_err(|_| invalid())?;
    let maximum = fields[4].parse::<u32>().map_err(|_| invalid())?;
    if maximum == 0 || current > maximum {
        return Err(invalid());
    }
    Ok(Level {
        percent: current as f32 / maximum as f32 * 100.0,
        muted: false,
    })
}

fn run(program: &str, arguments: &[&str]) -> Result<String, String> {
    let mut child = Command::new(program)
        .args(arguments)
        .env("LC_ALL", "C")
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|error| format!("{program}: {error}"))?;
    let deadline = Instant::now() + COMMAND_TIMEOUT;
    loop {
        match child.try_wait() {
            Ok(Some(status)) => {
                if !status.success() {
                    return Err(format!("{program} exited with {status}"));
                }
                let mut output = String::new();
                child
                    .stdout
                    .take()
                    .expect("piped stdout")
                    .read_to_string(&mut output)
                    .map_err(|error| error.to_string())?;
                return Ok(output);
            }
            Ok(None) if Instant::now() < deadline => thread::sleep(Duration::from_millis(10)),
            result => {
                let _ = child.kill();
                let _ = child.wait();
                return Err(format!(
                    "{program} timed out or could not be waited for: {result:?}"
                ));
            }
        }
    }
}

pub struct Osd {
    current: Option<(Kind, Level, Instant)>,
    progress: Animation,
}

impl Default for Osd {
    fn default() -> Self {
        Self {
            current: None,
            progress: Animation::new(0.0).duration(duration::EXTRA_FAST),
        }
    }
}

impl Osd {
    fn show(&mut self, kind: Kind, level: Level, now: Instant) {
        let progress = (level.percent / kind.maximum()).clamp(0.0, 1.0);
        if self.current.is_none_or(|(current, _, _)| current != kind) {
            self.progress = Animation::new(progress).duration(duration::EXTRA_FAST);
        } else {
            self.progress.to(progress);
        }
        self.current = Some((kind, level, now + duration::SLOW));
    }

    fn expire(&mut self, now: Instant) {
        if self.current.is_some_and(|(_, _, deadline)| now >= deadline) {
            self.current = None;
        }
    }
}

impl Service for Osd {
    fn new() -> Self {
        Self::default()
    }

    fn listen() {
        let receiver = UPDATES.1.lock().expect("OSD update receiver poisoned");
        loop {
            let deadline = Self::read().current.map(|(_, _, deadline)| deadline);
            let next = match deadline {
                Some(deadline) => {
                    receiver.recv_timeout(deadline.saturating_duration_since(Instant::now()))
                }
                None => receiver.recv().map_err(|_| RecvTimeoutError::Disconnected),
            };
            match next {
                Ok((kind, level)) => Self::write().show(kind, level, Instant::now()),
                Err(RecvTimeoutError::Timeout) => Self::write().expire(Instant::now()),
                Err(RecvTimeoutError::Disconnected) => return,
            }
        }
    }
}

static ACTIONS: LazyLock<SyncSender<Action>> = LazyLock::new(|| {
    let (sender, receiver) = mpsc::sync_channel::<Action>(64);
    thread::spawn(move || {
        for action in receiver {
            match action.execute(run) {
                Ok(level) => {
                    if UPDATES.0.send((action.kind, level)).is_err() {
                        return;
                    }
                }
                Err(error) => eprintln!("OSD {}: {error}", action.kind.label()),
            }
        }
    });
    sender
});

pub fn handle(arguments: &[String]) -> String {
    match Action::parse(arguments)
        .and_then(|action| ACTIONS.try_send(action).map_err(|error| error.to_string()))
    {
        Ok(()) => "ok\n".into(),
        Err(error) => format!("error: {error}\n"),
    }
}

pub fn client(arguments: &[String]) -> Result<(), String> {
    Action::parse(arguments)?;
    let mut stream = UnixStream::connect(amane::ipc_socket())
        .map_err(|error| format!("cannot reach Amane: {error}"))?;
    stream
        .set_read_timeout(Some(COMMAND_TIMEOUT))
        .map_err(|error| error.to_string())?;
    stream
        .set_write_timeout(Some(COMMAND_TIMEOUT))
        .map_err(|error| error.to_string())?;
    IpcCall::new("osd", arguments)
        .write(&mut stream)
        .map_err(|error| error.to_string())?;
    stream
        .shutdown(Shutdown::Write)
        .map_err(|error| error.to_string())?;
    let mut reply = String::new();
    stream
        .read_to_string(&mut reply)
        .map_err(|error| error.to_string())?;
    if reply.trim() != "ok" {
        return Err(format!("Amane rejected OSD action: {}", reply.trim()));
    }
    Ok(())
}

pub fn view(_monitor: &Monitor) -> LayerWindow {
    let state = Osd::read();
    let theme = ThemeState::read();
    let theme = &theme.theme;
    let (kind, level) = state
        .current
        .map(|(kind, level, _)| (kind, level))
        .unwrap_or((
            Kind::Volume,
            Level {
                percent: 0.0,
                muted: false,
            },
        ));
    let mut text = format!("{}: {:.0}%", kind.label(), level.percent);
    let mut foreground = theme.fg;
    let mut progress = theme.accent;
    if level.muted {
        text = format!("{}: Muted", kind.label());
        foreground = theme.surface2;
        progress = foreground;
    }
    LayerWindow::new()
        .width(osd::WIDTH)
        .height(osd::HEIGHT)
        .layer(Layer::Overlay)
        .space(Zone::Ignore)
        .keyboard(Keyboard::None)
        .click_through()
        .namespace("amane_osd")
        .visible(state.current.is_some())
        .child(
            Rectangle::new()
                .width(Parent)
                .height(Parent)
                .fill(theme.surface1)
                .border(design::BORDER_WIDTH, theme.surface4)
                .radius(theme.radius.normal)
                .padding(osd::PADDING)
                .align_child(Center, Center)
                .child(
                    Column::new(children![
                        Row::new(children![
                            Text::new(kind.icon(level).to_string())
                                .font(design::ICON_FONT)
                                .size(design::ICON_SIZE)
                                .color(foreground)
                                .tight(),
                            Text::new(text)
                                .font(&theme.font)
                                .size(design::typography::BODY_SIZE)
                                .weight(Weight::Medium)
                                .color(foreground),
                        ])
                        .gap(spacing::SMALL)
                        .align(Center),
                        Rectangle::new()
                            .width(osd::CONTENT_WIDTH)
                            .height(spacing::SMALL)
                            .fill(theme.bg)
                            .radius(theme.radius.large)
                            .align_child(Start, Start)
                            .child(
                                Rectangle::new()
                                    .width(osd::CONTENT_WIDTH * state.progress.value())
                                    .height(spacing::SMALL)
                                    .fill(progress)
                                    .radius(theme.radius.large)
                            ),
                    ])
                    .gap(spacing::SMALL),
                ),
        )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn action(name: &str) -> Action {
        Action::parse(&[name.into()]).unwrap()
    }

    #[test]
    fn icons_follow_level_thresholds_and_mute_state() {
        for (kind, percent, expected) in [
            (Kind::Volume, 0.0, '\u{e454}'),
            (Kind::Volume, 32.0, '\u{e454}'),
            (Kind::Volume, 32.5, '\u{e452}'),
            (Kind::Volume, 33.0, '\u{e452}'),
            (Kind::Volume, 65.0, '\u{e452}'),
            (Kind::Volume, 66.0, '\u{e450}'),
            (Kind::Volume, 100.0, '\u{e450}'),
            (Kind::Mic, 140.0, '\u{e326}'),
        ] {
            assert_eq!(
                kind.icon(Level {
                    percent,
                    muted: false
                }),
                expected
            );
        }
        for kind in [Kind::Brightness, Kind::Keyboard] {
            for (percent, expected) in [
                (0.0, '\u{e330}'),
                (24.0, '\u{e330}'),
                (25.0, '\u{e58e}'),
                (49.0, '\u{e58e}'),
                (50.0, '\u{e474}'),
                (74.0, '\u{e474}'),
                (75.0, '\u{e472}'),
                (100.0, '\u{e472}'),
            ] {
                assert_eq!(
                    kind.icon(Level {
                        percent,
                        muted: false
                    }),
                    expected
                );
            }
        }
        let muted = Level {
            percent: 50.0,
            muted: true,
        };
        assert_eq!(Kind::Volume.icon(muted), '\u{e456}');
        assert_eq!(Kind::Mic.icon(muted), '\u{e328}');
    }

    #[test]
    fn progress_uses_each_kind_limit_and_resets_between_modes() {
        let mut state = Osd::default();
        let now = Instant::now();
        state.show(
            Kind::Volume,
            Level {
                percent: 50.0,
                muted: false,
            },
            now,
        );
        assert_eq!(state.progress.value(), 0.5);
        state.show(
            Kind::Mic,
            Level {
                percent: 140.0,
                muted: false,
            },
            now,
        );
        assert_eq!(state.progress.value(), 1.0);
        state.expire(now + duration::SLOW);
        state.show(
            Kind::Mic,
            Level {
                percent: 70.0,
                muted: false,
            },
            now + duration::SLOW,
        );
        assert_eq!(state.progress.value(), 0.5);
        state.show(
            Kind::Brightness,
            Level {
                percent: 150.0,
                muted: false,
            },
            now,
        );
        assert_eq!(state.progress.value(), 1.0);
    }

    #[test]
    fn rejects_unknown_actions_and_extra_arguments() {
        for arguments in [
            vec![],
            vec!["brightness_mute".into()],
            vec!["volume_up".into(), "extra".into()],
        ] {
            assert!(Action::parse(&arguments).is_err());
        }
    }

    #[test]
    fn reads_real_levels_and_rejects_invalid_output() {
        assert_eq!(
            parse_audio("Volume: 1.40 [MUTED]\n").unwrap(),
            Level {
                percent: 140.0,
                muted: true
            }
        );
        assert_eq!(
            parse_brightness("asus::kbd_backlight,leds,1,33%,3\n")
                .unwrap()
                .percent
                .round(),
            33.0
        );
        for output in ["", "Volume: NaN", "Volume: -1", "Volume: 0.5 junk"] {
            assert!(parse_audio(output).is_err());
        }
        for output in ["", "dev,backlight,1,0%,0", "dev,backlight,4,100%,3"] {
            assert!(parse_brightness(output).is_err());
        }
    }

    #[test]
    fn commands_preserve_steps_limits_and_device_selection() {
        for (name, expected) in [
            (
                "volume_up",
                vec!["set-volume", "@DEFAULT_SINK@", "5%+", "-l", "1.0"],
            ),
            (
                "volume_down",
                vec!["set-volume", "@DEFAULT_SINK@", "5%-", "-l", "1.0"],
            ),
            (
                "mic_up",
                vec!["set-volume", "@DEFAULT_SOURCE@", "10%+", "-l", "1.4"],
            ),
            (
                "mic_down",
                vec!["set-volume", "@DEFAULT_SOURCE@", "10%-", "-l", "1.4"],
            ),
            ("volume_mute", vec!["set-mute", "@DEFAULT_SINK@", "toggle"]),
            ("mic_mute", vec!["set-mute", "@DEFAULT_SOURCE@", "toggle"]),
            ("brightness_up", vec!["-c", "backlight", "set", "+5%", "-q"]),
            (
                "brightness_down",
                vec!["-c", "backlight", "set", "5%-", "-q"],
            ),
            (
                "keyboard_up",
                vec!["-d", "asus::kbd_backlight", "set", "+33%", "-q"],
            ),
            (
                "keyboard_down",
                vec!["-d", "asus::kbd_backlight", "set", "33%-", "-q"],
            ),
        ] {
            let mut calls = Vec::new();
            action(name)
                .execute(|program, arguments| {
                    calls.push((
                        program.to_string(),
                        arguments
                            .iter()
                            .map(|arg| arg.to_string())
                            .collect::<Vec<_>>(),
                    ));
                    if program == "wpctl" {
                        return Ok("Volume: 0.50".into());
                    }
                    Ok("device,backlight,50,50%,100".into())
                })
                .unwrap();
            assert_eq!(calls.len(), 2);
            assert_eq!(calls[0].1, expected);
        }
    }

    #[test]
    fn failure_does_not_read_or_publish_a_level() {
        let mut calls = 0;
        assert!(
            action("volume_up")
                .execute(|_, _| {
                    calls += 1;
                    Err("device unavailable".into())
                })
                .is_err()
        );
        assert_eq!(calls, 1);
    }

    #[test]
    fn process_runner_checks_output_failure_and_timeout() {
        assert_eq!(run("printf", &["hello"]).unwrap(), "hello");
        assert!(run("false", &[]).is_err());
        assert!(run("/nonexistent/amane_osd_command", &[]).is_err());
        let started = Instant::now();
        assert!(run("sleep", &["10"]).unwrap_err().contains("timed out"));
        assert!(started.elapsed() < COMMAND_TIMEOUT + Duration::from_secs(2));
    }

    #[test]
    fn new_action_replaces_content_and_extends_deadline() {
        let mut state = Osd::default();
        let now = Instant::now();
        let level = Level {
            percent: 50.0,
            muted: false,
        };
        state.show(Kind::Volume, level, now);
        let next = now + duration::SLOW / 2;
        state.show(Kind::Mic, level, next);
        state.expire(now + duration::SLOW);
        assert_eq!(
            state.current,
            Some((Kind::Mic, level, next + duration::SLOW))
        );
        state.expire(next + duration::SLOW);
        assert_eq!(state.current, None);
    }
}
