use std::collections::BTreeMap;

use amane::{Rectangle, Stack, Widget};
use niri_ipc::Window;

use crate::theme::{Theme, faded};

#[derive(Debug, PartialEq)]
struct Tile {
    id: u64,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    focused: bool,
    active: bool,
}

#[derive(Debug, Default)]
pub struct Minimap {
    pub width: f32,
    tiles: Vec<Tile>,
}

impl Minimap {
    pub fn layout<'a>(
        windows: impl Iterator<Item = &'a Window>,
        active_id: Option<u64>,
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
        let scale = (f64::from(max_width) / total_width).min(f64::from(height) / tallest);
        let mut map = Self {
            width: (total_width * scale) as f32,
            tiles: Vec::new(),
        };
        let mut x = 0.0;
        for (windows, (column_width, column_height)) in columns.values().zip(sizes) {
            let mut y = (f64::from(height) - column_height * scale) / 2.0;
            for window in windows {
                let tile_width = column_width * scale;
                let tile_height = window.layout.tile_size.1 * scale;
                let gap_x = tile_width.min(1.0);
                let gap_y = tile_height.min(1.0);
                map.tiles.push(Tile {
                    id: window.id,
                    x: (x + gap_x / 2.0) as f32,
                    y: (y + gap_y / 2.0) as f32,
                    width: (tile_width - gap_x) as f32,
                    height: (tile_height - gap_y) as f32,
                    focused: window.is_focused,
                    active: active_id == Some(window.id),
                });
                y += tile_height;
            }
            x += column_width * scale;
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
                let border = if tile.active {
                    theme.accent
                } else {
                    faded(theme.accent, 120)
                };
                Box::new(
                    Rectangle::new()
                        .width(tile.width)
                        .height(tile.height)
                        .fill(fill)
                        .border(1.0, border)
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
        let map = Minimap::layout(windows.iter(), Some(2), 180.0, 18.0);
        assert_eq!(map.width, 24.0);
        assert_eq!(
            map.tiles.iter().map(|tile| tile.id).collect::<Vec<_>>(),
            [1, 2, 3]
        );
        assert_eq!(map.tiles[0].height, 5.0);
        assert_eq!(map.tiles[1].height, 11.0);
        assert_eq!(map.tiles[0].width, 15.0);
        assert_eq!(map.tiles[2].width, 7.0);
        assert!(map.tiles[1].active);
        assert!(!map.tiles[1].focused);
        assert!(map.tiles[2].focused);
    }

    #[test]
    fn caps_width_and_keeps_tiles_inside_bounds() {
        let windows: Vec<_> = (1..=30).map(|id| window(id, 1, id as usize, 1)).collect();
        let map = Minimap::layout(windows.iter(), None, 100.0, 18.0);
        assert_eq!(map.width, 100.0);
        for tile in &map.tiles {
            assert!(tile.x >= 0.0 && tile.y >= 0.0);
            assert!(tile.x + tile.width <= 100.0);
            assert!(tile.y + tile.height <= 18.0);
        }
    }

    #[test]
    fn ignores_floating_missing_and_invalid_geometry() {
        let mut windows: Vec<_> = (1..=4).map(|id| window(id, 1, 1, 1)).collect();
        windows[0].is_floating = true;
        windows[1].layout.pos_in_scrolling_layout = None;
        windows[2].layout.tile_size.0 = f64::NAN;
        windows[3].layout.tile_size.1 = 0.0;
        assert_eq!(
            Minimap::layout(windows.iter(), None, 100.0, 18.0).width,
            0.0
        );
        assert!(
            Minimap::layout([].iter(), None, 100.0, 18.0)
                .tiles
                .is_empty()
        );
        assert!(
            Minimap::layout(windows.iter(), None, 0.0, 18.0)
                .tiles
                .is_empty()
        );
    }
}
