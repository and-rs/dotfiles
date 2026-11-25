use std::{
    collections::{HashMap, HashSet},
    env, fs,
    hash::{DefaultHasher, Hash, Hasher},
    io::BufWriter,
    os::unix::fs::DirBuilderExt,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

use amane::Color;

use crate::{
    design::{self, tray as layout},
    icon_theme::{self, index_folders, supported, theme_folders},
};

pub(super) type Pixmap = (i32, i32, Vec<u8>);
const MAX_DIMENSION: i32 = 512;

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct Icon {
    pub source: PathBuf,
    pub halo: Option<PathBuf>,
}

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
    pub(super) halo_color: Option<Color>,
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
            halo_color: None,
        }
    }

    pub(super) fn resolve(
        &mut self,
        name: &str,
        theme_path: &str,
        pixmaps: &[Pixmap],
    ) -> Option<Icon> {
        let source = self.source(name, theme_path, pixmaps)?;
        let halo = self
            .halo_color
            .and_then(|color| self.with_halo(&source, color));
        Some(Icon { source, halo })
    }

    fn with_halo(&mut self, source: &Path, color: Color) -> Option<PathBuf> {
        let source = source.canonicalize().ok()?;
        let metadata = fs::metadata(&source).ok()?;
        let mut hash = DefaultHasher::new();
        (
            "halo",
            &source,
            metadata.len(),
            metadata.modified().ok()?,
            color.hex(),
        )
            .hash(&mut hash);
        let key = hash.finish();
        if let Some(path) = self.files.get(&key) {
            return Some(path.clone());
        }
        let path = self.directory.as_ref()?.join(format!("halo_{key:x}.svg"));
        let svg = halo_svg(&source, color)?;
        let mut file = fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&path)
            .ok()?;
        if std::io::Write::write_all(&mut file, svg.as_bytes()).is_err() {
            let _ = fs::remove_file(&path);
            return None;
        }
        self.files.insert(key, path.clone());
        Some(path)
    }

    fn source(&mut self, name: &str, theme_path: &str, pixmaps: &[Pixmap]) -> Option<PathBuf> {
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
        icon_theme::find(name, folders.iter().chain(&self.folders))
    }

    pub(super) fn retain<'a>(&mut self, icons: impl IntoIterator<Item = &'a Icon>) {
        let used: HashSet<_> = icons
            .into_iter()
            .flat_map(|icon| std::iter::once(&icon.source).chain(icon.halo.as_ref()))
            .collect();
        self.files.retain(|_, path| {
            if used.contains(path) {
                return true;
            }
            let _ = fs::remove_file(path);
            false
        });
    }
}

fn halo_svg(source: &Path, color: Color) -> Option<String> {
    let source = source
        .to_str()?
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;");
    let inset = layout::ICON_HALO_INSET;
    let width = design::ICON_SIZE + inset * 2.0;
    let height = design::size::BUTTON + inset * 2.0;
    let icon_width = design::ICON_SIZE;
    let icon_height = design::size::BUTTON;
    let blur = layout::ICON_HALO_BLUR;
    let opacity = layout::ICON_HALO_OPACITY;
    let color = color.hex();
    Some(format!(
        r##"<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<defs><filter id="halo" filterUnits="userSpaceOnUse" x="0" y="0" width="{width}" height="{height}" color-interpolation-filters="sRGB">
<feGaussianBlur in="SourceAlpha" stdDeviation="{blur}" result="blur"/>
<feFlood flood-color="{color}" flood-opacity="{opacity}" result="ink"/>
 <feComposite in="ink" in2="blur" operator="in"/>
</filter></defs>
<image x="{inset}" y="{inset}" width="{icon_width}" height="{icon_height}" xlink:href="{source}" filter="url(#halo)"/>
</svg>"##
    ))
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
            halo_color: None,
        };
        let pixmaps = vec![(1, 1, vec![128, 10, 20, 30])];
        let icon = icons.resolve("", "", &pixmaps).unwrap();
        assert_eq!(icons.resolve("", "", &pixmaps).as_ref(), Some(&icon));
        let path = &icon.source;
        let decoder = png::Decoder::new(std::io::BufReader::new(fs::File::open(path).unwrap()));
        let mut reader = decoder.read_info().unwrap();
        let mut bytes = vec![0; reader.output_buffer_size().unwrap()];
        reader.next_frame(&mut bytes).unwrap();
        assert_eq!(bytes, [10, 20, 30, 128]);
        icons.halo_color = Some(Color::WHITE);
        let light = icons.resolve("", "", &pixmaps).unwrap();
        let halo = light.halo.as_ref().unwrap();
        assert_eq!(icons.resolve("", "", &pixmaps).as_ref(), Some(&light));
        let raster = rasterize(halo);
        let center = raster.pixel(raster.width() / 2, raster.height() / 2).unwrap();
        assert!(center.alpha() > 0 && center.alpha() < 128);
        assert_eq!(center.red(), center.alpha(), "only the white halo is drawn");
        icons.retain([&light]);
        assert!(path.is_file(), "a retained SVG must keep its source PNG");
        assert!(halo.is_file());
        icons.halo_color = Some(Color::BLACK);
        let dark = icons.resolve("", "", &pixmaps).unwrap();
        assert_ne!(dark.halo.as_ref().unwrap(), halo);
        icons.retain([&dark]);
        assert!(!halo.exists());
        assert!(path.is_file());
        icons.retain([&icon]);
        assert!(path.is_file());
        icons.retain([]);
        assert!(!path.exists());
        drop(icons);
        assert!(!directory.exists());
    }

    fn rasterize(path: &Path) -> resvg::tiny_skia::Pixmap {
        let bytes = fs::read(path).unwrap();
        let tree = resvg::usvg::Tree::from_data(&bytes, &resvg::usvg::Options::default()).unwrap();
        let size = tree.size().to_int_size();
        let mut raster = resvg::tiny_skia::Pixmap::new(size.width(), size.height()).unwrap();
        resvg::render(
            &tree,
            resvg::tiny_skia::Transform::identity(),
            &mut raster.as_mut(),
        );
        raster
    }

    #[test]
    fn halo_follows_svg_silhouette_without_drawing_artwork() {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let directory =
            env::temp_dir().join(format!("amane_halo_test_{}_{nonce}", std::process::id()));
        fs::DirBuilder::new()
            .mode(0o700)
            .create(&directory)
            .unwrap();
        let source = directory.join("source_&'\".svg");
        let source_svg = r##"<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><circle cx="12" cy="12" r="6" fill="#e12c38"/></svg>"##;
        fs::write(&source, source_svg).unwrap();
        let mut icons = Icons {
            directory: Some(directory.clone()),
            files: HashMap::new(),
            folders: vec![],
            halo_color: None,
        };
        for color in [Color::WHITE, Color::BLACK] {
            let path = icons.with_halo(&source, color).unwrap();
            let raster = rasterize(&path);
            let center_x = raster.width() / 2;
            let center_y = raster.height() / 2;
            let center = raster.pixel(center_x, center_y).unwrap();
            assert!(center.alpha() > 0 && center.alpha() < 255);
            let ink = if color == Color::WHITE { center.alpha() } else { 0 };
            assert_eq!((center.red(), center.green(), center.blue()), (ink, ink, ink));
            assert_eq!(
                raster.pixel(0, 0).unwrap().alpha(),
                0,
                "no rectangular backing"
            );
            let edge = raster.pixel(center_x + 7, center_y).unwrap();
            assert!(edge.alpha() > 0, "the silhouette has a soft outer halo");
            if color == Color::WHITE {
                assert!(edge.red() > 0);
            } else {
                assert_eq!(edge.red(), 0);
            }
        }
        assert_eq!(fs::read_to_string(&source).unwrap(), source_svg);
        fs::remove_file(&source).unwrap();
        drop(icons);
        assert!(!directory.exists());
    }
}
