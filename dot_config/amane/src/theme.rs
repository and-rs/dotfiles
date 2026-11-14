use std::{env, fs, path::Path};

use amane::{Color, Service};
use serde::{Deserialize, Deserializer, de::Error};

#[derive(Debug, Deserialize, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct Theme {
    #[serde(deserialize_with = "color")]
    pub bg: Color,
    #[serde(deserialize_with = "color")]
    pub fg: Color,
    #[serde(deserialize_with = "color")]
    pub accent: Color,
    pub font: String,
    pub font_size: f32,
}

pub fn faded(color: Color, alpha: u8) -> Color {
    let alpha = (u16::from(color.alpha()) * u16::from(alpha) / 255) as u8;
    Color::rgba(color.red(), color.green(), color.blue(), alpha)
}

impl Theme {
    fn parse(json: &str) -> Result<Self, String> {
        let theme: Self = serde_json::from_str(json).map_err(|error| error.to_string())?;
        if theme.font.trim().is_empty() {
            return Err("font must not be empty".into());
        }
        if !(8.0..=24.0).contains(&theme.font_size) {
            return Err("font_size must be between 8 and 24 pixels".into());
        }
        Ok(theme)
    }

    fn load(path: &Path) -> Result<Self, String> {
        let json = fs::read_to_string(path).map_err(|error| error.to_string())?;
        Self::parse(&json)
    }
}

fn color<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Color, D::Error> {
    let value = String::deserialize(deserializer)?;
    let digits = value.strip_prefix('#').unwrap_or("");
    if !matches!(digits.len(), 6 | 8) || !digits.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err(D::Error::custom("expected #RRGGBB or #RRGGBBAA"));
    }
    Ok(Color::from(value.as_str()))
}

pub struct ThemeState {
    path: String,
    pub theme: Theme,
}

impl ThemeState {
    fn reload() {
        let path = Self::read().path.clone();
        // File IO and parsing happen without holding the UI's state lock.
        match Theme::load(Path::new(&path)) {
            Ok(theme) => {
                let changed = Self::read().theme != theme;
                if changed {
                    Self::write().theme = theme;
                    eprintln!("theme reloaded: {path}");
                }
            }
            Err(error) => eprintln!("keeping previous theme: {path}: {error}"),
        }
    }
}

impl Service for ThemeState {
    fn new() -> Self {
        let path = env::var_os("AMANE_THEME")
            .map(std::path::PathBuf::from)
            .unwrap_or_else(|| {
                let config = env::var_os("XDG_CONFIG_HOME")
                    .map(std::path::PathBuf::from)
                    .unwrap_or_else(|| {
                        std::path::PathBuf::from(env::var_os("HOME").expect("HOME is not set"))
                            .join(".config")
                    });
                config.join("amane/theme.json")
            });
        let theme = Theme::load(&path)
            .unwrap_or_else(|error| panic!("failed to load theme {}: {error}", path.display()));
        Self {
            path: path
                .into_os_string()
                .into_string()
                .expect("theme path must be UTF-8"),
            theme,
        }
    }

    fn listen() {
        let path = Self::read().path.clone();
        // Amane watches the parent directory, so atomic editor saves work too.
        let changes = amane::watch_file(&path);
        // Close the gap between the initial read and installing the watch.
        Self::reload();
        for () in changes {
            Self::reload();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const VALID: &str =
        r##"{"bg":"#101820","fg":"#ffffff","accent":"#80c0ff","font":"Inter","font_size":14}"##;

    #[test]
    fn parses_colors_and_typography() {
        let theme = Theme::parse(VALID).unwrap();
        assert_eq!(theme.bg, Color::rgb(16, 24, 32));
        assert_eq!(theme.fg, Color::WHITE);
        assert_eq!(theme.font, "Inter");
        assert_eq!(theme.font_size, 14.0);
        let transparent = VALID.replace("#101820", "#10182080");
        assert_eq!(Theme::parse(&transparent).unwrap().bg.alpha(), 128);
    }

    #[test]
    fn rejects_invalid_edits() {
        for json in [
            VALID.replace("#101820", "oops"),
            VALID.replace("#101820", "#１２３"),
            VALID.replace("\"Inter\"", "\" \""),
            VALID.replace(":14", ":0"),
            VALID.replace(":14", ":25"),
            VALID.replace("\"font_size\"", "\"font_szie\""),
            VALID[..VALID.len() - 1].to_string(),
        ] {
            assert!(Theme::parse(&json).is_err(), "accepted {json}");
        }
    }
}
