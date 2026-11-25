use amane::{Color, Parent, Rectangle, Text};

use crate::{components::button::icon_glyph, design, theme::Theme};

pub(super) fn body(value: impl Into<String>, theme: &Theme) -> Text {
    Text::new(value)
        .font(&theme.font)
        .size(design::typography::BODY_SIZE)
        .weight(design::typography::BODY_WEIGHT)
        .color(theme.fg)
}

pub(super) fn icon(code: char, color: Color) -> Rectangle {
    icon_glyph(code, color, design::ICON_SIZE)
}

pub(super) fn headline(value: impl Into<String>, theme: &Theme) -> Text {
    body(value, theme)
        .size(design::typography::HEADLINE_SIZE)
        .weight(design::typography::HEADLINE_WEIGHT)
}

pub(super) fn supporting(value: impl Into<String>, theme: &Theme) -> Text {
    body(value, theme)
        .weight(design::typography::SUPPORTING_WEIGHT)
        .color(theme.surface4)
}

pub(super) fn paragraph(value: &str, theme: &Theme, width: f32, error: bool) -> Rectangle {
    let mut text = supporting(value, theme).wrap();
    if error {
        text = text.color(theme.destructive);
    }
    Rectangle::new()
        .width(Parent)
        .height(text.height_in(width))
        .child(text)
}
