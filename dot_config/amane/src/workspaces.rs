use amane::{
    Button, Center, Cursor, Fill, Gradient, Padding, Rectangle, Row, Size, Text, Widget, children,
};

use crate::{
    design,
    minimap::Minimap,
    niri::{self, Niri},
    theme::{Theme, faded},
};

pub fn view(niri: &Niri, output: &str, theme: &Theme) -> Row {
    const SPACING: f32 = design::spacing::EXTRA_SMALL;

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
            map = Minimap::layout(niri.windows_on(workspace.id), 180.0, 16.0);
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
            theme.surface2
        };
        let background = if workspace.is_active {
            Fill::Gradient(Gradient::linear(
                0.0,
                [
                    (0.0, faded(theme.accent, 40)),
                    (1.0, faded(theme.accent, 0)),
                ],
            ))
        } else {
            Fill::Color(faded(theme.accent, 0))
        };
        let mut content = children![
            Rectangle::new()
                .width(design::workspace::CONTENT_HEIGHT)
                .height(design::workspace::CONTENT_HEIGHT)
                .align_child(Center, Center)
                .child(
                    Text::new(workspace.idx.to_string())
                        .font(&theme.font)
                        .size(theme.font_size)
                        .color(foreground),
                ),
        ];
        if map.width > 0.0 {
            content.push(Box::new(map.view(theme, 16.0)));
        }
        let content = Row::new(content).gap(SPACING).align(Center);
        let (width, left, right) = if workspace.is_active {
            let left = design::workspace::INSET;
            let right = design::workspace::RIGHT_INSET;
            let width = match Widget::width(&content) {
                Size::Fixed(width) => Size::Fixed(width + left + right),
                Size::Parent => Size::Parent,
            };
            (width, left, right)
        } else {
            (Size::Fixed(design::workspace::HEIGHT), 0.0, 0.0)
        };
        let id = workspace.id;
        buttons.push(Box::new(
            Rectangle::new()
                .width(width)
                .height(design::workspace::HEIGHT)
                .fill(background)
                .border(design::BORDER_WIDTH, border)
                .padding(Padding {
                    left,
                    right,
                    top: 0.0,
                    bottom: 0.0,
                })
                .align_child(Center, Center)
                .cursor(Cursor::Pointer)
                .on_click(move |button| {
                    if button == Button::Left {
                        niri::focus_workspace(id);
                    }
                })
                .child(content),
        ));
    }
    Row::new(buttons).gap(SPACING).align(Center)
}
