//! Shell-wide buttons. Keys identify mounted instances across view rebuilds.
//! Use monitor-scoped keys for controls rendered on multiple monitors.
use std::{
    cell::{Cell, RefCell},
    collections::HashMap,
    rc::{Rc, Weak},
};

use amane::{
    Button as MouseButton, Center, Color, Cursor, Parent, Rectangle, Row, Size, Text, Widget,
};

use crate::{design, theme::Theme};

#[derive(Clone, Copy, Default)]
pub enum Variant {
    #[default]
    Default,
    Secondary,
    Ghost,
    Destructive,
}

#[derive(Clone, Copy, Default)]
struct Interaction {
    hovered: bool,
    pressed: bool,
}

thread_local! {
    // Weak entries keep transient tray/device controls from retaining UI state forever.
    static INTERACTIONS: RefCell<HashMap<String, Weak<Cell<Interaction>>>> = RefCell::default();
}

fn interaction(key: String) -> Rc<Cell<Interaction>> {
    INTERACTIONS.with_borrow_mut(|states| {
        states.retain(|_, state| state.strong_count() > 0);
        if let Some(state) = states.get(&key).and_then(Weak::upgrade) {
            return state;
        }
        let state = Rc::new(Cell::new(Interaction::default()));
        states.insert(key, Rc::downgrade(&state));
        state
    })
}

pub fn icon_glyph(glyph: char, color: Color, width: f32) -> Rectangle {
    Rectangle::new()
        .width(width)
        .height(design::size::BUTTON)
        .align_child(Center, Center)
        .child(
            Text::new(glyph.to_string())
                .font(design::ICON_FONT)
                .size(design::ICON_SIZE)
                .color(color)
                .tight(),
        )
}

pub struct Button<'a> {
    key: String,
    label: String,
    theme: &'a Theme,
    variant: Variant,
    selected: bool,
    disabled: bool,
    icon: Option<char>,
    trailing_icon: Option<char>,
    width: Option<Size>,
    height: f32,
    padding: f32,
    content: Option<Box<dyn Widget>>,
    on_click: Option<Box<dyn Fn(MouseButton)>>,
}

impl<'a> Button<'a> {
    pub fn new(key: impl Into<String>, label: impl Into<String>, theme: &'a Theme) -> Self {
        Self {
            key: key.into(),
            label: label.into(),
            theme,
            variant: Variant::Default,
            selected: false,
            disabled: false,
            icon: None,
            trailing_icon: None,
            width: None,
            height: design::button::HEIGHT,
            padding: design::padding::NORMAL,
            content: None,
            on_click: None,
        }
    }

    pub fn icon_only(key: impl Into<String>, glyph: char, theme: &'a Theme) -> Self {
        Self::new(key, "", theme)
            .variant(Variant::Ghost)
            .icon(glyph)
            .width(design::size::BUTTON)
            .height(design::size::BUTTON)
            .padding(0.0)
    }

    pub fn variant(mut self, variant: Variant) -> Self {
        self.variant = variant;
        self
    }

    pub fn selected(mut self, selected: bool) -> Self {
        self.selected = selected;
        self
    }

    pub fn disabled(mut self, disabled: bool) -> Self {
        self.disabled = disabled;
        self
    }

    pub fn icon(mut self, icon: char) -> Self {
        self.icon = Some(icon);
        self
    }

    pub fn trailing_icon(mut self, icon: char) -> Self {
        self.trailing_icon = Some(icon);
        self
    }

    pub fn width(mut self, width: impl Into<Size>) -> Self {
        self.width = Some(width.into());
        self
    }

    pub fn height(mut self, height: f32) -> Self {
        self.height = height;
        self
    }

    pub fn padding(mut self, padding: f32) -> Self {
        self.padding = padding;
        self
    }

    /// Rich rows share the same interaction surface without imposing a label layout.
    pub fn content(mut self, content: impl Widget + 'static) -> Self {
        self.content = Some(Box::new(content));
        self
    }

    pub fn on_click(mut self, handler: impl Fn(MouseButton) + 'static) -> Self {
        self.on_click = Some(Box::new(handler));
        self
    }

    pub fn build(self) -> Rectangle {
        let state = interaction(self.key.clone());
        if self.disabled {
            state.set(Interaction::default());
        }
        let (fill, foreground, border) = self.colors(state.get());
        let content = self.content.unwrap_or_else(|| {
            let icon = |glyph| icon_glyph(glyph, foreground, design::ICON_SIZE);
            let mut children: Vec<Box<dyn Widget>> = Vec::new();
            if let Some(glyph) = self.icon {
                children.push(Box::new(icon(glyph)));
            }
            if !self.label.is_empty() {
                let label = Text::new(self.label)
                    .font(&self.theme.font)
                    .size(design::typography::BODY_SIZE)
                    .weight(design::typography::BODY_WEIGHT)
                    .color(foreground);
                let Size::Fixed(mut width) = label.width() else {
                    unreachable!("unwrapped button labels have measured widths");
                };
                if let Some(Size::Fixed(available)) = self.width {
                    let icons = children.len() + usize::from(self.trailing_icon.is_some());
                    width = width.min(
                        (available
                            - self.padding * 2.0
                            - icons as f32 * (design::ICON_SIZE + design::spacing::SMALL))
                            .max(0.0),
                    );
                }
                children.push(Box::new(
                    Rectangle::new()
                        .width(width)
                        .height(label.height())
                        .align_child(Center, Center)
                        .child(label.elide().max_lines(1)),
                ));
            }
            if let Some(glyph) = self.trailing_icon {
                children.push(Box::new(icon(glyph)));
            }
            Box::new(Row::new(children).align(Center).gap(design::spacing::SMALL))
        });
        let width = self.width.unwrap_or_else(|| match content.width() {
            Size::Fixed(width) => Size::Fixed(width + self.padding * 2.0),
            Size::Parent => Parent,
        });
        let mut surface = Rectangle::new()
            .width(width)
            .height(self.height)
            .padding(self.padding)
            .fill(fill)
            .border(design::BORDER_WIDTH, border)
            .radius(self.theme.radius.normal)
            .clip()
            .align_child(Center, Center)
            .child(Row::new(vec![content]).align(Center));
        if self.disabled {
            // Consume clicks, rather than allowing them to reach an enclosing action.
            return surface.cursor(Cursor::Default).on_click(|_| {});
        }
        let hover = state.clone();
        let press = state.clone();
        surface = surface
            .cursor(Cursor::Pointer)
            .on_hover(move |inside| {
                let mut value = hover.get();
                value.hovered = inside;
                if !inside {
                    value.pressed = false;
                }
                hover.set(value);
            })
            .on_drag(move |_| {
                let mut value = press.get();
                value.pressed = value.hovered;
                press.set(value);
            })
            .on_click(move |button| {
                let mut value = state.get();
                value.pressed = false;
                state.set(value);
                if let Some(handler) = &self.on_click {
                    handler(button);
                }
            });
        surface
    }

    fn colors(&self, interaction: Interaction) -> (Color, Color, Color) {
        let theme = self.theme;
        let (mut fill, mut foreground) = match self.variant {
            Variant::Default => (theme.accent, theme.bg),
            Variant::Secondary => (theme.surface2, theme.fg),
            Variant::Ghost => (Color::TRANSPARENT, theme.fg),
            Variant::Destructive => (theme.destructive, theme.bg),
        };
        if self.disabled {
            fill = theme.surface2;
            foreground = theme.surface4;
        } else if interaction.pressed {
            fill = tint(fill, foreground, design::button::PRESSED_TINT);
        } else if interaction.hovered {
            fill = tint(fill, foreground, design::button::HOVER_TINT);
        }
        let border = if self.selected {
            theme.accent
        } else {
            Color::TRANSPARENT
        };
        (fill, foreground, border)
    }
}

fn tint(base: Color, foreground: Color, amount: f32) -> Color {
    if base.alpha() == 0 {
        return Color::rgba(
            foreground.red(),
            foreground.green(),
            foreground.blue(),
            (255.0 * amount).round() as u8,
        );
    }
    let mix = |base: u8, foreground: u8| {
        (base as f32 + (foreground as f32 - base as f32) * amount).round() as u8
    };
    Color::rgba(
        mix(base.red(), foreground.red()),
        mix(base.green(), foreground.green()),
        mix(base.blue(), foreground.blue()),
        base.alpha(),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::theme::Radius;

    fn theme() -> Theme {
        Theme {
            bg: Color::BLACK,
            fg: Color::WHITE,
            accent: Color::BLUE,
            success: Color::GREEN,
            destructive: Color::RED,
            surface1: Color::rgb(25, 25, 25),
            surface2: Color::rgb(50, 50, 50),
            surface3: Color::rgb(90, 90, 90),
            surface4: Color::rgb(180, 180, 180),
            font: "sans-serif".into(),
            radius: Radius {
                small: 2.0,
                normal: 6.0,
                large: 10.0,
            },
        }
    }

    #[test]
    fn variants_and_interaction_states_use_theme_colors() {
        let theme = theme();
        for (variant, fill) in [
            (Variant::Default, theme.accent),
            (Variant::Secondary, theme.surface2),
            (Variant::Ghost, Color::TRANSPARENT),
            (Variant::Destructive, theme.destructive),
        ] {
            let button = Button::new("colors", "Button", &theme).variant(variant);
            assert_eq!(button.colors(Interaction::default()).0, fill);
            let foreground = button.colors(Interaction::default()).1;
            assert_eq!(
                button.colors(Interaction {
                    hovered: true,
                    pressed: false
                }),
                (
                    tint(fill, foreground, design::button::HOVER_TINT),
                    foreground,
                    Color::TRANSPARENT
                )
            );
            assert_eq!(
                button.colors(Interaction {
                    hovered: true,
                    pressed: true
                }),
                (
                    tint(fill, foreground, design::button::PRESSED_TINT),
                    foreground,
                    Color::TRANSPARENT
                )
            );
            let button = button.selected(true).disabled(true);
            assert_eq!(
                button.colors(Interaction {
                    hovered: true,
                    pressed: true
                }),
                (theme.surface2, theme.surface4, theme.accent)
            );
        }
    }

    #[test]
    fn keys_preserve_mounted_state_without_retaining_unmounted_controls() {
        let first = interaction("one".into());
        first.set(Interaction {
            hovered: true,
            pressed: false,
        });
        assert!(interaction("one".into()).get().hovered);
        assert!(!interaction("two".into()).get().hovered);
        drop(first);
        assert!(!interaction("one".into()).get().hovered);
    }

    #[test]
    fn labels_icons_and_rich_content_share_explicit_dimensions() {
        let theme = theme();
        for button in [
            Button::new("label", "Centered", &theme),
            Button::new("leading", "Centered", &theme).icon('\u{e136}'),
            Button::new("trailing", "Centered", &theme).trailing_icon('\u{e13a}'),
            Button::new("icon", "", &theme).icon('\u{e136}'),
            Button::new("rich", "", &theme).content(Rectangle::new().width(Parent).height(20.0)),
        ] {
            let button = button.width(160.0).build();
            assert_eq!(button.width(), Size::Fixed(160.0));
            assert_eq!(button.height(), Size::Fixed(design::button::HEIGHT));
        }
    }

    #[test]
    fn disabling_a_button_clears_held_interaction() {
        let theme = theme();
        let state = interaction("disabled".into());
        state.set(Interaction {
            hovered: true,
            pressed: true,
        });
        let _button = Button::new("disabled", "Disabled", &theme)
            .disabled(true)
            .build();
        assert!(!state.get().hovered);
        assert!(!state.get().pressed);
    }
}
