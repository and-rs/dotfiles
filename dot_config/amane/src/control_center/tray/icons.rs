use std::{
    collections::{HashMap, HashSet},
    env, fs,
    hash::{DefaultHasher, Hash, Hasher},
    io::BufWriter,
    os::unix::fs::DirBuilderExt,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

pub(super) type Pixmap = (i32, i32, Vec<u8>);
const MAX_DIMENSION: i32 = 512;

/// SNI pixels are network-order ARGB, whereas PNG expects straight RGBA.
pub(super) fn rgba(pixmap: &Pixmap) -> Option<Vec<u8>> {
    if !valid(pixmap) {
        return None;
    }
    let (_, _, bytes) = pixmap;
    Some(
        bytes
            .as_chunks::<4>()
            .0
            .iter()
            .flat_map(|p| [p[1], p[2], p[3], p[0]])
            .collect(),
    )
}

fn valid(pixmap: &Pixmap) -> bool {
    let (width, height, bytes) = pixmap;
    if !(1..=MAX_DIMENSION).contains(width) || !(1..=MAX_DIMENSION).contains(height) {
        return false;
    }
    // The dimension bounds above make this product safe on every target.
    bytes.len() == *width as usize * *height as usize * 4
}

pub(super) struct Icons {
    directory: Option<PathBuf>,
    files: HashMap<u64, PathBuf>,
    folders: Vec<PathBuf>,
}

impl Icons {
    pub(super) fn new() -> Self {
        let directory = env::var_os("XDG_RUNTIME_DIR").and_then(|root| {
            let nonce = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .ok()?
                .as_nanos();
            let path =
                PathBuf::from(root).join(format!("amane_tray_{}_{nonce}", std::process::id()));
            fs::DirBuilder::new().mode(0o700).create(&path).ok()?;
            Some(path)
        });
        Self {
            directory,
            files: HashMap::new(),
            folders: theme_folders(),
        }
    }

    pub(super) fn resolve(
        &mut self,
        name: &str,
        theme_path: &str,
        pixmaps: &[Pixmap],
    ) -> Option<PathBuf> {
        if let Some(path) = self.named(name, theme_path) {
            return Some(path);
        }
        let pixmap = pixmaps
            .iter()
            .filter(|p| valid(p))
            .min_by_key(|(width, height, _)| {
                // Prefer the closest size at least as large as the shared icon size.
                let target = crate::design::ICON_SIZE.ceil() as i32;
                (
                    *width < target || *height < target,
                    (*width - target).abs() + (*height - target).abs(),
                )
            })?;
        let pixels = rgba(pixmap)?;
        let mut hash = DefaultHasher::new();
        pixmap.hash(&mut hash);
        let key = hash.finish();
        if let Some(path) = self.files.get(&key) {
            return Some(path.clone());
        }
        let path = self.directory.as_ref()?.join(format!("icon_{key:x}.png"));
        let file = fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&path)
            .ok()?;
        let result = (|| {
            let mut encoder =
                png::Encoder::new(BufWriter::new(file), pixmap.0 as u32, pixmap.1 as u32);
            encoder.set_color(png::ColorType::Rgba);
            encoder.set_depth(png::BitDepth::Eight);
            encoder.write_header()?.write_image_data(&pixels)
        })();
        if result.is_err() {
            let _ = fs::remove_file(&path);
            return None;
        }
        self.files.insert(key, path.clone());
        Some(path)
    }

    fn named(&self, name: &str, theme_path: &str) -> Option<PathBuf> {
        if name.is_empty() {
            return None;
        }
        let path = Path::new(name);
        if path.is_absolute() {
            return supported(path).then(|| path.to_path_buf());
        }
        // Icon names are names, not arbitrary relative filesystem paths.
        if name.contains('/') || name == "." || name == ".." {
            return None;
        }
        let extra = Path::new(theme_path);
        let mut folders = Vec::new();
        if extra.is_absolute() {
            folders.push(extra.to_path_buf());
            folders.extend(index_folders(extra));
        }
        for folder in folders.iter().chain(&self.folders) {
            for extension in ["svg", "png"] {
                let path = folder.join(format!("{name}.{extension}"));
                if supported(&path) {
                    return Some(path);
                }
            }
        }
        None
    }

    pub(super) fn retain(&mut self, used: &HashSet<PathBuf>) {
        self.files.retain(|_, path| {
            if used.contains(path) {
                return true;
            }
            let _ = fs::remove_file(path);
            false
        });
    }
}

impl Drop for Icons {
    fn drop(&mut self) {
        for path in self.files.values() {
            let _ = fs::remove_file(path);
        }
        if let Some(path) = &self.directory {
            let _ = fs::remove_dir(path);
        }
    }
}

fn supported(path: &Path) -> bool {
    matches!(
        path.extension().and_then(|e| e.to_str()),
        Some("svg" | "png")
    ) && path.is_file()
}

fn index_folders(root: &Path) -> Vec<PathBuf> {
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

fn theme_folders() -> Vec<PathBuf> {
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pixmaps_validate_dimensions_lengths_and_argb_order() {
        assert_eq!(
            rgba(&(1, 1, vec![128, 10, 20, 30])),
            Some(vec![10, 20, 30, 128])
        );
        for invalid in [
            (0, 1, vec![]),
            (-1, 1, vec![]),
            (513, 1, vec![]),
            (1, 1, vec![0; 3]),
        ] {
            assert_eq!(rgba(&invalid), None);
        }
    }

    #[test]
    fn cache_reuses_pixels_writes_rgba_and_removes_unused_files() {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let directory =
            env::temp_dir().join(format!("amane_tray_test_{}_{nonce}", std::process::id()));
        fs::DirBuilder::new()
            .mode(0o700)
            .create(&directory)
            .unwrap();
        let mut icons = Icons {
            directory: Some(directory.clone()),
            files: HashMap::new(),
            folders: vec![],
        };
        let pixmaps = vec![(1, 1, vec![128, 10, 20, 30])];
        let path = icons.resolve("", "", &pixmaps).unwrap();
        assert_eq!(icons.resolve("", "", &pixmaps), Some(path.clone()));
        let decoder = png::Decoder::new(std::io::BufReader::new(fs::File::open(&path).unwrap()));
        let mut reader = decoder.read_info().unwrap();
        let mut bytes = vec![0; reader.output_buffer_size().unwrap()];
        reader.next_frame(&mut bytes).unwrap();
        assert_eq!(bytes, [10, 20, 30, 128]);
        icons.retain(&HashSet::from([path.clone()]));
        assert!(path.is_file());
        icons.retain(&HashSet::new());
        assert!(!path.exists());
        drop(icons);
        assert!(!directory.exists());
    }
}
