use std::{
    collections::HashSet,
    env, fs,
    path::{Path, PathBuf},
};

pub fn supported(path: &Path) -> bool {
    matches!(
        path.extension().and_then(|ext| ext.to_str()),
        Some("svg" | "png")
    ) && path.is_file()
}

pub fn find<'a>(name: &str, folders: impl IntoIterator<Item = &'a PathBuf>) -> Option<PathBuf> {
    if name.is_empty() || name.contains('/') || matches!(name, "." | "..") {
        return None;
    }
    let names = [format!("{name}.svg"), format!("{name}.png")];
    for folder in folders {
        for file in &names {
            let path = folder.join(file);
            if supported(&path) {
                return Some(path);
            }
        }
    }
    None
}

pub fn index_folders(root: &Path) -> Vec<PathBuf> {
    let index = fs::read_to_string(root.join("index.theme")).unwrap_or_default();
    index
        .lines()
        .filter_map(|line| line.split_once('='))
        .filter(|(key, _)| matches!(*key, "Directories" | "ScaledDirectories"))
        .flat_map(|(_, value)| value.split(','))
        .map(str::trim)
        .filter(|part| {
            !part.is_empty()
                && !Path::new(part).is_absolute()
                && !part.split('/').any(|p| p == "..")
        })
        .map(|part| root.join(part))
        .collect()
}

pub fn theme_folders() -> Vec<PathBuf> {
    let mut data = Vec::new();
    if let Some(home) = env::var_os("HOME") {
        data.push(PathBuf::from(&home).join(".icons"));
        data.push(
            env::var_os("XDG_DATA_HOME")
                .map(PathBuf::from)
                .unwrap_or_else(|| PathBuf::from(home).join(".local/share"))
                .join("icons"),
        );
    }
    for root in env::split_paths(
        &env::var_os("XDG_DATA_DIRS").unwrap_or_else(|| "/usr/local/share:/usr/share".into()),
    ) {
        data.push(root.join("icons"));
    }
    let config = env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")));
    let selected = config
        .and_then(|root| fs::read_to_string(root.join("gtk-3.0/settings.ini")).ok())
        .and_then(|text| {
            text.lines().find_map(|line| {
                let (key, value) = line.split_once('=')?;
                (key.trim() == "gtk-icon-theme-name").then(|| value.trim().to_string())
            })
        });
    let mut themes = Vec::new();
    if let Some(selected) = selected {
        themes.push(selected);
    }
    let mut folders = Vec::new();
    let mut visited = HashSet::new();
    let mut next = 0;
    while visited.len() < 16 {
        if next == themes.len() {
            if visited.contains("hicolor") {
                break;
            }
            themes.push("hicolor".into());
        }
        let theme = themes[next].clone();
        next += 1;
        if theme.contains('/') || !visited.insert(theme.clone()) {
            continue;
        }
        for root in &data {
            let root = root.join(&theme);
            folders.extend(index_folders(&root));
            if let Ok(index) = fs::read_to_string(root.join("index.theme")) {
                for parents in index.lines().filter_map(|l| l.strip_prefix("Inherits=")) {
                    themes.extend(
                        parents
                            .split(',')
                            .map(str::trim)
                            .filter(|s| !s.is_empty())
                            .map(str::to_string),
                    );
                }
            }
        }
    }
    for root in data {
        if let Some(parent) = root.parent() {
            folders.push(parent.join("pixmaps"));
        }
    }
    folders
}
