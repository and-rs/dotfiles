use std::collections::BTreeMap;

use amane::{Rectangle, Stack, Widget};
use niri_ipc::Window;

use crate::{
    design::spacing,
    theme::{Theme, faded},
};

#[derive(Debug, PartialEq)]
struct Tile {
    id: u64,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    focused: bool,
}

#[derive(Debug, Default)]
pub struct Minimap {
    pub width: f32,
    tiles: Vec<Tile>,
}

impl Minimap {
    pub fn layout<'a>(
        windows: impl Iterator<Item = &'a Window>,
        max_width: f32,
        height: f32,
    ) -> Self {
        if !max_width.is_finite() || !height.is_finite() || max_width <= 0.0 || height <= 0.0 {
            return Self::default();
        }
        let mut columns: BTreeMap<usize, Vec<&Window>> = BTreeMap::new();
        for window in windows {
            let Some((column, row)) = window.layout.pos_in_scrolling_layout else {
                continue;
            };
            let (width, height) = window.layout.tile_size;
            if window.is_floating
                || column == 0
                || row == 0
                || !width.is_finite()
                || !height.is_finite()
                || width <= 0.0
                || height <= 0.0
            {
                continue;
            }
            columns.entry(column).or_default().push(window);
        }
        if columns.is_empty() {
            return Self::default();
        }
        for windows in columns.values_mut() {
            windows.sort_by_key(|window| (window.layout.pos_in_scrolling_layout, window.id));
        }
        let sizes: Vec<(f64, f64)> = columns
            .values()
            .map(|windows| {
                let width = windows
                    .iter()
                    .map(|win| win.layout.tile_size.0)
                    .fold(0.0, f64::max);
                let height = windows.iter().map(|win| win.layout.tile_size.1).sum();
                (width, height)
            })
            .collect();
        let total_width: f64 = sizes.iter().map(|size| size.0).sum();
        let tallest = sizes.iter().map(|size| size.1).fold(0.0, f64::max);
        if !total_width.is_finite() || !tallest.is_finite() {
            return Self::default();
        }
        // Reserve gaps between columns, keeping room for tiles even in narrow maps.
        let gap = f64::from(spacing::TINY).min(f64::from(max_width) / (2.0 * columns.len() as f64));
        let gaps_width = gap * (columns.len() - 1) as f64;
        let scale =
            ((f64::from(max_width) - gaps_width) / total_width).min(f64::from(height) / tallest);
        let mut map = Self {
            width: (total_width * scale + gaps_width) as f32,
            tiles: Vec::new(),
        };
        let mut x = 0.0;
        for (windows, (column_width, column_height)) in columns.values().zip(sizes) {
            let mut y = (f64::from(height) - column_height * scale) / 2.0;
            for window in windows {
                let tile_width = column_width * scale;
                let tile_height = window.layout.tile_size.1 * scale;
                let gap_y = tile_height.min(f64::from(spacing::TINY));
                map.tiles.push(Tile {
                    id: window.id,
                    x: x as f32,
                    y: (y + gap_y / 2.0) as f32,
                    width: tile_width as f32,
                    height: (tile_height - gap_y) as f32,
                    focused: window.is_focused,
                });
                y += tile_height;
            }
            x += column_width * scale + gap;
        }
        map
    }

    pub fn view(&self, theme: &Theme, height: f32) -> Stack {
        let tiles: Vec<Box<dyn Widget>> = self
            .tiles
            .iter()
            .map(|tile| {
                let fill = if tile.focused {
                    theme.accent
                } else {
                    faded(theme.accent, 80)
                };
                Box::new(
                    Rectangle::new()
                        .width(tile.width)
                        .height(tile.height)
                        .fill(fill)
                        .translate(tile.x, tile.y),
                ) as Box<dyn Widget>
            })
            .collect();
        Stack::new(tiles).width(self.width).height(height)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::niri::tests::window;

    #[test]
    fn sorts_columns_and_rows_and_preserves_proportions() {
        let mut first = window(1, 1, 1, 1);
        first.layout.tile_size = (800.0, 300.0);
        let mut second = window(2, 1, 1, 2);
        second.layout.tile_size = (800.0, 600.0);
        let mut third = window(3, 1, 2, 1);
        third.layout.tile_size = (400.0, 900.0);
        third.is_focused = true;
        let windows = [third, second, first];
        let map = Minimap::layout(windows.iter(), 180.0, 18.0);
        assert_eq!(map.width, 27.0);
        assert_eq!(
            map.tiles.iter().map(|tile| tile.id).collect::<Vec<_>>(),
            [1, 2, 3]
        );
        assert_eq!(map.tiles[0].height, 3.0);
        assert_eq!(map.tiles[1].height, 9.0);
        assert_eq!(map.tiles[0].width, 16.0);
        assert_eq!(map.tiles[2].width, 8.0);
        assert_eq!(map.tiles[0].x, 0.0);
        assert_eq!(map.tiles[2].x, 19.0);
        assert_eq!(
            map.tiles[1].y - (map.tiles[0].y + map.tiles[0].height),
            spacing::TINY
        );
        assert_eq!(map.tiles[2].x + map.tiles[2].width, map.width);
        assert!(!map.tiles[1].focused);
        assert!(map.tiles[2].focused);
    }

    #[test]
    fn caps_width_and_keeps_tiles_inside_bounds() {
        let windows: Vec<_> = (1..=30).map(|id| window(id, 1, id as usize, 1)).collect();
        let map = Minimap::layout(windows.iter(), 100.0, 18.0);
        assert_eq!(map.width, 100.0);
        for tile in &map.tiles {
            assert!(tile.x >= 0.0 && tile.y >= 0.0);
            assert!(tile.x + tile.width <= 100.0);
            assert!(tile.y + tile.height <= 18.0);
        }
    }

    #[test]
    fn single_column_has_no_horizontal_inset() {
        let windows = [window(1, 1, 1, 1)];
        let map = Minimap::layout(windows.iter(), 100.0, 18.0);
        assert_eq!(map.tiles[0].x, 0.0);
        assert_eq!(map.tiles[0].width, map.width);
    }

    #[test]
    fn shrinks_gaps_to_keep_narrow_tiles_visible() {
        let windows: Vec<_> = (1..=30).map(|id| window(id, 1, id as usize, 1)).collect();
        let map = Minimap::layout(windows.iter(), 1.0, 18.0);
        assert_eq!(map.width, 1.0);
        assert_eq!(map.tiles[0].x, 0.0);
        for pair in map.tiles.windows(2) {
            assert!(pair[0].width > 0.0);
            assert!(pair[0].x + pair[0].width < pair[1].x);
        }
        let last = map.tiles.last().unwrap();
        assert!(last.width > 0.0);
        assert!((last.x + last.width - map.width).abs() < f32::EPSILON);
    }

    #[test]
    fn ignores_floating_missing_and_invalid_geometry() {
        let mut windows: Vec<_> = (1..=4).map(|id| window(id, 1, 1, 1)).collect();
        windows[0].is_floating = true;
        windows[1].layout.pos_in_scrolling_layout = None;
        windows[2].layout.tile_size.0 = f64::NAN;
        windows[3].layout.tile_size.1 = 0.0;
        assert_eq!(Minimap::layout(windows.iter(), 100.0, 18.0).width, 0.0);
        assert!(Minimap::layout([].iter(), 100.0, 18.0).tiles.is_empty());
        assert!(Minimap::layout(windows.iter(), 0.0, 18.0).tiles.is_empty());
    }
}
