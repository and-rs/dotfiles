//! Shared scrolling for intrinsically sized lists.
use std::{collections::HashMap, time::Instant};

use amane::{Padding, Rectangle, Service, Size, Start, Widget};

use crate::design::scroll as design;

struct Motion {
    context: String,
    position: f32,
    from: f32,
    target: f32,
    started: Instant,
    rows: Vec<(u32, f32)>,
}

impl Motion {
    fn new(context: &str, now: Instant) -> Self {
        Self {
            context: context.into(),
            position: 0.0,
            from: 0.0,
            target: 0.0,
            started: now,
            rows: Vec::new(),
        }
    }

    fn advance(&mut self, now: Instant) -> bool {
        if self.position == self.target {
            return false;
        }
        self.position = self.position_at(now);
        true
    }

    fn position_at(&self, now: Instant) -> f32 {
        let progress = (now.saturating_duration_since(self.started).as_secs_f32()
            / design::DURATION.as_secs_f32())
        .min(1.0);
        if progress == 1.0 {
            return self.target;
        }
        self.from + (self.target - self.from) * (1.0 - (1.0 - progress).powi(3))
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

    fn scroll_directly(&mut self, lines: f32, maximum: f32, now: Instant) {
        self.scroll(lines, maximum, now);
        self.position = self.target;
        self.from = self.target;
    }

    fn reanchor(&mut self, rows: &[(u32, f32)], maximum: f32, now: Instant) {
        self.advance(now);
        let mut delta = 0.0;
        if self.position > 0.0
            && let Some(anchor) = self.rows.iter().rposition(|(_, top)| *top <= self.position)
        {
            // If the visible row disappeared, use the next surviving neighbour.
            delta = self.rows[anchor..]
                .iter()
                .chain(self.rows[..anchor].iter().rev())
                .find_map(|(id, old)| {
                    rows.iter()
                        .find(|(next, _)| next == id)
                        .map(|(_, new)| new - old)
                })
                .unwrap_or_default();
        }
        self.position = (self.position + delta).clamp(0.0, maximum);
        self.from = self.position;
        self.target = (self.target + delta).clamp(0.0, maximum);
        self.started = now;
        self.rows = rows.to_vec();
    }
}

#[derive(Default)]
struct Scrolls(HashMap<&'static str, Motion>);

impl Service for Scrolls {
    fn new() -> Self {
        Self::default()
    }

    fn listen() {}
}

/// Each list has a stable slot; changing context resets its offset (e.g. a submenu).
pub fn scroll_area(
    id: &'static str,
    context: impl Into<String>,
    child: impl Widget + 'static,
    width: f32,
    height: f32,
) -> Rectangle {
    let Size::Fixed(content_height) = child.height() else {
        unreachable!("scroll content must have an intrinsic height");
    };
    viewport(
        id,
        context,
        (width, height),
        content_height,
        Vec::new(),
        Motion::scroll,
        |_| child,
    )
}

/// Direct scrolling with stable row anchors, for lists that mount only visible widgets.
pub fn anchored_scroll_area<W: Widget + 'static>(
    id: &'static str,
    context: impl Into<String>,
    width: f32,
    height: f32,
    content_height: f32,
    rows: Vec<(u32, f32)>,
    build: impl FnOnce(f32) -> W,
) -> Rectangle {
    viewport(
        id,
        context,
        (width, height),
        content_height,
        rows,
        Motion::scroll_directly,
        build,
    )
}

fn viewport<W: Widget + 'static>(
    id: &'static str,
    context: impl Into<String>,
    (width, height): (f32, f32),
    content_height: f32,
    rows: Vec<(u32, f32)>,
    scroll_by: fn(&mut Motion, f32, f32, Instant),
    build: impl FnOnce(f32) -> W,
) -> Rectangle {
    let context = context.into();
    let maximum = (content_height - height).max(0.0);
    let now = Instant::now();
    let (mut offset, mut target, changed) = {
        let scrolls = Scrolls::read();
        scrolls
            .0
            .get(id)
            .filter(|motion| motion.context == context)
            .map_or((0.0, 0.0, false), |motion| {
                (
                    motion.position_at(now).clamp(0.0, maximum),
                    motion.target.clamp(0.0, maximum),
                    motion.rows != rows,
                )
            })
    };
    if changed {
        let mut scrolls = Scrolls::write();
        if let Some(motion) = scrolls.0.get_mut(id) {
            motion.reanchor(&rows, maximum, now);
            offset = motion.position;
            target = motion.target;
        }
    }
    if offset != target {
        amane::request_frame();
    }
    let child = build(offset);
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
            if motion.rows != rows {
                motion.reanchor(&rows, maximum, now);
            }
            scroll_by(motion, scroll.y, maximum, now);
        })
        .child(child)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn prepend_and_removal_keep_visible_rows_stationary_but_leave_top_pinned() {
        let now = Instant::now();
        let mut motion = Motion::new("history", now);
        motion.reanchor(&[(2, 0.0), (1, 60.0), (0, 120.0)], 300.0, now);
        motion.reanchor(&[(3, 0.0), (2, 80.0), (1, 140.0), (0, 200.0)], 300.0, now);
        assert_eq!(motion.position, 0.0);
        motion.scroll_directly(1.0, 300.0, now);
        motion.reanchor(
            &[(4, 0.0), (3, 60.0), (2, 140.0), (1, 200.0), (0, 260.0)],
            300.0,
            now,
        );
        assert_eq!(motion.position, design::STEP + 60.0);
        motion.reanchor(&[(4, 0.0), (2, 60.0), (1, 120.0), (0, 180.0)], 300.0, now);
        assert_eq!(motion.position, design::STEP - 20.0);
    }

    #[test]
    fn direct_scroll_moves_immediately_and_preserves_fractional_input() {
        let now = Instant::now();
        let mut motion = Motion::new("history", now);
        motion.scroll_directly(1.25, 500.0, now);
        assert_eq!(motion.position_at(now), design::STEP * 1.25);
        assert_eq!(motion.position, motion.target);
        assert!(!motion.advance(now + design::DURATION / 2));
        motion.scroll_directly(-0.25, 500.0, now);
        assert_eq!(motion.position_at(now), design::STEP);
    }

    #[test]
    fn wheel_and_fractional_input_animate_without_jumping() {
        let now = Instant::now();
        let mut motion = Motion::new("list", now);
        motion.scroll(1.0, 500.0, now);
        assert_eq!(motion.position, 0.0);
        assert_eq!(motion.target, design::STEP);
        let frame = motion.position_at(now + design::DURATION / 2);
        assert!(frame > 0.0 && frame < motion.target);
        assert_eq!(motion.position_at(now + design::DURATION), motion.target);
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
