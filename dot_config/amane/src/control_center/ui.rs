use amane::{Center, Color, Rectangle, Text, Weight};

use crate::{design, theme::Theme};

pub(super) fn text(value: impl Into<String>, theme: &Theme) -> Text {
    Text::new(value)
        .font(&theme.font)
        .size(design::typography::BODY_SIZE)
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
        .size(design::typography::HEADLINE_SIZE)
        .weight(design::typography::HEADLINE_WEIGHT)
}

pub(super) fn body(value: impl Into<String>, theme: &Theme) -> Text {
    text(value, theme).weight(design::typography::BODY_WEIGHT)
}

pub(super) fn supporting(value: impl Into<String>, theme: &Theme) -> Text {
    body(value, theme)
        .weight(design::typography::SUPPORTING_WEIGHT)
        .color(theme.surface4)
}
