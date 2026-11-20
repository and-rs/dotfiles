mod bar_buttons;
mod caffeine;
mod components;
mod control_center;
mod design;
mod fullscreen;
mod minimap;
mod niri;
mod osd;
mod theme;
mod window_title;
mod workspaces;

use std::time::Duration;

use amane::{
    App, Center, Full, Layer, LayerWindow, Monitor, Padding, Parent, Rectangle, Row, Service, Text,
    Vertical, Weight, Widget, Zone, children,
};
use chrono::Local;
use niri::Niri;
use theme::ThemeState;

struct Clock(String);

impl Service for Clock {
    fn new() -> Self {
        Self(Local::now().format("%a %-d %b %H:%M").to_string())
    }

    fn interval() -> Duration {
        Duration::from_secs(1)
    }

    fn update(&mut self) -> bool {
        let time = Self::new().0;
        if self.0 == time {
            return false;
        }
        self.0 = time;
        true
    }
}

fn main() {
    let arguments: Vec<_> = std::env::args().skip(1).collect();
    if let Some((command, rest)) = arguments.split_first() {
        if command != "osd" {
            eprintln!("usage: amane_shell [osd <action>]");
            std::process::exit(1);
        }
        if let Err(error) = osd::client(rest) {
            eprintln!("{error}");
            std::process::exit(1);
        }
        return;
    }
    // Load before opening any windows, so a bad initial config fails clearly.
    drop(ThemeState::read());
    drop(osd::Osd::read());
    App::new()
        .ipc("osd", osd::handle)
        .window_per_monitor(bar)
        .window_per_monitor(osd::view)
        .window_per_monitor(control_center::view)
        .run();
}

fn bar(monitor: &Monitor) -> LayerWindow {
    let window = LayerWindow::new()
        .width(Full)
        .height(design::BAR_HEIGHT)
        .anchor_vertical(Vertical::Top)
        .layer(Layer::Top)
        .space(Zone::Reserve)
        .namespace("amane_shell");
    if fullscreen::Fullscreen::read().hidden_on(&monitor.name) {
        // Keep the exclusive zone, but draw nothing and let pointer input through.
        return window
            .click_through()
            .child(Rectangle::new().width(Parent).height(Parent));
    }

    let state = ThemeState::read();
    let theme = &state.theme;
    let clock = Clock::read();
    let niri = Niri::read();
    let clock_text = |text: &str| {
        Text::new(text)
            .font(&theme.font)
            .size(design::typography::BODY_SIZE)
            .weight(Weight::Medium)
            .color(theme.fg)
    };
    let clock_width = clock_text(design::CLOCK_WIDTH_REFERENCE).width();

    window.child(
        Rectangle::new()
            .width(Parent)
            .height(Parent)
            .fill(theme.bg)
            .padding(Padding {
                left: 4.0,
                right: 12.0,
                top: 0.0,
                bottom: 0.0,
            })
            .child(
                Row::new(children![
                    workspaces::view(&niri, &monitor.name, theme),
                    window_title::view(&niri, &monitor.name, theme),
                    bar_buttons::view(&monitor.name, theme),
                    control_center::button(&monitor.name, theme),
                    Rectangle::new()
                        .width(clock_width)
                        .height(Parent)
                        .align_child(Center, Center)
                        .child(clock_text(&clock.0)),
                ])
                .width(Parent)
                .height(Parent)
                .align(Center)
                .gap(12.0),
            ),
    )
}
