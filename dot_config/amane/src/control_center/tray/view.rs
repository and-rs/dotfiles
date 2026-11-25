use amane::{
    Button, Center, Column, Image, Parent, Rectangle, Row, Service, Size, Widget, children,
};

use super::{
    Command, State,
    items::{Action, Item},
    menu::{Entry, Menu},
    request,
};
use crate::{
    components::{Button as UiButton, Variant},
    control_center::ui,
    design::{self, control_center as layout, padding, spacing, typography},
    theme::Theme,
};

fn height(widget: &impl Widget) -> f32 {
    let Size::Fixed(height) = widget.height() else {
        unreachable!("tray content has intrinsic height");
    };
    height
}

fn item_icon(item: &Item, theme: &Theme) -> Rectangle {
    let Some(image) = item
        .icon
        .as_ref()
        .filter(|image| Image::loaded(&image.source))
    else {
        return ui::icon('\u{e136}', theme.surface4);
    };
    let icon = Rectangle::new()
        .width(design::ICON_SIZE)
        .height(design::size::BUTTON)
        .fill(Image::contain(&image.source));
    let Some(halo) = image.halo.as_ref().filter(|halo| Image::loaded(*halo)) else {
        return icon;
    };
    let inset = design::tray::ICON_HALO_INSET;
    Rectangle::new()
        .width(design::ICON_SIZE)
        .height(design::size::BUTTON)
        .align_child(Center, Center)
        .child(
            Rectangle::new()
                .width(design::ICON_SIZE + inset * 2.0)
                .height(design::size::BUTTON + inset * 2.0)
                .fill(Image::contain(halo))
                .align_child(Center, Center)
                .child(icon),
        )
}

fn item_row(item: &Item, theme: &Theme, width: f32) -> Rectangle {
    let color = if item.attention() {
        theme.accent
    } else {
        theme.fg
    };
    let mut labels = children![
        ui::body(&item.title, theme)
            .weight(typography::HEADLINE_WEIGHT)
            .color(color)
            .elide()
            .max_lines(1),
    ];
    if let Some(error) = &item.error {
        labels.push(Box::new(
            ui::supporting(error, theme)
                .color(theme.destructive)
                .elide()
                .max_lines(1),
        ));
    } else if item.attention() {
        labels.push(Box::new(
            ui::supporting("Needs attention", theme).color(color),
        ));
    } else if !item.tooltip.trim().is_empty() {
        labels.push(Box::new(
            ui::supporting(item.tooltip.replace('\n', " · "), theme)
                .elide()
                .max_lines(1),
        ));
    }
    let labels = Column::new(labels).width(Parent).gap(spacing::TINY);
    let row = Row::new(children![
        item_icon(item, theme).on_scroll({
            let id = item.id.clone();
            move |scroll| {
                let (delta, horizontal) = scroll_delta(scroll.x, scroll.y);
                if delta != 0 {
                    request(Command::Action(
                        id.clone(),
                        Action::Scroll(delta, horizontal),
                    ));
                }
            }
        }),
        labels,
    ])
    .width(Parent)
    .align(Center)
    .gap(spacing::SMALL);
    let id = item.id.clone();
    UiButton::new(format!("tray:{:?}", item.id), "", theme)
        .variant(Variant::Secondary)
        .width(width)
        .height(
            height(&row).max(layout::ROW_HEIGHT - padding::NORMAL * 2.0) + padding::NORMAL * 2.0,
        )
        .padding(padding::NORMAL)
        .content(row)
        .disabled(item.error.is_some())
        .on_click(move |button| match button {
            Button::Left => request(Command::Menu(id.clone())),
            Button::Middle => request(Command::Action(id.clone(), Action::Secondary)),
            Button::Right => request(Command::Action(id.clone(), Action::Activate)),
        })
        .build()
}

/// SNI wheel units are 120 per notch, with positive vertical values meaning up.
fn scroll_delta(x: f32, y: f32) -> (i32, bool) {
    if !x.is_finite() || !y.is_finite() {
        return (0, false);
    }
    let horizontal = x.abs() > y.abs();
    let lines = if horizontal { x } else { -y };
    (
        (lines * 120.0).round().clamp(-1200.0, 1200.0) as i32,
        horizontal,
    )
}

fn menu_row(entry: &Entry, menu: &Menu, theme: &Theme, width: f32) -> Rectangle {
    if entry.separator {
        return Rectangle::new()
            .width(Parent)
            .height(design::BORDER_WIDTH)
            .fill(theme.surface3);
    }
    let mut label = entry.label.clone();
    if !entry.toggle.is_empty() {
        let status = match (entry.toggle.as_str(), entry.toggle_state) {
            (_, -1) => "Mixed",
            ("radio", 1) => "Selected",
            ("radio", _) => "Not selected",
            (_, 1) => "On",
            _ => "Off",
        };
        label.push_str(&format!(" · {status}"));
    }
    let id = menu.item.id.clone();
    let entry_id = entry.id;
    let mut button = UiButton::new(format!("tray_menu:{:?}:{}", id, entry_id), label, theme)
        .variant(Variant::Secondary)
        .width(width)
        .height(layout::ROW_HEIGHT)
        .padding(padding::NORMAL)
        .disabled(!entry.enabled)
        .on_click(move |button| {
            if button == Button::Left {
                request(Command::MenuClick(id.clone(), entry_id));
            }
        });
    if entry.submenu {
        button = button.trailing_icon('\u{e13a}');
    }
    button.build()
}

fn header(state: &State, theme: &Theme, width: f32) -> Column {
    let mut content = children![ui::body("Tray", theme).weight(typography::HEADLINE_WEIGHT),];
    if let Some(menu) = &state.menu {
        content.push(Box::new(
            UiButton::new("tray_back", "Back", theme)
                .variant(Variant::Secondary)
                .width(Parent)
                .height(layout::ROW_HEIGHT)
                .on_click(|button| {
                    if button == Button::Left {
                        request(Command::Back);
                    }
                })
                .build(),
        ));
        content.push(Box::new(
            ui::body(&menu.item.title, theme).elide().max_lines(1),
        ));
    } else {
        let visible = state.items.iter().filter(|i| i.visible()).count();
        let hidden = state.items.len() - visible;
        let label = if state.loading {
            "Checking tray…".into()
        } else if visible == 0 && hidden == 0 {
            "No tray applications".into()
        } else if hidden > 0 {
            format!("{visible} active · {hidden} passive")
        } else if visible == 1 {
            "1 application".into()
        } else {
            format!("{visible} applications")
        };
        content.push(Box::new(ui::supporting(label, theme)));
    }
    if let Some(error) = state.error {
        content.push(Box::new(ui::paragraph(error.message(), theme, width, true)));
    }
    Column::new(content).width(Parent).gap(spacing::EXTRA_SMALL)
}

fn list(state: &State, theme: &Theme, width: f32) -> Column {
    let mut content: Vec<Box<dyn Widget>> = Vec::new();
    if let Some(menu) = &state.menu {
        for entry in &menu.entries {
            content.push(Box::new(menu_row(entry, menu, theme, width)));
        }
        if content.is_empty() {
            content.push(Box::new(ui::paragraph(
                "This menu is empty.",
                theme,
                width,
                false,
            )));
        }
    } else {
        for item in state.items.iter().filter(|i| i.visible()) {
            content.push(Box::new(item_row(item, theme, width)));
        }
    }
    Column::new(content).width(Parent).gap(spacing::EXTRA_SMALL)
}

pub fn view(theme: &Theme, width: f32, budget: f32) -> Column {
    content(&State::read(), theme, width, budget)
}

fn content(state: &State, theme: &Theme, width: f32, budget: f32) -> Column {
    let header = header(state, theme, width);
    let available = (budget - height(&header) - spacing::SMALL).max(0.0);
    let list = list(state, theme, width);
    let list_height = height(&list);
    let mut content = children![header];
    if list_height > 0.0 {
        if list_height > available {
            let key = if state.menu.is_some() {
                "tray_menu"
            } else {
                "tray_items"
            };
            let context = state.menu.as_ref().map_or_else(String::new, |menu| {
                format!("{:?}:{:?}", menu.item.id, menu.stack)
            });
            content.push(Box::new(crate::components::scroll_area(
                key, context, list, width, available,
            )));
        } else {
            content.push(Box::new(list));
        }
    }
    Column::new(content).width(width).gap(spacing::SMALL)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        control_center::tray::{Error, items::Id},
        theme::test_theme as theme,
    };

    fn item() -> Item {
        Item {
            id: Id {
                owner: ":1.42".into(),
                path: "/Item".into(),
            },
            interface: "org.kde.StatusNotifierItem".into(),
            title: "Test application".into(),
            tooltip: "Application status".into(),
            status: "Active".into(),
            icon: None,
            menu: None,
            error: None,
        }
    }

    #[test]
    fn wheel_actions_preserve_orientation_and_reject_nonfinite_input() {
        assert_eq!(scroll_delta(0.0, 1.0), (-120, false));
        assert_eq!(scroll_delta(1.0, 0.0), (120, true));
        assert_eq!(scroll_delta(0.0, f32::NAN), (0, false));
    }

    #[test]
    fn empty_and_short_lists_have_intrinsic_height_and_only_overflow_uses_budget() {
        let theme = theme();
        let mut state = State::new();
        for width in [380.0, 160.0] {
            let empty = height(&header(&state, &theme, width));
            assert_eq!(height(&content(&state, &theme, width, 500.0)), empty);
            state.loading = false;
            state.items = vec![item()];
            let expected = height(&header(&state, &theme, width))
                + spacing::SMALL
                + height(&list(&state, &theme, width));
            assert_eq!(height(&content(&state, &theme, width, 500.0)), expected);
            for _ in 0..20 {
                state.items.push(item());
            }
            assert_eq!(height(&content(&state, &theme, width, 300.0)), 300.0);
            state.items.clear();
        }
    }

    #[test]
    fn passive_items_are_hidden_and_long_labels_keep_row_height_stable() {
        let theme = theme();
        let mut state = State::new();
        let mut app = item();
        let normal = height(&item_row(&app, &theme, 160.0));
        app.title = "Long title ".repeat(30);
        app.tooltip = "Long tooltip ".repeat(30);
        assert_eq!(height(&item_row(&app, &theme, 160.0)), normal);
        app.status = "Passive".into();
        state.items.push(app);
        assert_eq!(height(&list(&state, &theme, 160.0)), 0.0);
        state.error = Some(Error::Backend);
        assert!(
            height(&header(&state, &theme, 160.0)) > height(&header(&State::new(), &theme, 160.0))
        );
    }

    #[test]
    fn menu_separators_and_toggle_rows_have_shared_dimensions() {
        let theme = theme();
        let mut entry = Entry {
            id: 1,
            label: "Toggle".into(),
            enabled: false,
            separator: false,
            toggle: "checkmark".into(),
            toggle_state: 1,
            submenu: false,
        };
        let menu = Menu {
            item: item(),
            stack: vec![],
            entries: vec![entry.clone()],
        };
        assert_eq!(
            height(&menu_row(&entry, &menu, &theme, 160.0)),
            layout::ROW_HEIGHT
        );
        entry.separator = true;
        assert_eq!(
            height(&menu_row(&entry, &menu, &theme, 160.0)),
            design::BORDER_WIDTH
        );
    }
}
