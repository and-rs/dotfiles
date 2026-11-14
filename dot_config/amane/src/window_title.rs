use amane::{Center, Parent, Rectangle, Start, Text};
use niri_ipc::Window;

use crate::{niri::Niri, theme::Theme};

fn label(window: Option<&Window>) -> &str {
    let Some(window) = window else {
        return "";
    };
    if let Some(title) = window.title.as_deref().filter(|title| !title.is_empty()) {
        return title;
    }
    window.app_id.as_deref().unwrap_or("")
}

pub fn view(niri: &Niri, output: &str, theme: &Theme) -> Rectangle {
    Rectangle::new()
        .width(Parent)
        .height(Parent)
        .align_child(Start, Center)
        .clip()
        .child(
            Text::new(label(niri.active_window(output)))
                .font(&theme.font)
                .size(theme.font_size)
                .color(theme.fg)
                .elide()
                .max_lines(1),
        )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::niri::tests::window;

    #[test]
    fn title_falls_back_to_app_id_then_empty() {
        let mut win = window(1, 1, 1, 1);
        assert_eq!(label(Some(&win)), "window 1");
        win.title = Some(String::new());
        assert_eq!(label(Some(&win)), "test");
        win.title = None;
        win.app_id = None;
        assert_eq!(label(Some(&win)), "");
        assert_eq!(label(None), "");
    }
}
