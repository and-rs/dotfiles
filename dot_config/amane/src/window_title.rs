use amane::{Center, Parent, Rectangle, Row, Size, Start, Text, Weight, Widget};
use niri_ipc::Window;

use crate::{design, niri::Niri, theme::Theme};

fn labels(window: Option<&Window>) -> (&str, Option<&str>) {
    let Some(window) = window else {
        return ("", None);
    };
    let app = window.app_id.as_deref().filter(|app| !app.is_empty());
    let Some(title) = window.title.as_deref().filter(|title| !title.is_empty()) else {
        return (app.unwrap_or_default(), None);
    };
    (title, app.filter(|app| *app != title))
}

pub fn view(niri: &Niri, output: &str, theme: &Theme, width: f32) -> Rectangle {
    let (title, app) = labels(niri.active_window(output));
    let label = |value| {
        Text::new(value)
            .font(&theme.font)
            .size(design::typography::BODY_SIZE)
            .weight(Weight::Medium)
    };
    let title = label(title).color(theme.fg);
    let app = app.map(|app| label(app).color(theme.surface4));
    let gap = design::spacing::SMALL;
    let app_width = app.as_ref().map_or(0.0, |app| {
        natural_width(app).min((width - gap).max(0.0) / 2.0)
    });
    let title_width = if app_width > 0.0 {
        width - app_width - gap
    } else {
        width
    };
    let slot = |text: Text, width: f32| {
        Rectangle::new()
            .width(width)
            .height(Parent)
            .align_child(Start, Center)
            .child(text.elide().max_lines(1))
    };
    let title_width = natural_width(&title).min(title_width);
    let mut children = amane::children![slot(title, title_width)];
    if let Some(app) = app.filter(|_| app_width > 0.0) {
        children.push(Box::new(slot(app, app_width)));
    }
    Rectangle::new()
        .width(Parent)
        .height(Parent)
        .align_child(Start, Center)
        .clip()
        .child(Row::new(children).height(Parent).gap(gap))
}

fn natural_width(text: &Text) -> f32 {
    let Size::Fixed(width) = text.width() else {
        unreachable!("unwrapped text has intrinsic width");
    };
    width
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::niri::tests::window;

    #[test]
    fn title_falls_back_to_app_id_then_empty() {
        let mut win = window(1, 1, 1, 1);
        assert_eq!(labels(Some(&win)), ("window 1", Some("test")));
        win.title = Some("test".into());
        assert_eq!(labels(Some(&win)), ("test", None));
        win.title = Some(String::new());
        assert_eq!(labels(Some(&win)), ("test", None));
        win.title = None;
        win.app_id = None;
        assert_eq!(labels(Some(&win)), ("", None));
        assert_eq!(labels(None), ("", None));
    }
}
