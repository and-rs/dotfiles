//! Shared animated scrolling for intrinsically sized lists.
use std::{collections::HashMap, time::Instant};

use amane::{Padding, Rectangle, Service, Size, Start, Widget};

use crate::design::scroll as design;

struct Motion {
    context: String,
    position: f32,
    from: f32,
    target: f32,
    started: Instant,
}

impl Motion {
    fn new(context: &str, now: Instant) -> Self {
        Self {
            context: context.into(),
            position: 0.0,
            from: 0.0,
            target: 0.0,
            started: now,
        }
    }

    fn advance(&mut self, now: Instant) -> bool {
        if self.position == self.target {
            return false;
        }
        let progress = (now.saturating_duration_since(self.started).as_secs_f32()
            / design::DURATION.as_secs_f32())
        .min(1.0);
        self.position = self.from + (self.target - self.from) * (1.0 - (1.0 - progress).powi(3));
        if progress == 1.0 {
            self.position = self.target;
        }
        true
    }

    fn scroll(&mut self, lines: f32, maximum: f32, now: Instant) {
        if !lines.is_finite() {
            return;
        }
        self.advance(now);
        self.position = self.position.clamp(0.0, maximum);
        self.from = self.position;
        self.target = (self.target.clamp(0.0, maximum) + lines * design::STEP).clamp(0.0, maximum);
        self.started = now;
    }
}

#[derive(Default)]
struct Scrolls(HashMap<&'static str, Motion>);

impl Service for Scrolls {
    fn new() -> Self {
        Self::default()
    }

    fn interval() -> std::time::Duration {
        design::FRAME
    }

    fn update(&mut self) -> bool {
        let now = Instant::now();
        let mut changed = false;
        for motion in self.0.values_mut() {
            changed |= motion.advance(now);
        }
        changed
    }
}

/// Each list has a stable slot; changing context resets its offset (e.g. a submenu).
pub fn scroll_area(
    id: &'static str,
    context: impl Into<String>,
    child: impl Widget + 'static,
    width: f32,
    height: f32,
) -> Rectangle {
    let context = context.into();
    let Size::Fixed(content_height) = child.height() else {
        unreachable!("scroll content must have an intrinsic height");
    };
    let maximum = (content_height - height).max(0.0);
    let offset = Scrolls::read()
        .0
        .get(id)
        .filter(|motion| motion.context == context)
        .map_or(0.0, |motion| motion.position.clamp(0.0, maximum));
    Rectangle::new()
        .width(width)
        .height(height)
        .clip()
        .align_child(Start, Start)
        // Move layout, not just drawing, so clipped hit areas track visible rows.
        .padding(Padding {
            top: -offset,
            right: 0.0,
            bottom: 0.0,
            left: 0.0,
        })
        .on_scroll(move |scroll| {
            if !scroll.y.is_finite() || scroll.y == 0.0 {
                return;
            }
            let now = Instant::now();
            let mut state = Scrolls::write();
            let motion = state
                .0
                .entry(id)
                .or_insert_with(|| Motion::new(&context, now));
            if motion.context != context {
                *motion = Motion::new(&context, now);
            }
            motion.scroll(scroll.y, maximum, now);
        })
        .child(child)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wheel_and_fractional_input_animate_without_jumping() {
        let now = Instant::now();
        let mut motion = Motion::new("list", now);
        motion.scroll(1.0, 500.0, now);
        assert_eq!(motion.position, 0.0);
        assert_eq!(motion.target, design::STEP);
        motion.advance(now + design::DURATION / 2);
        assert!(motion.position > 0.0 && motion.position < motion.target);
        motion.advance(now + design::DURATION);
        assert_eq!(motion.position, design::STEP);
        assert!(!motion.advance(now + design::DURATION));
        motion.scroll(0.25, 500.0, now + design::DURATION);
        assert_eq!(motion.target, design::STEP * 1.25);
    }

    #[test]
    fn repeated_input_accumulates_and_reverses_from_current_position() {
        let now = Instant::now();
        let mut motion = Motion::new("list", now);
        motion.scroll(2.0, 500.0, now);
        motion.advance(now + design::DURATION / 2);
        let before = motion.position;
        motion.scroll(-2.0, 500.0, now + design::DURATION / 2);
        assert_eq!(motion.position, before);
        assert_eq!(motion.target, 0.0);
        motion.advance(now + design::DURATION * 2);
        assert_eq!(motion.position, 0.0);
    }

    #[test]
    fn bounds_shrinking_content_and_invalid_input_are_safe() {
        let now = Instant::now();
        let mut motion = Motion::new("list", now);
        motion.scroll(100.0, 90.0, now);
        assert_eq!(motion.target, 90.0);
        motion.advance(now + design::DURATION);
        motion.scroll(1.0, 20.0, now + design::DURATION);
        assert_eq!(motion.position, 20.0);
        assert_eq!(motion.target, 20.0);
        motion.scroll(f32::NAN, 20.0, now);
        assert_eq!(motion.target, 20.0);
        motion.scroll(-100.0, 20.0, now);
        assert_eq!(motion.target, 0.0);
    }
}
