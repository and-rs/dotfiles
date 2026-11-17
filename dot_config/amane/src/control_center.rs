mod battery;
mod bluetooth;
mod dbus;
mod tray;
mod ui;
mod wifi;

use amane::{
    Button, Center, Column, Cursor, End, Full, Key, Keyboard, Layer, LayerWindow, Monitor, Padding,
    Parent, Rectangle, Row, ScrollArea, Service, Size, Start, Widget, Zone,
};

use crate::{
    bar_buttons,
    design::{self, control_center as layout, padding, spacing},
    theme::{Theme, ThemeState},
};
use ui::text;

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

    fn set_active(self, active: bool) {
        if self == Self::Bluetooth {
            bluetooth::set_active(active);
        }
    }

    fn content(self, theme: &Theme, width: f32, height: f32) -> Box<dyn Widget> {
        let content = match self {
            Self::Tray => tray::view(theme),
            Self::Bluetooth => return Box::new(bluetooth::view(theme, width, height)),
            Self::Wifi => return Box::new(wifi::view(theme, width)),
            Self::Battery => return Box::new(battery::view(theme, width)),
        };
        Box::new(
            ScrollArea::new("control_center_content", content)
                .width(width)
                .height(height),
        )
    }

    fn indicator(self, theme: &Theme) -> Option<Box<dyn Widget>> {
        match self {
            Self::Tray => Some(Box::new(tray::indicator(theme))),
            Self::Bluetooth => Some(Box::new(bluetooth::indicator(theme))),
            Self::Wifi => Some(Box::new(wifi::indicator(theme))),
            Self::Battery => {
                battery::indicator(theme).map(|view| Box::new(view) as Box<dyn Widget>)
            }
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
        if self.monitor.is_some() && self.section != section {
            self.section.set_active(false);
        }
        self.monitor = Some(monitor.into());
        self.section = section;
        self.section.set_active(true);
    }

    fn close(&mut self) {
        self.monitor = None;
        self.section.set_active(false);
    }
}

pub fn button(monitor: &str, theme: &Theme) -> Rectangle {
    let state = ControlCenter::read();
    let active = state.monitor.as_deref() == Some(monitor);
    let monitor = monitor.to_owned();
    let icons = Section::ALL
        .into_iter()
        .filter_map(|section| section.indicator(theme))
        .collect();
    let icons = Row::new(icons).align(Center).gap(spacing::SMALL);
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
    let width = layout::WIDTH.min((monitor.width as f32 - layout::EDGE * 2.0).max(0.0));
    let preferred_height = match state.section {
        Section::Bluetooth => design::bluetooth::HEIGHT,
        _ => layout::HEIGHT,
    };
    let height =
        preferred_height.min((monitor.height as f32 - layout::TOP - layout::EDGE).max(0.0));
    let content_width = (width - padding::NORMAL * 2.0).max(0.0);
    let tab_count = Section::ALL.len() as f32;
    let tab_width = (content_width - spacing::SMALL * (tab_count - 1.0)).max(0.0) / tab_count;
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
    let content_height =
        (height - padding::NORMAL * 2.0 - layout::TAB_HEIGHT - spacing::SMALL).max(0.0);
    let content = state.section.content(theme, content_width, content_height);
    let height = match content.height() {
        Size::Fixed(content_height) => {
            content_height + padding::NORMAL * 2.0 + layout::TAB_HEIGHT + spacing::SMALL
        }
        Size::Parent => height,
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
                            Column::new(vec![
                                Box::new(Row::new(tabs).gap(spacing::SMALL)),
                                content,
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
