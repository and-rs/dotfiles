use std::{
    cell::RefCell,
    collections::HashMap,
    ops::Range,
    sync::{Arc, Weak},
    time::Instant,
};

use amane::{
    Button, Center, Column, End, Full, Horizontal, Image, Key, Keyboard, Layer, LayerWindow,
    Margin, Monitor, Parent, Rectangle, Row, Service, Size, Start, Text, TextInput, Vertical,
    Widget, Zone, children,
};

use super::{Entry, Notice, Notifications};
use crate::{
    components::{
        Button as UiButton, Variant, button::icon_glyph, scroll_area::anchored_scroll_area,
    },
    design::{self, notifications as layout, padding, spacing, typography},
    niri::Niri,
    theme::{Theme, ThemeState},
};

const REPLY_FIELD: &str = "notification_reply";

pub fn bell(monitor: &str, theme: &Theme) -> Rectangle {
    let state = Notifications::read();
    let count = state
        .entries
        .iter()
        .filter(|entry| entry.undo_until.is_none() && !entry.notice.transient)
        .count();
    let selected = state.monitor.as_deref() == Some(monitor);
    drop(state);
    bell_button(monitor, theme, count, selected)
}

fn bell_button(monitor: &str, theme: &Theme, count: usize, selected: bool) -> Rectangle {
    let monitor = monitor.to_owned();
    let glyph = '\u{e0ce}';
    let mut button = UiButton::icon_only(format!("notifications:{monitor}"), glyph, theme);
    if count > 0 {
        let value = if count > 99 {
            "99+".into()
        } else {
            count.to_string()
        };
        let label = text(value, theme)
            .color(theme.accent)
            .weight(typography::BODY_WEIGHT);
        let Size::Fixed(label_width) = label.width() else {
            unreachable!("an unwrapped count has an intrinsic width");
        };
        let content = Row::new(children![
            Rectangle::new()
                .width(label_width.ceil() + design::BORDER_WIDTH + spacing::TINY)
                .height(design::size::BUTTON)
                .align_child(End, Center)
                .child(label),
            icon_glyph(glyph, theme.fg, design::size::BUTTON),
        ])
        .align(Center);
        button = button.width(Widget::width(&content)).content(content);
    }
    button
        .selected(selected)
        .on_click(move |button| {
            if button == Button::Left {
                TextInput::set_text(REPLY_FIELD, "");
                let mut state = Notifications::write();
                state.reply_to = None;
                state.monitor =
                    (state.monitor.as_deref() != Some(&monitor)).then(|| monitor.clone());
            }
        })
        .build()
}

fn text(value: impl Into<String>, theme: &Theme) -> Text {
    Text::new(value)
        .font(&theme.font)
        .size(typography::BODY_SIZE)
        .color(theme.fg)
}

fn height(widget: &impl Widget) -> f32 {
    match widget.height() {
        Size::Fixed(value) => value,
        Size::Parent => unreachable!("notification content must have intrinsic height"),
    }
}

fn action(
    key: String,
    label: &str,
    variant: Variant,
    theme: &Theme,
    on_click: impl Fn() + 'static,
) -> Rectangle {
    UiButton::new(key, label, theme)
        .variant(variant)
        .width(Parent)
        .height(layout::ACTION_HEIGHT)
        .padding(layout::ACTION_PADDING)
        .on_click(move |button| {
            if button == Button::Left {
                on_click();
            }
        })
        .build()
}

fn close_button(key: String, theme: &Theme, close: impl Fn() + 'static) -> Rectangle {
    UiButton::icon_only(key, '\u{e4f6}', theme)
        .on_click(move |button| {
            if button == Button::Left {
                close();
            }
        })
        .build()
}

fn card(
    entry: &Entry,
    theme: &Theme,
    width: f32,
    popup: bool,
    progress: Option<f32>,
    replying: bool,
    show_image: bool,
) -> Rectangle {
    let id = entry.id;
    let surface = if popup { "popup" } else { "history" };
    let notice = &entry.notice;
    let available = (width - padding::NORMAL * 2.0).max(0.0);
    let badge_size = layout::THUMBNAIL.min(available / 3.0);
    let close_width = if popup {
        design::size::BUTTON + spacing::EXTRA_SMALL
    } else {
        0.0
    };
    let info_width = (available - close_width).max(0.0);
    let text_width = (info_width - badge_size - spacing::SMALL).max(0.0);
    let initial = notice
        .app
        .chars()
        .find(|value| value.is_alphanumeric())
        .map(|value| value.to_uppercase().collect::<String>())
        .unwrap_or_else(|| "?".into());
    let badge = Rectangle::new()
        .width(badge_size)
        .height(badge_size)
        .fill(theme.surface2)
        .radius(theme.radius.small)
        .align_child(Center, Center);
    let badge = match notice.image.get().map(super::images::Preview::path) {
        Some(path) if show_image && Image::loaded(path) => badge.fill(Image::contain(path)),
        _ => badge.child(
            text(initial, theme)
                .size(typography::HEADLINE_SIZE)
                .weight(typography::HEADLINE_WEIGHT),
        ),
    };
    let title = text(&notice.title, theme)
        .weight(typography::HEADLINE_WEIGHT)
        .wrap()
        .elide()
        .max_lines(2);
    let body = text(&notice.body, theme)
        .wrap()
        .elide()
        .max_lines(if popup { 4 } else { 6 });
    let mut labels = children![
        text(&notice.app, theme)
            .color(theme.surface4)
            .elide()
            .max_lines(1),
        Rectangle::new()
            .width(Parent)
            .height(title.height_in(text_width))
            .child(title),
    ];
    if !notice.body.is_empty() {
        labels.push(Box::new(
            Rectangle::new()
                .width(Parent)
                .height(body.height_in(text_width))
                .child(body),
        ));
    }
    let info = Row::new(children![
        badge,
        Column::new(labels)
            .width(text_width)
            .gap(spacing::EXTRA_SMALL)
    ])
    .width(info_width)
    .align(Start)
    .gap(spacing::SMALL);
    let has_default = entry.live && notice.actions.iter().any(|(key, _)| key == "default");
    let mut heading = if popup || has_default {
        children![
            UiButton::new(format!("notification:{surface}:{id}:card"), "", theme)
                .variant(Variant::Ghost)
                .width(info_width)
                .height(height(&info))
                .padding(0.0)
                .content(info)
                .on_click(move |button| {
                    if button == Button::Left {
                        let mut state = Notifications::write();
                        let now = Instant::now();
                        if has_default {
                            state.invoke(id, "default", now);
                        } else {
                            state.dismiss_popup(id, now);
                        }
                    }
                })
                .build()
        ]
    } else {
        children![info]
    };
    if popup {
        heading.push(Box::new(close_button(
            format!("notification:{id}:close"),
            theme,
            move || {
                Notifications::write().dismiss_popup(id, Instant::now());
            },
        )));
    }
    let mut content = children![
        Row::new(heading)
            .width(Parent)
            .align(Start)
            .gap(spacing::EXTRA_SMALL)
    ];

    let mut buttons: Vec<Box<dyn Widget>> = Vec::new();
    if entry.live {
        for (index, (key, label)) in notice.actions.iter().enumerate() {
            if key == "default" {
                continue;
            }
            let key = key.clone();
            buttons.push(Box::new(action(
                format!("notification:{surface}:{id}:action:{index}"),
                label,
                Variant::Secondary,
                theme,
                move || Notifications::write().invoke(id, &key, Instant::now()),
            )));
        }
    }
    if !popup {
        if entry.live && notice.reply.is_some() {
            buttons.push(Box::new(action(
                format!("notification:{id}:reply"),
                if replying { "Cancel reply" } else { "Reply" },
                Variant::Secondary,
                theme,
                move || {
                    TextInput::set_text(REPLY_FIELD, "");
                    let mut state = Notifications::write();
                    state.reply_to = (state.reply_to != Some(id)).then_some(id);
                },
            )));
        }
        buttons.push(Box::new(action(
            format!("notification:{id}:dismiss"),
            "Dismiss",
            Variant::Ghost,
            theme,
            move || Notifications::write().dismiss(id, Instant::now()),
        )));
    }
    let mut buttons = buttons.into_iter();
    while let Some(first) = buttons.next() {
        let mut row = vec![first];
        row.extend(buttons.next());
        content.push(Box::new(
            Row::new(row).width(Parent).gap(spacing::EXTRA_SMALL),
        ));
    }
    if replying && let Some(placeholder) = &notice.reply {
        let input = TextInput::new(REPLY_FIELD)
            .placeholder(placeholder)
            .size(typography::BODY_SIZE)
            .color(theme.fg)
            .focused()
            .on_submit(move |reply| {
                if !reply.trim().is_empty() {
                    Notifications::write().reply(id, &reply, Instant::now());
                    TextInput::set_text(REPLY_FIELD, "");
                }
            });
        content.push(Box::new(
            Rectangle::new()
                .width(Parent)
                .height(height(&input) + layout::ACTION_PADDING * 2.0)
                .padding(layout::ACTION_PADDING)
                .fill(theme.surface3)
                .radius(theme.radius.small)
                .child(input),
        ));
        content.push(Box::new(text("Enter to send", theme).color(theme.surface4)));
    }
    if let Some(progress) = progress {
        content.push(Box::new(
            Rectangle::new()
                .width(Parent)
                .height(layout::PROGRESS_HEIGHT)
                .fill(theme.surface3)
                .align_child(Start, Center)
                .child(
                    Rectangle::new()
                        .width(available * progress)
                        .height(Parent)
                        .fill(theme.accent),
                ),
        ));
    }
    let content = Column::new(content).width(Parent).gap(spacing::EXTRA_SMALL);
    Rectangle::new()
        .width(width)
        .height(height(&content) + padding::NORMAL * 2.0)
        .padding(padding::NORMAL)
        .fill(theme.surface1)
        .radius(theme.radius.normal)
        .border(
            design::BORDER_WIDTH,
            if notice.critical {
                theme.destructive
            } else {
                theme.surface4
            },
        )
        .child(content)
}

fn panel_width(monitor: &Monitor) -> f32 {
    layout::WIDTH.min((monitor.width as f32 - layout::EDGE * 2.0).max(0.0))
}

fn popup_window(width: f32, height: f32) -> LayerWindow {
    LayerWindow::new()
        .width(width)
        .height(height)
        .anchor_vertical(Vertical::Top)
        .anchor_horizontal(Horizontal::Right)
        .margin(Margin {
            top: layout::TOP as i32,
            right: layout::EDGE as i32,
            ..Margin::default()
        })
        .space(Zone::Ignore)
        .layer(Layer::Top)
        .namespace("amane_notification")
}

pub fn popup(monitor: &Monitor) -> LayerWindow {
    let width = panel_width(monitor);
    if Niri::read().focused_output() != Some(monitor.name.as_str()) {
        return popup_window(width, 0.0).visible(false);
    }
    let displayed = {
        let state = Notifications::read();
        if state.monitor.is_some() {
            return popup_window(width, 0.0).visible(false);
        }
        state
            .popup
            .and_then(|popup| Some((popup, state.entry(popup.id)?.clone())))
    };
    let Some((popup, entry)) = displayed else {
        return popup_window(width, 0.0).visible(false);
    };
    let progress = popup
        .deadline
        .zip(entry.notice.timeout)
        .map(|(deadline, duration)| {
            amane::request_frame();
            (deadline
                .saturating_duration_since(Instant::now())
                .as_secs_f32()
                / duration.as_secs_f32())
            .clamp(0.0, 1.0)
        });
    let theme = ThemeState::read();
    let card = card(&entry, &theme.theme, width, true, progress, false, true);
    popup_window(width, height(&card)).child(card)
}

fn close_sidebar() {
    let mut state = Notifications::write();
    state.monitor = None;
    state.reply_to = None;
    TextInput::set_text(REPLY_FIELD, "");
}

#[derive(Default)]
struct HistoryLayout {
    width: f32,
    font: String,
    cards: HashMap<u32, CardHeight>,
}

struct CardHeight {
    notice: Weak<Notice>,
    live: bool,
    replying: bool,
    height: f32,
}

thread_local! {
    static HISTORY_LAYOUT: RefCell<HistoryLayout> = RefCell::default();
}

fn history_card(
    entry: &Entry,
    theme: &Theme,
    width: f32,
    replying: bool,
    images: bool,
) -> Rectangle {
    let id = entry.id;
    if entry.undo_until.is_some() {
        return action(
            format!("notification:{id}:undo"),
            "Dismissed · Undo",
            Variant::Secondary,
            theme,
            move || Notifications::write().undo(id),
        );
    }
    card(entry, theme, width, false, None, replying, images)
}

fn history_geometry(
    entries: &[&Entry],
    theme: &Theme,
    width: f32,
    reply_to: Option<u32>,
) -> (f32, Vec<(u32, f32)>) {
    HISTORY_LAYOUT.with_borrow_mut(|cache| {
        if cache.width != width || cache.font != theme.font {
            cache.cards.clear();
            cache.width = width;
            cache.font.clone_from(&theme.font);
        }
        cache
            .cards
            .retain(|_, measured| measured.notice.strong_count() != 0);
        let mut top = 0.0;
        let rows = entries
            .iter()
            .map(|entry| {
                let offset = top;
                let replying = reply_to == Some(entry.id);
                let item_height = if entry.undo_until.is_some() {
                    layout::ACTION_HEIGHT
                } else {
                    let notice = Arc::downgrade(&entry.notice);
                    let cached = cache.cards.get(&entry.id).filter(|measured| {
                        measured.notice.ptr_eq(&notice)
                            && measured.live == entry.live
                            && measured.replying == replying
                    });
                    if let Some(measured) = cached {
                        measured.height
                    } else {
                        let height = height(&history_card(entry, theme, width, replying, false));
                        cache.cards.insert(
                            entry.id,
                            CardHeight {
                                notice,
                                live: entry.live,
                                replying,
                                height,
                            },
                        );
                        height
                    }
                };
                top += item_height + spacing::EXTRA_SMALL;
                (entry.id, offset)
            })
            .collect();
        ((top - spacing::EXTRA_SMALL).max(0.0), rows)
    })
}

fn visible_rows(rows: &[(u32, f32)], offset: f32, viewport: f32) -> Range<usize> {
    // Keep one row beyond each edge so partial rows don't churn at the boundary.
    let start = rows
        .partition_point(|&(_, top)| top <= offset)
        .saturating_sub(2);
    let end = (rows.partition_point(|&(_, top)| top < offset + viewport) + 1).min(rows.len());
    start..end
}

pub fn sidebar_backdrop(monitor: &Monitor) -> LayerWindow {
    let visible = Notifications::read().monitor.as_deref() == Some(monitor.name.as_str());
    LayerWindow::new()
        .width(Full)
        .height(Full)
        .space(Zone::Ignore)
        .layer(Layer::Top)
        .namespace("amane_notification_backdrop")
        .visible(visible)
        .child(
            Rectangle::new()
                .width(Parent)
                .height(Parent)
                .on_click(|_| close_sidebar()),
        )
}

fn sidebar_window(width: f32, height: f32) -> LayerWindow {
    LayerWindow::new()
        .width(width)
        .height(height)
        .anchor_vertical(Vertical::Top)
        .anchor_horizontal(Horizontal::Right)
        .margin(Margin {
            top: layout::TOP as i32,
            right: layout::EDGE as i32,
            ..Margin::default()
        })
        .space(Zone::Ignore)
        .layer(Layer::Overlay)
        .keyboard(Keyboard::Exclusive)
        .namespace("amane_notification_history")
}

pub fn sidebar(monitor: &Monitor) -> LayerWindow {
    let width = panel_width(monitor);
    let (entries, reply_to, running) = {
        let state = Notifications::read();
        if state.monitor.as_deref() != Some(&monitor.name) {
            return sidebar_window(width, 0.0).visible(false);
        }
        (state.entries.clone(), state.reply_to, state.running)
    };
    let theme = ThemeState::read();
    let theme = &theme.theme;
    let inside = (width - padding::NORMAL * 2.0).max(0.0);
    let budget =
        (monitor.height as f32 - layout::TOP - layout::EDGE - padding::NORMAL * 2.0).max(0.0);
    let header = Column::new(children![
        Row::new(children![
            Rectangle::new()
                .width(Parent)
                .height(design::size::BUTTON)
                .align_child(Start, Center)
                .child(text("Notifications", theme).weight(typography::HEADLINE_WEIGHT)),
            close_button("notification_history:close".into(), theme, close_sidebar),
        ])
        .width(Parent)
        .align(Center),
        action(
            "notification_clear".into(),
            "Clear all",
            Variant::Ghost,
            theme,
            || {
                Notifications::write().clear();
                TextInput::set_text(REPLY_FIELD, "");
            }
        ),
    ])
    .width(Parent)
    .gap(spacing::EXTRA_SMALL);
    let available = (budget - height(&header) - spacing::SMALL).max(0.0);
    let entries: Vec<_> = entries
        .iter()
        .filter(|entry| !entry.notice.transient)
        .collect();
    let list = if entries.is_empty() {
        let message = if running {
            "All clear"
        } else {
            "Notification service unavailable"
        };
        let message = text(message, theme).color(theme.surface4);
        anchored_scroll_area(
            "notification_history",
            monitor.name.clone(),
            inside,
            available.min(height(&message)),
            height(&message),
            Vec::new(),
            |_| message,
        )
    } else {
        let (total, rows) = history_geometry(&entries, theme, inside, reply_to);
        let viewport = available.min(total);
        anchored_scroll_area(
            "notification_history",
            monitor.name.clone(),
            inside,
            viewport,
            total,
            rows.clone(),
            |offset| {
                let visible = visible_rows(&rows, offset, viewport);
                let mut widgets: Vec<Box<dyn Widget>> = Vec::new();
                if visible.start != 0 {
                    widgets.push(Box::new(
                        Rectangle::new()
                            .width(Parent)
                            .height(rows[visible.start].1 - spacing::EXTRA_SMALL),
                    ));
                }
                for entry in &entries[visible] {
                    widgets.push(Box::new(history_card(
                        entry,
                        theme,
                        inside,
                        reply_to == Some(entry.id),
                        true,
                    )));
                }
                Column::new(widgets).width(Parent).gap(spacing::EXTRA_SMALL)
            },
        )
    };
    let content = Column::new(children![header, list])
        .width(Parent)
        .gap(spacing::SMALL);
    let panel_height = height(&content) + padding::NORMAL * 2.0;
    sidebar_window(width, panel_height)
        .on_key(|key| {
            if key == Key::Escape {
                close_sidebar();
            }
        })
        .child(
            Rectangle::new()
                .width(Parent)
                .height(Parent)
                .padding(padding::NORMAL)
                .fill(theme.surface1)
                .radius(theme.radius.normal)
                .border(design::BORDER_WIDTH, theme.surface4)
                .child(content),
        )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bell_button_grows_only_to_fit_the_visible_count() {
        let theme: Theme = serde_json::from_value(serde_json::json!({
            "bg": "#ffffff", "fg": "#000000", "accent": "#0000ff",
            "success": "#008000", "destructive": "#ff0000",
            "surface1": "#eeeeee", "surface2": "#dddddd",
            "surface3": "#cccccc", "surface4": "#666666", "font": "sans-serif",
            "radius": { "small": 2.0, "normal": 4.0, "large": 6.0 }
        }))
        .unwrap();
        let width = |count| {
            let Size::Fixed(width) = Widget::width(&bell_button("test", &theme, count, true))
            else {
                panic!("bell button must have an intrinsic width");
            };
            width
        };
        assert_eq!(width(0), design::size::BUTTON);
        assert!(width(0) < width(3));
        assert!(width(3) < width(99));
        assert!(width(99) < width(100));
        assert_eq!(width(100), width(101));
    }

    #[test]
    fn full_history_mounts_only_visible_rows_and_neighbours() {
        let rows: Vec<_> = (0..100).map(|id| (id, id as f32 * 70.0)).collect();
        assert_eq!(visible_rows(&rows, 0.0, 560.0), 0..9);
        assert_eq!(visible_rows(&rows, 3500.0, 560.0), 49..59);
        assert_eq!(visible_rows(&rows, 6440.0, 560.0), 91..100);
    }
}
