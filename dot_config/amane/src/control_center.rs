mod backends;
mod battery;
mod bluetooth;
mod indicators;

use amane::{
    Button, Center, Column, Cursor, End, Full, Key, Keyboard, Layer, LayerWindow, Monitor, Padding,
    Parent, Rectangle, Row, ScrollArea, Service, Start, Text, Weight, Zone, children,
};

use crate::{
    bar_buttons,
    design::{self, control_center as layout, padding, spacing},
    theme::{Theme, ThemeState},
};

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
enum Section {
    #[default]
    Tray,
    Bluetooth,
    Wifi,
    Battery,
}

impl Section {
    const ALL: [Self; 4] = [Self::Tray, Self::Bluetooth, Self::Wifi, Self::Battery];

    fn label(self) -> &'static str {
        match self {
            Self::Tray => "Tray",
            Self::Bluetooth => "Bluetooth",
            Self::Wifi => "Wi-Fi",
            Self::Battery => "Battery",
        }
    }
}

#[derive(Default)]
struct ControlCenter {
    monitor: Option<String>,
    section: Section,
}

impl Service for ControlCenter {
    fn new() -> Self {
        Self::default()
    }

    fn listen() {}
}

impl ControlCenter {
    fn open(&mut self, monitor: &str, section: Section) {
        self.monitor = Some(monitor.into());
        self.section = section;
        bluetooth::set_visible(section == Section::Bluetooth);
    }

    fn close(&mut self) {
        self.monitor = None;
        bluetooth::set_visible(false);
    }
}

fn text(value: impl Into<String>, theme: &Theme) -> Text {
    Text::new(value)
        .font(&theme.font)
        .size(theme.font_size * design::BAR_TEXT_SCALE)
        .weight(Weight::Medium)
        .color(theme.fg)
}

pub fn button(monitor: &str, theme: &Theme) -> Rectangle {
    let state = ControlCenter::read();
    let active = state.monitor.as_deref() == Some(monitor);
    let monitor = monitor.to_owned();
    let status = backends::Status::read();
    let charge_opacity = status.charge_opacity.value();
    let icons = Row::new(
        status
            .readings
            .iter()
            .filter_map(|reading| indicators::view(&reading.indicator, theme, charge_opacity))
            .collect(),
    )
    .align(Center)
    .gap(spacing::SMALL);
    let border = if active { theme.accent } else { theme.surface2 };
    bar_buttons::frame(icons, theme)
        .border(design::BORDER_WIDTH, border)
        .cursor(Cursor::Pointer)
        .on_click(move |button| {
            if button != Button::Left {
                return;
            }
            let mut state = ControlCenter::write();
            if state.monitor.as_deref() == Some(&monitor) {
                state.close();
            } else {
                let section = state.section;
                state.open(&monitor, section);
            }
        })
}

pub fn view(monitor: &Monitor) -> LayerWindow {
    let state = ControlCenter::read();
    let theme = ThemeState::read();
    let theme = &theme.theme;
    let visible = state.monitor.as_deref() == Some(&monitor.name);
    let status = backends::Status::read();
    let index = Section::ALL
        .iter()
        .position(|section| *section == state.section)
        .unwrap();
    let message = &status.readings[index].message;
    let width = layout::WIDTH.min((monitor.width as f32 - layout::EDGE * 2.0).max(0.0));
    let height = layout::HEIGHT.min((monitor.height as f32 - layout::TOP - layout::EDGE).max(0.0));
    let content_width = (width - padding::NORMAL * 2.0).max(0.0);
    let tab_width = (content_width - spacing::SMALL * 3.0).max(0.0) / 4.0;
    let tabs = Section::ALL
        .into_iter()
        .map(|section| {
            let name = monitor.name.clone();
            let fill = if state.section == section {
                theme.surface2
            } else {
                theme.surface1
            };
            Box::new(
                Rectangle::new()
                    .width(tab_width)
                    .height(layout::TAB_HEIGHT)
                    .fill(fill)
                    .radius(theme.radius.normal)
                    .align_child(Center, Center)
                    .cursor(Cursor::Pointer)
                    .on_click(move |button| {
                        if button == Button::Left {
                            ControlCenter::write().open(&name, section);
                        }
                    })
                    .child(text(section.label(), theme)),
            ) as Box<dyn amane::Widget>
        })
        .collect();
    let content = match state.section {
        Section::Battery => battery::view(&status.readings[index], theme),
        Section::Bluetooth => bluetooth::view(&status.readings[index], theme),
        _ => Column::new(children![
            text(state.section.label(), theme),
            text(message, theme)
                .wrap()
                .max_lines(layout::PREVIEW_LINES)
                .elide(),
            text("Read-only backend preview", theme),
        ])
        .width(Parent)
        .gap(spacing::SMALL),
    };
    LayerWindow::new()
        .width(Full)
        .height(Full)
        .layer(Layer::Overlay)
        .space(Zone::Ignore)
        .keyboard(Keyboard::Exclusive)
        .namespace("amane_control_center")
        .visible(visible)
        .on_key(|key| {
            if key == Key::Escape {
                ControlCenter::write().close();
            }
        })
        .child(
            Rectangle::new()
                .width(Parent)
                .height(Parent)
                .padding(Padding {
                    top: layout::TOP,
                    right: layout::EDGE,
                    bottom: layout::EDGE,
                    left: layout::EDGE,
                })
                .align_child(End, Start)
                .on_click(|_| ControlCenter::write().close())
                .child(
                    Rectangle::new()
                        .width(width)
                        .height(height)
                        .fill(theme.surface1)
                        .border(design::BORDER_WIDTH, theme.surface4)
                        .radius(theme.radius.normal)
                        .padding(padding::NORMAL)
                        // Consume clicks in empty panel space, not the outside-click handler.
                        .on_click(|_| {})
                        .child(
                            Column::new(children![
                                Row::new(tabs).gap(spacing::SMALL),
                                ScrollArea::new("control_center_content", content,)
                                    .width(content_width)
                                    .height(
                                        (height
                                            - padding::NORMAL * 2.0
                                            - layout::TAB_HEIGHT
                                            - spacing::SMALL)
                                            .max(0.0),
                                    ),
                            ])
                            .width(content_width)
                            .gap(spacing::SMALL),
                        ),
                ),
        )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn opening_on_another_monitor_transfers_ownership() {
        let mut state = ControlCenter::default();
        state.open("one", Section::Wifi);
        state.open("two", Section::Bluetooth);
        assert_eq!(state.monitor.as_deref(), Some("two"));
        assert_eq!(state.section, Section::Bluetooth);
    }

    #[test]
    fn backend_updates_do_not_own_panel_visibility_or_selection() {
        let mut state = ControlCenter::default();
        state.open("one", Section::Wifi);
        state.open("one", Section::Battery);
        state.close();
        assert!(state.monitor.is_none());
        assert_eq!(state.section, Section::Battery);
    }
}
