use std::time::Duration;

// Fixed design values belong here; palette, fonts, and radii come from the theme.
pub const ICON_FONT: &str = "Phosphor-Bold";
pub const ICON_SIZE: f32 = size::NORMAL * 96.0 / 72.0;
pub const BORDER_WIDTH: f32 = 2.0;
pub const BAR_HEIGHT: f32 = 32.0;
pub const CLOCK_WIDTH_REFERENCE: &str = "Wed 31 May 23:59";

pub mod workspace {
    use super::{BORDER_WIDTH, spacing};

    pub const CONTENT_HEIGHT: f32 = 24.0;
    pub const HEIGHT: f32 = CONTENT_HEIGHT;
    pub const INSET: f32 = spacing::EXTRA_SMALL + BORDER_WIDTH;
    pub const RIGHT_INSET: f32 = spacing::TINY + BORDER_WIDTH;
}

pub mod control_center {
    use super::{BAR_HEIGHT, padding, spacing};

    pub const WIDTH: f32 = 400.0;
    pub const HEIGHT: f32 = 280.0;
    pub const LIST_HEIGHT: f32 = 560.0;
    pub const EDGE: f32 = padding::NORMAL;
    pub const TOP: f32 = BAR_HEIGHT + spacing::SMALL;
    pub const TAB_HEIGHT: f32 = BAR_HEIGHT;
    pub const ROW_HEIGHT: f32 = super::button::HEIGHT;
}

pub mod typography {
    use amane::Weight;

    pub const BODY_SIZE: f32 = 14.0;
    pub const HEADLINE_SIZE: f32 = 24.0;
    pub const HEADLINE_WEIGHT: Weight = Weight::SemiBold;
    pub const BODY_WEIGHT: Weight = Weight::Medium;
    pub const SUPPORTING_WEIGHT: Weight = Weight::Regular;
}

pub mod battery {
    use super::{padding, spacing};

    pub const METER_HEIGHT: f32 = spacing::EXTRA_SMALL;
    pub const DETAIL_LABEL_WIDTH: f32 = padding::NORMAL * 8.0;
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

pub mod button {
    use amane::Padding;

    pub const HEIGHT: f32 = super::size::BUTTON + super::padding::NORMAL * 2.0;
    pub const COMPACT_HEIGHT: f32 = 32.0;
    pub const COMPACT_PADDING: Padding = Padding {
        top: super::spacing::EXTRA_SMALL,
        right: super::padding::NORMAL,
        bottom: super::spacing::EXTRA_SMALL,
        left: super::padding::NORMAL,
    };
    pub const HOVER_TINT: f32 = 0.06;
    pub const PRESSED_TINT: f32 = 0.12;
    pub const SELECTED_TINT: f32 = 0.12;
}

pub mod scroll {
    pub const STEP: f32 = super::button::HEIGHT;
    pub const DURATION: super::Duration = super::Duration::from_millis(160);
}

pub mod tray {
    pub const ICON_HALO_INSET: f32 = 5.0;
    pub const ICON_HALO_BLUR: f32 = 1.4;
    pub const ICON_HALO_OPACITY: f32 = 0.6;
}

pub mod notifications {
    use super::{Duration, padding, size, spacing};

    pub const WIDTH: f32 = super::control_center::WIDTH;
    pub const THUMBNAIL: f32 = size::BUTTON * 2.0;
    pub const THUMBNAIL_PIXELS: u32 = THUMBNAIL as u32 * 2;
    pub const ACTION_HEIGHT: f32 = size::BUTTON + spacing::EXTRA_SMALL * 2.0;
    pub const ACTION_PADDING: f32 = spacing::EXTRA_SMALL;
    pub const PROGRESS_HEIGHT: f32 = super::BORDER_WIDTH;
    pub const EDGE: f32 = padding::NORMAL;
    pub const TOP: f32 = super::BAR_HEIGHT + spacing::SMALL;
    pub const POPUP_TIMEOUT: Duration = Duration::from_secs(5);
    pub const UNDO: Duration = Duration::from_secs(4);
}

pub mod padding {
    pub const NORMAL: f32 = 10.0;
}

pub mod spacing {
    pub const TINY: f32 = 3.0;
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
