use std::{
    collections::HashMap,
    env,
    ffi::OsString,
    fs::{self, File},
    io::{BufReader, BufWriter, Cursor, Read},
    os::unix::{
        ffi::OsStringExt,
        fs::{DirBuilderExt, PermissionsExt},
    },
    path::{Path, PathBuf},
    sync::{Arc, LazyLock, OnceLock, Weak, mpsc},
    thread,
};

use amane::Service;
use rustix::fs::{FlockOperation, Mode, OFlags};
use tempfile::{Builder, TempPath};
use zbus::zvariant::{OwnedValue, Signature, Value};
use zune_jpeg::{
    JpegDecoder,
    zune_core::{bytestream::ZCursor, colorspace::ColorSpace, options::DecoderOptions},
};

use super::Notifications;
use crate::{design::notifications::THUMBNAIL_PIXELS, icon_theme};

const MAX_BYTES: u64 = 16 * 1024 * 1024;
const MAX_SIDE: u32 = 4096;
const MAX_PIXELS: u32 = 9 * 1024 * 1024;
const QUEUE_DEPTH: usize = 8;
const THUMB_PREFIX: &str = "thumb_";

struct Cache {
    path: PathBuf,
    _lock: File,
}

impl Cache {
    fn open(runtime: &Path) -> Option<Self> {
        if !runtime.is_absolute() {
            return None;
        }
        let path = runtime.join("amane_notification_thumbnails");
        match fs::DirBuilder::new().mode(0o700).create(&path) {
            Ok(()) => {}
            Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => {}
            Err(_) => return None,
        }
        let lock = File::from(
            rustix::fs::open(
                &path,
                OFlags::RDONLY | OFlags::DIRECTORY | OFlags::NOFOLLOW | OFlags::CLOEXEC,
                Mode::empty(),
            )
            .ok()?,
        );
        if lock.metadata().ok()?.permissions().mode() & 0o077 != 0 {
            return None;
        }
        rustix::fs::flock(&lock, FlockOperation::NonBlockingLockExclusive).ok()?;
        // A killed shell cannot drop TempPaths. Reap old thumbnails only after
        // securing the directory for this instance.
        for entry in fs::read_dir(&path).ok()?.flatten() {
            if entry
                .file_name()
                .to_str()
                .is_some_and(|name| name.starts_with(THUMB_PREFIX) && name.ends_with(".png"))
            {
                let _ = fs::remove_file(entry.path());
            }
        }
        Some(Self { path, _lock: lock })
    }
}

pub(super) enum Preview {
    Cached(TempPath),
    Themed(PathBuf),
}

impl Preview {
    pub(super) fn path(&self) -> &Path {
        match self {
            Self::Cached(path) => path.as_ref(),
            Self::Themed(path) => path,
        }
    }
}

enum Source {
    Raster(Raster),
    File(File),
    Theme(String),
}

struct Job {
    target: Weak<OnceLock<Preview>>,
    sources: Vec<Source>,
}

static JOBS: LazyLock<Option<mpsc::SyncSender<Job>>> = LazyLock::new(|| {
    let (sender, jobs) = mpsc::sync_channel::<Job>(QUEUE_DEPTH);
    thread::Builder::new()
        .name("notification_images".into())
        .spawn(move || {
            let cache =
                env::var_os("XDG_RUNTIME_DIR").and_then(|root| Cache::open(Path::new(&root)));
            for Job { target, sources } in jobs {
                if target.strong_count() == 0 {
                    continue;
                }
                let preview = sources.into_iter().find_map(|source| {
                    source.preview(cache.as_ref().map(|cache| cache.path.as_path()))
                });
                if let (Some(target), Some(preview)) = (target.upgrade(), preview) {
                    let published = target.set(preview).is_ok();
                    // Do not hold an image alive while waiting on the UI state lock.
                    drop(target);
                    if published {
                        drop(Notifications::write());
                    }
                }
            }
        })
        .ok()?;
    Some(sender)
});

pub(super) fn capture(
    hints: &HashMap<String, OwnedValue>,
    app_icon: &str,
) -> Arc<OnceLock<Preview>> {
    let target = Arc::new(OnceLock::new());
    let raw = |name: &str| raw_thumbnail(hints.get(name)?).map(Source::Raster);
    let named_hint = |name: &str| <&str>::try_from(hints.get(name)?).ok();
    let modern = raw("image-data").or_else(|| raw("image_data"));
    // Open path-backed payloads before acknowledging Notify. The worker can
    // read the open file even if the sender unlinks it immediately afterward.
    let from_path = named_hint("image-path")
        .or_else(|| named_hint("image_path"))
        .and_then(Source::open);
    let app = Source::open(app_icon);
    let legacy = raw("icon_data");
    let desktop_icon = named_hint("desktop-entry").and_then(Source::named);
    let sources: Vec<_> = [modern, from_path, app, legacy, desktop_icon]
        .into_iter()
        .flatten()
        .collect();
    if !sources.is_empty()
        && let Some(jobs) = JOBS.as_ref()
    {
        // An image burst must not delay delivery of notification text.
        let _ = jobs.try_send(Job {
            target: Arc::downgrade(&target),
            sources,
        });
    }
    target
}

impl Source {
    fn named(name: &str) -> Option<Self> {
        (!name.is_empty() && name.len() <= 255 && !name.contains('/') && !name.contains(':'))
            .then(|| Self::Theme(name.trim_end_matches(".desktop").into()))
    }

    fn open(value: &str) -> Option<Self> {
        if !value.starts_with('/') && !value.starts_with("file:") {
            return Self::named(value);
        }
        let path = local_path(value)?;
        let file = File::from(
            rustix::fs::open(
                &path,
                OFlags::RDONLY | OFlags::NONBLOCK | OFlags::CLOEXEC,
                Mode::empty(),
            )
            .ok()?,
        );
        let metadata = file.metadata().ok()?;
        (metadata.is_file() && (1..=MAX_BYTES).contains(&metadata.len()))
            .then_some(Self::File(file))
    }

    fn preview(self, directory: Option<&Path>) -> Option<Preview> {
        static FOLDERS: LazyLock<Vec<PathBuf>> = LazyLock::new(icon_theme::theme_folders);
        let raster = match self {
            Self::Theme(name) => {
                return icon_theme::find(&name, FOLDERS.iter()).map(Preview::Themed);
            }
            Self::Raster(raster) => raster,
            Self::File(file) => {
                directory?;
                let mut bytes = Vec::new();
                file.take(MAX_BYTES + 1).read_to_end(&mut bytes).ok()?;
                if bytes.len() as u64 > MAX_BYTES {
                    return None;
                }
                decode(&bytes)?
            }
        };
        raster.save(directory?).map(Preview::Cached)
    }
}

fn local_path(value: &str) -> Option<PathBuf> {
    if value.len() > 4096 {
        return None;
    }
    if value.starts_with('/') {
        return Some(value.into());
    }
    let uri = value.strip_prefix("file://")?;
    let encoded = uri.strip_prefix("localhost").unwrap_or(uri);
    if !encoded.starts_with('/') || encoded.contains(['?', '#']) {
        return None;
    }
    let mut bytes = encoded.bytes();
    let mut decoded = Vec::with_capacity(encoded.len());
    while let Some(byte) = bytes.next() {
        if byte == b'%' {
            let high = (bytes.next()? as char).to_digit(16)?;
            let low = (bytes.next()? as char).to_digit(16)?;
            decoded.push((high * 16 + low) as u8);
        } else {
            decoded.push(byte);
        }
    }
    Some(OsString::from_vec(decoded).into())
}

struct Raster {
    width: u32,
    height: u32,
    rgba: Vec<u8>,
}

fn valid_dimensions(width: u32, height: u32) -> bool {
    (1..=MAX_SIDE).contains(&width)
        && (1..=MAX_SIDE).contains(&height)
        && width * height <= MAX_PIXELS
}

impl Raster {
    fn sample(width: u32, height: u32, pixel: impl Fn(usize, usize) -> [u8; 4]) -> Self {
        let scale = width.max(height).max(THUMBNAIL_PIXELS);
        let w = (width * THUMBNAIL_PIXELS / scale).max(1);
        let h = (height * THUMBNAIL_PIXELS / scale).max(1);
        let mut rgba = Vec::with_capacity((w * h * 4) as usize);
        for y in 0..h {
            for x in 0..w {
                let column = ((2 * x + 1) * width / (2 * w)) as usize;
                let row = ((2 * y + 1) * height / (2 * h)) as usize;
                rgba.extend(pixel(column, row));
            }
        }
        Self {
            width: w,
            height: h,
            rgba,
        }
    }

    fn save(self, directory: &Path) -> Option<TempPath> {
        if !directory.is_absolute() {
            return None;
        }
        let mut file = Builder::new()
            .prefix(THUMB_PREFIX)
            .suffix(".png")
            .tempfile_in(directory)
            .ok()?;
        {
            let mut encoder =
                png::Encoder::new(BufWriter::new(file.as_file_mut()), self.width, self.height);
            encoder.set_color(png::ColorType::Rgba);
            encoder.set_depth(png::BitDepth::Eight);
            let mut writer = encoder.write_header().ok()?;
            writer.write_image_data(&self.rgba).ok()?;
            writer.finish().ok()?;
        }
        Some(file.into_temp_path())
    }
}

fn raw_thumbnail(value: &Value<'_>) -> Option<Raster> {
    let Value::Structure(image) = value else {
        return None;
    };
    let [
        Value::I32(width),
        Value::I32(height),
        Value::I32(stride),
        Value::Bool(alpha),
        Value::I32(8),
        Value::I32(channels),
        Value::Array(data),
    ] = image.fields()
    else {
        return None;
    };
    let (width, height) = (u32::try_from(*width).ok()?, u32::try_from(*height).ok()?);
    if !valid_dimensions(width, height) || *channels != if *alpha { 4 } else { 3 } {
        return None;
    }
    let stride = usize::try_from(*stride).ok()?;
    let channels = *channels as usize;
    let row = width as usize * channels;
    let last = (height as usize - 1)
        .checked_mul(stride)?
        .checked_add(row)?;
    if data.element_signature() != &Signature::U8
        || stride < row
        || last > data.len()
        || data.len() as u64 > MAX_BYTES
    {
        return None;
    }
    Some(Raster::sample(width, height, |x, y| {
        let index = y * stride + x * channels;
        let byte = |offset: usize| u8::try_from(&data.inner()[index + offset]).unwrap_or_default();
        [
            byte(0),
            byte(1),
            byte(2),
            if *alpha { byte(3) } else { 255 },
        ]
    }))
}

fn decode(bytes: &[u8]) -> Option<Raster> {
    if bytes.starts_with(b"\xff\xd8") {
        let options = DecoderOptions::default()
            .set_max_width(MAX_SIDE as usize)
            .set_max_height(MAX_SIDE as usize)
            .jpeg_set_out_colorspace(ColorSpace::RGBA);
        let mut decoder = JpegDecoder::new_with_options(ZCursor::new(bytes), options);
        decoder.decode_headers().ok()?;
        let info = decoder.info()?;
        let (width, height) = (u32::from(info.width), u32::from(info.height));
        if !valid_dimensions(width, height) {
            return None;
        }
        let pixels = decoder.decode().ok()?;
        let rgba = pixels.as_chunks::<4>().0;
        if rgba.len() != (width * height) as usize {
            return None;
        }
        return Some(Raster::sample(width, height, |x, y| {
            rgba[y * width as usize + x]
        }));
    }
    let mut decoder = png::Decoder::new(BufReader::new(Cursor::new(bytes)));
    decoder.set_transformations(png::Transformations::normalize_to_color8());
    let mut reader = decoder.read_info().ok()?;
    let (width, height) = reader.info().size();
    if !valid_dimensions(width, height) {
        return None;
    }
    let mut pixels = vec![0; reader.output_buffer_size()?];
    let frame = reader.next_frame(&mut pixels).ok()?;
    let channels = frame.color_type.samples();
    Some(Raster::sample(frame.width, frame.height, |x, y| {
        let offset = y * frame.line_size + x * channels;
        match &pixels[offset..offset + channels] {
            [gray] => [*gray, *gray, *gray, 255],
            [gray, alpha] => [*gray, *gray, *gray, *alpha],
            [r, g, b] => [*r, *g, *b, 255],
            [r, g, b, a] => [*r, *g, *b, *a],
            _ => unreachable!("PNG decoder emits normalized channels"),
        }
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decodes_padded_raw_pixels_and_rejects_short_rows() {
        let value = Value::from((
            1_i32,
            2_i32,
            4_i32,
            false,
            8_i32,
            3_i32,
            vec![1_u8, 2, 3, 0, 4, 5, 6],
        ));
        let image = raw_thumbnail(&value).unwrap();
        assert_eq!((image.width, image.height), (1, 2));
        assert_eq!(image.rgba, [1, 2, 3, 255, 4, 5, 6, 255]);
        let bad = Value::from((1_i32, 2_i32, 2_i32, false, 8_i32, 3_i32, vec![0_u8; 8]));
        assert!(raw_thumbnail(&bad).is_none());
    }

    #[test]
    fn snapshots_an_open_local_image_after_unlink_and_reclaims_stale_cache() {
        let runtime = tempfile::tempdir().unwrap();
        let cache = Cache::open(runtime.path()).unwrap();
        let input = Raster::sample(2, 1, |_, _| [20, 30, 40, 128])
            .save(runtime.path())
            .unwrap();
        let original = input.to_path_buf();
        let source = Source::open(original.to_str().unwrap()).unwrap();
        drop(input);
        assert!(!original.exists());
        let preview = source.preview(Some(&cache.path)).unwrap();
        let path = preview.path().to_owned();
        assert_eq!(
            decode(&fs::read(&path).unwrap()).unwrap().rgba,
            [20, 30, 40, 128].repeat(2)
        );
        assert!(Cache::open(runtime.path()).is_none());
        drop(preview);
        assert!(!path.exists());
        let stale = cache.path.join("thumb_abandoned.png");
        fs::write(&stale, []).unwrap();
        drop(cache);
        assert!(Cache::open(runtime.path()).is_some());
        assert!(!stale.exists());
    }

    #[test]
    fn local_uris_do_not_accept_remote_hosts_or_bad_escaping() {
        assert_eq!(
            local_path("file://localhost/tmp/with%20space.png"),
            Some("/tmp/with space.png".into())
        );
        assert!(local_path("file://example.org/tmp/image.png").is_none());
        assert!(local_path("file:///tmp/%zz").is_none());
    }
}
