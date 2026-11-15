use std::time::Duration;

// Fixed design values belong here; palette, fonts, and radii come from the theme.
pub const ICON_FONT: &str = "Phosphor-Bold";
pub const ICON_SIZE: f32 = size::NORMAL * 96.0 / 72.0;
pub const BORDER_WIDTH: f32 = 2.0;

pub mod size {
    pub const NORMAL: f32 = 16.0;
}

pub mod padding {
    pub const NORMAL: f32 = 10.0;
}

pub mod spacing {
    pub const SMALL: f32 = 10.0;
}

pub mod duration {
    use super::Duration;

    pub const EXTRA_FAST: Duration = Duration::from_millis(100);
    pub const SLOW: Duration = Duration::from_millis(600);
}

pub mod osd {
    use super::padding;

    pub const WIDTH: f32 = 300.0;
    pub const HEIGHT: f32 = 80.0;
    pub const PADDING: f32 = 2.0 * padding::NORMAL;
    pub const CONTENT_WIDTH: f32 = WIDTH - 2.0 * PADDING;
}
