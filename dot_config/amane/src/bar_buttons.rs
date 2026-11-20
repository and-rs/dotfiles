use std::{env, path::PathBuf, process::Command, thread};

use amane::{Button, Center, Padding, Rectangle, Row, Service, Size, Widget, children};

use crate::{
    caffeine::{self, Caffeine},
    components::{Button as UiButton, Variant},
    design,
    theme::Theme,
};

pub fn frame(content: impl Widget + 'static, theme: &Theme) -> Rectangle {
    let Size::Fixed(content_width) = content.width() else {
        unreachable!("bar button content must have a measured width");
    };
    Rectangle::new()
        .width(content_width + design::padding::NORMAL * 2.0)
        .height(design::size::BUTTON)
        .padding(Padding {
            left: design::padding::NORMAL,
            right: design::padding::NORMAL,
            top: 0.0,
            bottom: 0.0,
        })
        .align_child(Center, Center)
        .radius(theme.radius.normal)
        .child(content)
}

pub fn view(monitor: &str, theme: &Theme) -> Rectangle {
    let active = Caffeine::read().active;
    let caffeine_icon = if active { '\u{e220}' } else { '\u{e224}' };
    let icons = Row::new(children![
        UiButton::new(format!("caffeine:{monitor}"), "", theme)
            .variant(Variant::Ghost)
            .selected(active)
            .icon(caffeine_icon)
            .width(design::size::BUTTON)
            .height(design::size::BUTTON)
            .padding(0.0)
            .on_click(|button| {
                if button == Button::Left {
                    caffeine::request_toggle();
                }
            })
            .build(),
        UiButton::new(format!("lock:{monitor}"), "", theme)
            .variant(Variant::Ghost)
            .icon('\u{e308}')
            .width(design::size::BUTTON)
            .height(design::size::BUTTON)
            .padding(0.0)
            .on_click(|button| {
                if button == Button::Left {
                    lock();
                }
            })
            .build(),
    ])
    .align(Center)
    .gap(design::spacing::MEDIUM);
    frame(icons, theme)
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
