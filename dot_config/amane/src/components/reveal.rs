use std::{collections::HashMap, time::Duration};

use amane::{Animation, Keyboard, LayerWindow};

use crate::design;

/// A separate presentation state for each output. Closing retains the last
/// content until it is no longer visible, not until the feature stops using it.
pub struct Reveals<T> {
    duration: Duration,
    outputs: HashMap<String, Reveal<T>>,
}

struct Reveal<T> {
    content: T,
    open: bool,
    transition: Option<Animation>,
}

pub struct Frame<T> {
    pub content: T,
    pub opacity: f32,
    open: bool,
}

impl<T> Frame<T> {
    pub fn window(&self, window: LayerWindow) -> LayerWindow {
        if self.open {
            window
        } else {
            window.keyboard(Keyboard::None).click_through()
        }
    }
}

impl<T> Default for Reveals<T> {
    fn default() -> Self {
        Self {
            duration: design::reveal::DURATION,
            outputs: HashMap::new(),
        }
    }
}

impl<T: Clone> Reveals<T> {
    pub fn frame(&mut self, output: &str, content: Option<T>) -> Option<Frame<T>> {
        self.sample(output, content, Animation::value)
    }

    fn sample(
        &mut self,
        output: &str,
        content: Option<T>,
        value: impl FnOnce(&Animation) -> f32,
    ) -> Option<Frame<T>> {
        let open = content.is_some();
        let start = |from| {
            Animation::new(from)
                .duration(self.duration)
                .easing(design::reveal::EASING)
        };
        let slot = if let Some(slot) = self.outputs.get_mut(output) {
            if let Some(content) = content {
                slot.content = content;
            }
            slot
        } else {
            self.outputs.entry(output.into()).or_insert(Reveal {
                content: content?,
                open: false,
                transition: None,
            })
        };

        let target = if open { 1.0 } else { 0.0 };
        if open != slot.open {
            let from = if slot.open { 1.0 } else { 0.0 };
            slot.transition
                .get_or_insert_with(|| start(from))
                .to(target);
            slot.open = open;
        }
        let opacity = slot.transition.as_ref().map_or(target, value);
        if opacity == target {
            slot.transition = None;
            if !open {
                self.outputs.remove(output);
                return None;
            }
        }
        Some(Frame {
            content: slot.content.clone(),
            opacity,
            open,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn closing_keeps_the_last_content_but_reopening_is_interactive() {
        let mut reveals = Reveals::default();
        let mut sample = |content, opacity| reveals.sample("one", content, |_| opacity).unwrap();
        assert!(sample(Some("first"), 0.4).open);
        let exiting = sample(None, 0.4);
        assert!(!exiting.open);
        assert_eq!(exiting.content, "first");
        let reopening = sample(Some("next"), 0.4);
        assert!(reopening.open);
        assert_eq!(reopening.content, "next");
    }

    #[test]
    fn settled_surfaces_do_not_sample_and_outputs_are_independent() {
        let mut reveals = Reveals::default();
        reveals.sample("one", Some(1), |_| 1.0).unwrap();
        let next = reveals.sample("one", Some(2), |_| panic!("already open"));
        assert_eq!(next.unwrap().content, 2);
        assert!(
            reveals
                .sample("two", None, |_| panic!("never opened"))
                .is_none()
        );
        assert!(reveals.sample("two", Some(3), |_| 1.0).unwrap().open);
        assert!(reveals.sample("one", None, |_| 0.0).is_none());
        let next = reveals.sample("two", Some(4), |_| panic!("unaffected by first output"));
        assert_eq!(next.unwrap().content, 4);
        assert!(!reveals.outputs.contains_key("one"));
    }

    #[test]
    fn zero_duration_opens_and_closes_without_intermediate_frames() {
        let mut reveals = Reveals {
            duration: Duration::ZERO,
            ..Reveals::default()
        };
        assert_eq!(reveals.frame("one", Some(())).unwrap().opacity, 1.0);
        assert!(reveals.frame("one", None).is_none());
    }
}
