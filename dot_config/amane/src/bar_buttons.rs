use std::{env, path::PathBuf, process::Command, thread};

use amane::{Button, Center, Cursor, Rectangle, Row, Service, Text, children};

use crate::{
    caffeine::{self, Caffeine},
    design,
    theme::Theme,
};

pub fn view(theme: &Theme) -> Row {
    let active = Caffeine::read().active;
    let caffeine_icon = if active { '\u{e220}' } else { '\u{e224}' };
    let caffeine_color = if active { theme.accent } else { theme.surface4 };
    Row::new(children![
        Rectangle::new()
            .width(design::size::BUTTON)
            .height(design::size::BUTTON)
            .align_child(Center, Center)
            .cursor(Cursor::Pointer)
            .on_click(|button| {
                if button == Button::Left {
                    caffeine::request_toggle();
                }
            })
            .child(
                Text::new(caffeine_icon.to_string())
                    .font(design::ICON_FONT)
                    .size(design::ICON_SIZE)
                    .color(caffeine_color)
                    .tight(),
            ),
        Rectangle::new()
            .width(design::size::BUTTON)
            .height(design::size::BUTTON)
            .align_child(Center, Center)
            .cursor(Cursor::Pointer)
            .on_click(|button| {
                if button == Button::Left {
                    lock();
                }
            })
            .child(
                Text::new("\u{e308}")
                    .font(design::ICON_FONT)
                    .size(design::ICON_SIZE)
                    .color(theme.surface4)
                    .tight(),
            ),
    ])
    .align(Center)
    .gap(design::spacing::EXTRA_SMALL)
}

fn lock() {
    thread::spawn(|| {
        let config = env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".config")));
        let Some(config) = config else {
            eprintln!("lock: neither XDG_CONFIG_HOME nor HOME is set");
            return;
        };
        // The existing launcher handles duplicate requests and monitor selection.
        match Command::new(config.join("hypr/hyprlock_launch")).status() {
            Ok(status) if status.success() => {}
            Ok(status) => eprintln!("lock: launcher exited with {status}"),
            Err(error) => eprintln!("lock: {error}"),
        }
    });
}
