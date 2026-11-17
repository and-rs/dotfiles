use amane::{Center, Color, Rectangle, Text, Weight};

use crate::{design, theme::Theme};

pub(super) fn text(value: impl Into<String>, theme: &Theme) -> Text {
    Text::new(value)
        .font(&theme.font)
        .size(theme.font_size * design::BAR_TEXT_SCALE)
        .weight(Weight::Medium)
        .color(theme.fg)
}

pub(super) fn icon(code: char, color: Color) -> Rectangle {
    Rectangle::new()
        .width(design::ICON_SIZE)
        .height(design::size::BUTTON)
        .align_child(Center, Center)
        .child(
            Text::new(code.to_string())
                .font(design::ICON_FONT)
                .size(design::ICON_SIZE)
                .color(color)
                .tight(),
        )
}

pub(super) fn headline(value: impl Into<String>, theme: &Theme) -> Text {
    text(value, theme)
        .size(theme.font_size * design::typography::HEADLINE_SCALE)
        .weight(design::typography::HEADLINE_WEIGHT)
}

pub(super) fn body(value: impl Into<String>, theme: &Theme) -> Text {
    text(value, theme)
        .size(theme.font_size * design::typography::BODY_SCALE)
        .weight(design::typography::BODY_WEIGHT)
}

pub(super) fn supporting(value: impl Into<String>, theme: &Theme) -> Text {
    body(value, theme)
        .weight(design::typography::SUPPORTING_WEIGHT)
        .color(theme.surface4)
}
