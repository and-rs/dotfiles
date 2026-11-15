use std::time::Duration;

// Fixed design values belong here; palette, fonts, and radii come from the theme.
pub const ICON_FONT: &str = "Phosphor-Bold";
pub const ICON_SIZE: f32 = size::NORMAL * 96.0 / 72.0;
pub const BORDER_WIDTH: f32 = 2.0;
pub const BAR_TEXT_SCALE: f32 = 1.05;
pub const BAR_HEIGHT: f32 = 32.0;

pub mod control_center {
    use super::{BAR_HEIGHT, padding, spacing};

    pub const WIDTH: f32 = 400.0;
    pub const HEIGHT: f32 = 280.0;
    pub const EDGE: f32 = padding::NORMAL;
    pub const TOP: f32 = BAR_HEIGHT + spacing::SMALL;
    pub const TAB_HEIGHT: f32 = BAR_HEIGHT;
    pub const PREVIEW_LINES: usize = 8;
}

pub mod indicator {
    use amane::Weight;

    use super::{BORDER_WIDTH, size};

    pub const GHOST_OPACITY: f32 = 0.55;
    pub const BATTERY_WIDTH: f32 = 30.0;
    pub const BATTERY_HEIGHT: f32 = size::NORMAL;
    pub const BATTERY_INSET: f32 = BORDER_WIDTH - 0.5;
    pub const TERMINAL_WIDTH: f32 = 2.5;
    pub const TERMINAL_HEIGHT: f32 = (BATTERY_HEIGHT - BORDER_WIDTH / 2.0) / 2.0;
    pub const BATTERY_WEIGHT: Weight = Weight::SemiBold;
    pub const BOLT_SIZE: f32 = 14.0 * 96.0 / 72.0;
    pub const BOLT_OUTLINE: f32 = 1.8;
    pub const BOLT_OPACITY: f32 = 0.9;
    pub const CHARGE_SATURATION: f32 = 1.08;
    pub const CHARGE_LIGHTNESS: f32 = 0.15;
}

pub mod size {
    pub const NORMAL: f32 = 16.0;
    pub const BUTTON: f32 = 28.0;
}

pub mod padding {
    pub const NORMAL: f32 = 10.0;
}

pub mod spacing {
    pub const EXTRA_SMALL: f32 = 4.0;
    pub const SMALL: f32 = 10.0;
    pub const MEDIUM: f32 = 16.0;
}

pub mod duration {
    use super::Duration;

    pub const EXTRA_FAST: Duration = Duration::from_millis(100);
    pub const NORMAL: Duration = Duration::from_millis(400);
    pub const SLOW: Duration = Duration::from_millis(600);
}

pub mod osd {
    use super::padding;

    pub const WIDTH: f32 = 300.0;
    pub const HEIGHT: f32 = 80.0;
    pub const PADDING: f32 = 2.0 * padding::NORMAL;
    pub const CONTENT_WIDTH: f32 = WIDTH - 2.0 * PADDING;
}
