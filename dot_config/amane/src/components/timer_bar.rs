use std::time::{Duration, Instant};

use amane::{Center, Parent, Rectangle, Start};

use crate::{design::timer_bar::HEIGHT, theme::Theme};

pub fn timer_bar(width: f32, deadline: Instant, duration: Duration, theme: &Theme) -> Rectangle {
    let remaining = deadline.saturating_duration_since(Instant::now());
    if !remaining.is_zero() {
        amane::request_frame();
    }
    Rectangle::new()
        .width(Parent)
        .height(HEIGHT)
        .fill(theme.surface3)
        .align_child(Start, Center)
        .child(
            Rectangle::new()
                .width(width * fraction(remaining, duration))
                .height(Parent)
                .fill(theme.accent),
        )
}

fn fraction(remaining: Duration, duration: Duration) -> f32 {
    if duration.is_zero() {
        return 0.0;
    }
    (remaining.as_secs_f32() / duration.as_secs_f32()).min(1.0)
}

#[cfg(test)]
#[test]
fn timer_fraction_is_remaining_and_bounded() {
    let second = Duration::from_secs(1);
    assert_eq!(fraction(second, second * 4), 0.25);
    assert_eq!(fraction(second * 2, second), 1.0);
    assert_eq!(fraction(Duration::ZERO, second), 0.0);
    assert_eq!(fraction(second, Duration::ZERO), 0.0);
}
