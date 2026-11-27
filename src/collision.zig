const std = @import("std");
const dungeon_generation = @import("dungeon_generation.zig");
const BitMap = dungeon_generation.BitMap;

/// World-space axis-aligned bounding box, top-left origin.
pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    pub fn right(self: Rect) f32 {
        return self.x + self.w;
    }

    pub fn bottom(self: Rect) f32 {
        return self.y + self.h;
    }

    pub fn center_x(self: Rect) f32 {
        return self.x + self.w * 0.5;
    }

    pub fn center_y(self: Rect) f32 {
        return self.y + self.h * 0.5;
    }

    pub fn overlaps(self: Rect, other: Rect) bool {
        return self.x < other.right() and other.x < self.right() and
            self.y < other.bottom() and other.y < self.bottom();
    }

    pub fn contains_point(self: Rect, px: f32, py: f32) bool {
        return px >= self.x and px < self.right() and py >= self.y and py < self.bottom();
    }
};

pub fn is_solid_tile(map: *const BitMap, tile_x: i32, tile_y: i32) bool {
    return !map.is_set(tile_x, tile_y);
}

pub fn solid_at(map: *const BitMap, tile_size: f32, world_x: f32, world_y: f32) bool {
    if (tile_size <= 0) return false;
    const tx: i32 = @intFromFloat(@floor(world_x / tile_size));
    const ty: i32 = @intFromFloat(@floor(world_y / tile_size));
    return is_solid_tile(map, tx, ty);
}

const edge_epsilon: f32 = 0.0001;

const Span = struct { first: i32, last: i32 };

fn tile_span(lo: f32, hi: f32, tile_size: f32) Span {
    return .{
        .first = @intFromFloat(@floor(lo / tile_size)),
        .last = @intFromFloat(@floor((hi - edge_epsilon) / tile_size)),
    };
}

pub fn overlaps_solid(map: *const BitMap, rect: Rect, tile_size: f32) bool {
    if (rect.w <= 0 or rect.h <= 0 or tile_size <= 0) return false;

    const xs = tile_span(rect.x, rect.right(), tile_size);
    const ys = tile_span(rect.y, rect.bottom(), tile_size);
    if (xs.last < xs.first or ys.last < ys.first) return false;

    var ty = ys.first;
    while (ty <= ys.last) : (ty += 1) {
        var tx = xs.first;
        while (tx <= xs.last) : (tx += 1) {
            if (is_solid_tile(map, tx, ty)) return true;
        }
    }
    return false;
}

pub fn overlaps_solid_at(
    map: *const BitMap,
    tile_size: f32,
    x: f32,
    y: f32,
    half_w: f32,
    half_h: f32,
) bool {
    return overlaps_solid(map, .{
        .x = x - half_w,
        .y = y - half_h,
        .w = half_w * 2,
        .h = half_h * 2,
    }, tile_size);
}

pub const MoveResult = struct { x: f32, y: f32 };

pub fn move_rect(map: *const BitMap, tile_size: f32, rect: Rect, dx: f32, dy: f32) MoveResult {
    var x = rect.x;
    var y = rect.y;

    if (dx != 0) {
        const moved = Rect{ .x = x + dx, .y = y, .w = rect.w, .h = rect.h };
        if (!overlaps_solid(map, moved, tile_size)) x += dx;
    }
    if (dy != 0) {
        const moved = Rect{ .x = x, .y = y + dy, .w = rect.w, .h = rect.h };
        if (!overlaps_solid(map, moved, tile_size)) y += dy;
    }

    return .{ .x = x, .y = y };
}
