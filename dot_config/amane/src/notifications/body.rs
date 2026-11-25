use std::{process::Command, sync::Arc, thread};

use amane::{
    Button, Center, Column, Cursor, End, Parent, Rectangle, Row, Size, Start, Text, Weight, Widget,
};

use crate::{design, theme::Theme};

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub(super) struct Style {
    bold: bool,
    underline: bool,
    link: Option<Arc<str>>,
}

pub(super) enum Body {
    Plain(String),
    Styled(Vec<(String, Style)>),
}

impl Body {
    pub(super) fn parse(text: String) -> Self {
        if !text.contains(['<', '&']) {
            return Self::Plain(text);
        }
        let fragment = format!("<body>{text}</body>");
        let options = roxmltree::ParsingOptions {
            nodes_limit: 512,
            ..Default::default()
        };
        let Ok(doc) = roxmltree::Document::parse_with_options(&fragment, options) else {
            return Self::Plain(text);
        };
        let mut styled = Vec::new();
        for child in doc.root_element().children() {
            collect(child, Style::default(), &mut styled);
        }
        if styled.iter().all(|(_, style)| *style == Style::default()) {
            return Self::Plain(styled.into_iter().map(|(value, _)| value).collect());
        }
        Self::Styled(styled)
    }

    pub(super) fn view(&self, theme: &Theme, width: f32, limit: usize) -> Option<Rectangle> {
        if width <= 0.0 {
            return None;
        }
        let styled = match self {
            Self::Styled(styled) => styled,
            Self::Plain(plain) => {
                if plain.is_empty() {
                    return None;
                }
                let text = label(plain, &Style::default(), theme)
                    .wrap()
                    .elide()
                    .max_lines(limit);
                return Some(
                    Rectangle::new()
                        .width(Parent)
                        .height(text.height_in(width))
                        .child(text),
                );
            }
        };
        let (lines, elided) = lines(styled, theme, width, limit);
        let height = label("M", &Style::default(), theme).height_in(width);
        let mut rows: Vec<Box<dyn Widget>> = Vec::new();
        let last = lines.len().saturating_sub(1);
        for (index, line) in lines.into_iter().enumerate() {
            let mut pieces: Vec<Box<dyn Widget>> = line
                .into_iter()
                .map(|piece| Box::new(piece.view(theme, height)) as Box<dyn Widget>)
                .collect();
            if elided && index == last {
                pieces.push(Box::new(label("…", &Style::default(), theme)));
            }
            rows.push(Box::new(Row::new(pieces).width(Parent).height(height)));
        }
        let content = Column::new(rows).width(Parent);
        Some(
            Rectangle::new()
                .width(Parent)
                .height(Widget::height(&content))
                .child(content),
        )
    }
}

fn lines<'a>(
    styled: &'a [(String, Style)],
    theme: &Theme,
    width: f32,
    limit: usize,
) -> (Vec<Vec<Piece<'a>>>, bool) {
    let mut lines = vec![Vec::new()];
    let mut used = 0.0;
    let mut elided = false;
    'body: for (value, style) in styled {
        let measure = |value| text_width(&label(value, style, theme));
        for (index, line) in value.split('\n').enumerate() {
            if index > 0 {
                if lines.len() == limit {
                    elided = true;
                    break 'body;
                }
                lines.push(Vec::new());
                used = 0.0;
            }
            for word in line.split_inclusive(char::is_whitespace) {
                let mut rest = word;
                loop {
                    let trimmed = rest.trim_end();
                    let trimmed_width = measure(trimmed);
                    if used + trimmed_width > width && used > 0.0 {
                        if lines.len() == limit {
                            elided = true;
                            break 'body;
                        }
                        lines.push(Vec::new());
                        used = 0.0;
                    }
                    let mut end = rest.len();
                    if trimmed_width > width {
                        end = rest
                            .char_indices()
                            .skip(1)
                            .take_while(|(end, _)| measure(&rest[..*end]) <= width)
                            .last()
                            .map_or_else(
                                || rest.chars().next().unwrap().len_utf8(),
                                |(end, _)| end,
                            );
                    }
                    let value = &rest[..end];
                    let measured = if value.len() == trimmed.len() {
                        trimmed_width
                    } else {
                        measure(value)
                    };
                    let size = measured.min((width - used).max(0.0));
                    lines.last_mut().unwrap().push(Piece {
                        value,
                        style,
                        width: size,
                    });
                    used += size;
                    rest = &rest[end..];
                    if rest.is_empty() {
                        break;
                    }
                }
            }
        }
    }
    if elided {
        let available = (width - text_width(&label("…", &Style::default(), theme))).max(0.0);
        let line = lines.last_mut().unwrap();
        while line.iter().map(|piece| piece.width).sum::<f32>() > available {
            line.pop();
        }
    }
    (lines, elided)
}

fn collect(node: roxmltree::Node<'_, '_>, mut style: Style, styled: &mut Vec<(String, Style)>) {
    if node.is_text() {
        push(styled, node.text().unwrap_or_default(), style);
        return;
    }
    if !node.is_element() {
        return;
    }
    match node.tag_name().name() {
        "b" => style.bold = true,
        "u" => style.underline = true,
        "a" => {
            style.link = node
                .attribute("href")
                .filter(|url| web_url(url))
                .map(Arc::from)
        }
        "br" => return push(styled, "\n", style),
        "img" => {
            return push(
                styled,
                node.attribute("alt").unwrap_or_default(),
                Style::default(),
            );
        }
        _ => {}
    }
    for child in node.children() {
        collect(child, style.clone(), styled);
    }
}

fn push(styled: &mut Vec<(String, Style)>, value: &str, style: Style) {
    if let Some((text, _)) = styled.last_mut().filter(|(_, last)| *last == style) {
        text.push_str(value);
    } else if !value.is_empty() {
        styled.push((value.into(), style));
    }
}

fn web_url(url: &str) -> bool {
    let Some((scheme, rest)) = url.split_once("://") else {
        return false;
    };
    let authority = rest.split(['/', '?', '#']).next().unwrap_or_default();
    (scheme.eq_ignore_ascii_case("https") || scheme.eq_ignore_ascii_case("http"))
        && !authority.is_empty()
        && !authority.contains('@')
        && !url.contains(|c: char| c.is_whitespace() || c.is_control() || c == '\\')
}

fn open_link(url: &str) {
    match Command::new("xdg-open").arg(url).spawn() {
        Ok(mut child) => {
            thread::spawn(move || match child.wait() {
                Ok(status) if status.success() => {}
                Ok(status) => eprintln!("notification link: xdg-open exited with {status}"),
                Err(error) => eprintln!("notification link: {error}"),
            });
        }
        Err(error) => eprintln!("notification link: could not start xdg-open: {error}"),
    }
}

fn label(value: &str, style: &Style, theme: &Theme) -> Text {
    let mut text = Text::new(value)
        .font(&theme.font)
        .size(design::typography::BODY_SIZE);
    if style.bold {
        text = text.weight(Weight::Bold);
    }
    text.color(if style.link.is_some() {
        theme.accent
    } else {
        theme.fg
    })
}

fn text_width(text: &Text) -> f32 {
    let Size::Fixed(width) = text.width() else {
        unreachable!("unwrapped text has intrinsic width");
    };
    width
}

struct Piece<'a> {
    value: &'a str,
    style: &'a Style,
    width: f32,
}

impl Piece<'_> {
    fn view(self, theme: &Theme, height: f32) -> Rectangle {
        let mut content = Rectangle::new().width(self.width).height(height).clip();
        let text = label(self.value, self.style, theme);
        if self.style.underline || self.style.link.is_some() {
            let ink = if self.style.link.is_some() {
                theme.accent
            } else {
                theme.fg
            };
            let underline = Rectangle::new()
                .width(Parent)
                .height(design::notifications::LINK_UNDERLINE)
                .fill(ink);
            content = content.child(amane::Stack::new(amane::children![
                text,
                Rectangle::new()
                    .width(Parent)
                    .height(Parent)
                    .align_child(Start, End)
                    .child(underline)
            ]));
        } else {
            content = content.align_child(Start, Center).child(text);
        }
        if let Some(url) = self.style.link.clone() {
            content = content.cursor(Cursor::Pointer).on_click(move |button| {
                if button == Button::Left {
                    open_link(&url);
                }
            });
        }
        content
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn markup_keeps_text_and_only_activates_web_links() {
        let body = Body::parse(r#"<b>Bold <a href="https://example.com/?a=1&amp;b=2">link</a></b><br/><img src="https://example.org" alt="image"/><a href="file:///etc/passwd"> blocked</a>"#.into());
        let Body::Styled(styled) = body else {
            panic!("expected styled text")
        };
        assert_eq!(
            styled
                .iter()
                .map(|(value, _)| value.as_str())
                .collect::<String>(),
            "Bold link\nimage blocked"
        );
        let (_, style) = &styled[1];
        assert!(style.bold);
        assert_eq!(style.link.as_deref(), Some("https://example.com/?a=1&b=2"));
        assert_eq!(
            styled
                .iter()
                .filter(|(_, style)| style.link.is_some())
                .count(),
            1
        );
        for url in [
            "https://",
            "http://host\\file",
            "https://someone@example.com",
            "javascript:alert(1)",
            "data:text/html,test",
        ] {
            assert!(!web_url(url));
        }
    }

    #[test]
    fn malformed_fragments_are_plain_text() {
        let body = Body::parse("<b>unfinished & literal".into());
        assert!(matches!(body, Body::Plain(text) if text == "<b>unfinished & literal"));
        let decoded = Body::parse("<i>plain &amp; decoded</i>".into());
        assert!(matches!(decoded, Body::Plain(text) if text == "plain & decoded"));
    }

    #[test]
    fn wrapped_links_keep_targets_within_the_line_budget() {
        let theme: Theme = serde_json::from_value(serde_json::json!({
            "bg": "#ffffff", "fg": "#000000", "accent": "#0000ff",
            "success": "#008000", "destructive": "#ff0000",
            "surface1": "#eeeeee", "surface2": "#dddddd", "surface3": "#cccccc",
            "surface4": "#666666", "font": "sans-serif",
            "radius": { "small": 2.0, "normal": 4.0, "large": 6.0 }
        }))
        .unwrap();
        let body = Body::parse("<a href='https://example.com'>A wrapped link with enough words to reach the line limit</a>".into());
        let width = 60.0;
        let Body::Styled(styled) = body else {
            panic!("expected a styled link")
        };
        let (lines, elided) = lines(&styled, &theme, width, 3);
        assert!(elided);
        assert_eq!(lines.len(), 3);
        assert!(
            lines
                .iter()
                .all(|line| line.iter().map(|piece| piece.width).sum::<f32>() <= width)
        );
        assert!(
            lines
                .iter()
                .take(2)
                .all(|line| line.iter().any(|piece| piece.style.link.is_some()))
        );
    }
}
