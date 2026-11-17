use amane::{Canvas, Cap, Center, Color, Path, Rectangle, Row, Shape, Stack, Text, children};

use crate::{
    design::{self, indicator as tokens, spacing},
    theme::{Theme, faded},
};

#[derive(Clone, Copy, Debug, PartialEq)]
pub(super) struct Battery {
    pub level: f32,
    pub charging: bool,
}

impl Battery {
    pub fn from_upower(percent: f64, state: u32) -> Self {
        let level = if percent.is_finite() {
            (percent / 100.0).clamp(0.0, 1.0) as f32
        } else {
            0.0
        };
        Self {
            level,
            charging: matches!(state, 1 | 5),
        }
    }
}

pub(super) fn view(battery: Battery, theme: &Theme, charge_opacity: f32) -> Row {
    let fill = battery_color(
        battery,
        theme.bg,
        theme.fg,
        theme.success,
        theme.destructive,
    );
    let inner_width = tokens::BATTERY_WIDTH - tokens::BATTERY_INSET * 2.0;
    let inner_height = tokens::BATTERY_HEIGHT - tokens::BATTERY_INSET * 2.0;
    let mut layers = children![
        Rectangle::new()
            .width(tokens::BATTERY_WIDTH)
            .height(tokens::BATTERY_HEIGHT)
            .padding(tokens::BATTERY_INSET)
            .clip()
            .child(
                Rectangle::new()
                    .width(inner_width * battery.level)
                    .height(inner_height)
                    .fill(fill),
            ),
        Rectangle::new()
            .width(tokens::BATTERY_WIDTH)
            .height(tokens::BATTERY_HEIGHT)
            .border(design::BORDER_WIDTH, theme.surface3)
            .radius(theme.radius.small),
    ];
    if charge_opacity > 0.0 {
        layers.push(Box::new(
            Rectangle::new()
                .width(tokens::BATTERY_WIDTH)
                .height(tokens::BATTERY_HEIGHT)
                .opacity(charge_opacity)
                .child(bolt(theme.bg, theme.fg)),
        ));
    }
    Row::new(children![
        Text::new(format!("{:.0}%", battery.level * 100.0))
            .font(&theme.font)
            .size(design::typography::BODY_SIZE)
            .weight(tokens::BATTERY_WEIGHT)
            .color(theme.fg),
        Row::new(children![
            Stack::new(layers),
            Rectangle::new()
                .width(tokens::TERMINAL_WIDTH)
                .height(tokens::TERMINAL_HEIGHT)
                .fill(theme.surface3)
                .radius_top_right(theme.radius.small)
                .radius_bottom_right(theme.radius.small),
        ])
        .align(Center),
    ])
    .gap(spacing::EXTRA_SMALL)
    .align(Center)
}

fn lightness(color: Color) -> f32 {
    let channels = [color.red(), color.green(), color.blue()];
    (f32::from(*channels.iter().max().unwrap()) + f32::from(*channels.iter().min().unwrap()))
        / 510.0
}

fn battery_color(
    battery: Battery,
    bg: Color,
    fg: Color,
    success: Color,
    destructive: Color,
) -> Color {
    if battery.level < 0.2 {
        return destructive;
    }
    if !battery.charging {
        return fg;
    }
    if lightness(bg) < 0.5 {
        return success;
    }
    // Preserve the original HSL saturation/lightness adjustment on light themes.
    let channels = [success.red(), success.green(), success.blue()].map(|c| f32::from(c) / 255.0);
    let max = channels.iter().copied().fold(0.0_f32, f32::max);
    let min = channels.iter().copied().fold(1.0_f32, f32::min);
    let chroma = max - min;
    let old_lightness = (max + min) / 2.0;
    let saturation = if chroma == 0.0 {
        0.0
    } else {
        chroma / (1.0 - (2.0 * old_lightness - 1.0).abs())
    };
    let lightness = (old_lightness + tokens::CHARGE_LIGHTNESS).min(1.0);
    let saturation = (saturation * tokens::CHARGE_SATURATION).min(1.0);
    let new_chroma = (1.0 - (2.0 * lightness - 1.0).abs()) * saturation;
    let channels = channels.map(|c| {
        let hue_channel = if chroma == 0.0 {
            0.0
        } else {
            (c - min) / chroma
        };
        ((hue_channel * new_chroma + lightness - new_chroma / 2.0) * 255.0).round() as u8
    });
    Color::rgba(channels[0], channels[1], channels[2], success.alpha())
}

fn bolt(bg: Color, fg: Color) -> Canvas {
    let (light, dark) = if lightness(bg) >= lightness(fg) {
        (bg, fg)
    } else {
        (fg, bg)
    };
    let scale = tokens::BOLT_SIZE / 1024.0;
    // Exact Phosphor-Fill U+E2DE outline, extracted from the original font.
    // Font coordinates are asset data, not independently tunable UI dimensions.
    let x = |value: f32| (value - 512.0) * scale + tokens::BATTERY_WIDTH / 2.0;
    let y = |value: f32| (448.0 - value) * scale + tokens::BATTERY_HEIGHT / 2.0;
    let path = Path::new()
        .move_to(x(855.0), y(458.0))
        .line_to(x(407.0), y(-22.0))
        .quad_to(x(403.0), y(-27.0), x(397.0), y(-29.5))
        .quad_to(x(391.0), y(-32.0), x(384.0), y(-32.0))
        .quad_to(x(371.0), y(-32.0), x(361.5), y(-22.5))
        .quad_to(x(352.0), y(-13.0), x(352.0), y(0.0))
        .quad_to(x(352.0), y(2.0), x(352.0), y(3.5))
        .quad_to(x(352.0), y(5.0), x(353.0), y(6.0))
        .line_to(x(411.0), y(299.0))
        .line_to(x(181.0), y(386.0))
        .quad_to(x(172.0), y(390.0), x(166.0), y(398.0))
        .quad_to(x(160.0), y(406.0), x(160.0), y(416.0))
        .quad_to(x(160.0), y(422.0), x(162.5), y(428.0))
        .quad_to(x(165.0), y(434.0), x(169.0), y(438.0))
        .line_to(x(617.0), y(918.0))
        .quad_to(x(621.0), y(923.0), x(627.0), y(925.5))
        .quad_to(x(633.0), y(928.0), x(640.0), y(928.0))
        .quad_to(x(653.0), y(928.0), x(662.5), y(918.5))
        .quad_to(x(672.0), y(909.0), x(672.0), y(896.0))
        .quad_to(x(672.0), y(895.0), x(672.0), y(893.0))
        .quad_to(x(672.0), y(891.0), x(671.0), y(890.0))
        .line_to(x(672.0), y(890.0))
        .line_to(x(613.0), y(596.0))
        .line_to(x(843.0), y(510.0))
        .quad_to(x(852.0), y(506.0), x(858.0), y(498.0))
        .quad_to(x(864.0), y(490.0), x(864.0), y(480.0))
        .quad_to(x(864.0), y(474.0), x(861.5), y(468.0))
        .quad_to(x(859.0), y(462.0), x(855.0), y(458.0))
        .close()
        .fill(faded(light, (tokens::BOLT_OPACITY * 255.0).round() as u8))
        .stroke(tokens::BOLT_OUTLINE, dark)
        .cap(Cap::Round);
    Canvas::new()
        .width(tokens::BATTERY_WIDTH)
        .height(tokens::BATTERY_HEIGHT)
        .shapes(vec![Box::new(path)])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn upower_pending_charge_and_invalid_percentages_are_handled() {
        for state in [1, 5] {
            assert!(Battery::from_upower(50.0, state).charging);
        }
        for state in [0, 2, 3, 4, 6] {
            assert!(!Battery::from_upower(50.0, state).charging);
        }
        for (percent, expected) in [
            (-10.0, 0.0),
            (50.0, 0.5),
            (120.0, 1.0),
            (f64::NAN, 0.0),
            (f64::INFINITY, 0.0),
        ] {
            assert_eq!(Battery::from_upower(percent, 2).level, expected);
        }
    }

    #[test]
    fn battery_low_charge_overrides_charging_and_light_theme_adjustment() {
        let bg = Color::BLACK;
        let fg = Color::WHITE;
        let success = Color::rgb(0, 128, 0);
        let destructive = Color::rgb(255, 0, 0);
        let mut state = Battery {
            level: 0.199,
            charging: true,
        };
        assert_eq!(
            battery_color(state, bg, fg, success, destructive),
            destructive
        );
        state.level = 0.2;
        assert_eq!(battery_color(state, bg, fg, success, destructive), success);
        state.charging = false;
        assert_eq!(battery_color(state, bg, fg, success, destructive), fg);
        state.charging = true;
        let adjusted = battery_color(state, Color::WHITE, Color::BLACK, success, destructive);
        assert!(lightness(adjusted) > lightness(success));
    }
}
