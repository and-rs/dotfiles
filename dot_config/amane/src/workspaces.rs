use amane::{Button, Center, Cursor, Fill, Gradient, Rectangle, Row, Text, Widget, children};

use crate::{
    minimap::Minimap,
    niri::{self, Niri},
    theme::{Theme, faded},
};

pub fn view(niri: &Niri, output: &str, theme: &Theme) -> Row {
    if !niri.ready() {
        return Row::new(children![
            Text::new("niri unavailable")
                .font(&theme.font)
                .size(theme.font_size)
                .color(faded(theme.fg, 140)),
        ]);
    }
    let mut buttons: Vec<Box<dyn Widget>> = Vec::new();
    for workspace in niri.workspaces_on(output) {
        let mut map = Minimap::default();
        if workspace.is_active {
            map = Minimap::layout(
                niri.windows_on(workspace.id),
                workspace.active_window_id,
                180.0,
                16.0,
            );
        }
        let occupied = niri.windows_on(workspace.id).next().is_some();
        let foreground = if workspace.is_active || workspace.is_urgent {
            theme.accent
        } else if occupied {
            theme.fg
        } else {
            faded(theme.fg, 100)
        };
        let border = if workspace.is_focused || workspace.is_urgent {
            theme.accent
        } else if workspace.is_active {
            faded(theme.accent, 150)
        } else {
            faded(theme.fg, 50)
        };
        let background = if workspace.is_active {
            Fill::Gradient(Gradient::linear(
                0.0,
                [
                    (0.0, faded(theme.accent, 50)),
                    (1.0, faded(theme.accent, 0)),
                ],
            ))
        } else {
            Fill::Color(faded(theme.accent, 0))
        };
        let mut width = 28.0;
        let mut content = children![
            Rectangle::new()
                .width(24.0)
                .height(24.0)
                .align_child(Center, Center)
                .child(
                    Text::new(workspace.idx.to_string())
                        .font(&theme.font)
                        .size(theme.font_size)
                        .color(foreground),
                ),
        ];
        if map.width > 0.0 {
            width += map.width + 6.0;
            content.push(Box::new(map.view(theme, 16.0)));
        }
        let id = workspace.id;
        buttons.push(Box::new(
            Rectangle::new()
                .width(width)
                .height(24.0)
                .fill(background)
                .border(1.0, border)
                .align_child(Center, Center)
                .cursor(Cursor::Pointer)
                .on_click(move |button| {
                    if button == Button::Left {
                        niri::focus_workspace(id);
                    }
                })
                .child(Row::new(content).gap(4.0).align(Center)),
        ));
    }
    Row::new(buttons).gap(4.0).align(Center)
}
