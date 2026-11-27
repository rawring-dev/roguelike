const std = @import("std");
const dungeon_generation = @import("dungeon_generation.zig");
const BitMap = dungeon_generation.BitMap;

pub const Side = enum { x, y };

pub const Hit = struct {
    tile_x: i32,
    tile_y: i32,
    world_x: f32,
    world_y: f32,
    distance: f32,
    side: Side,
};

const inf = std.math.inf(f32);

pub fn cast(
    map: *const BitMap,
    tile_size: f32,
    ox: f32,
    oy: f32,
    dx: f32,
    dy: f32,
    max_distance: f32,
) ?Hit {
    if (tile_size <= 0 or max_distance < 0) return null;

    const len = @sqrt(dx * dx + dy * dy);
    if (len == 0) return null;

    const rx = dx / len;
    const ry = dy / len;
    const gdx = rx / tile_size;
    const gdy = ry / tile_size;

    const gx = ox / tile_size;
    const gy = oy / tile_size;

    var map_x: i32 = @intFromFloat(@floor(gx));
    var map_y: i32 = @intFromFloat(@floor(gy));

    const delta_x = if (gdx == 0) inf else @abs(1.0 / gdx);
    const delta_y = if (gdy == 0) inf else @abs(1.0 / gdy);

    var step_x: i32 = 0;
    var side_dist_x = inf;
    if (gdx > 0) {
        step_x = 1;
        side_dist_x = (@as(f32, @floatFromInt(map_x + 1)) - gx) * delta_x;
    } else if (gdx < 0) {
        step_x = -1;
        side_dist_x = (gx - @as(f32, @floatFromInt(map_x))) * delta_x;
    }

    var step_y: i32 = 0;
    var side_dist_y = inf;
    if (gdy > 0) {
        step_y = 1;
        side_dist_y = (@as(f32, @floatFromInt(map_y + 1)) - gy) * delta_y;
    } else if (gdy < 0) {
        step_y = -1;
        side_dist_y = (gy - @as(f32, @floatFromInt(map_y))) * delta_y;
    }

    if (!map.is_set(map_x, map_y)) {
        return .{
            .tile_x = map_x,
            .tile_y = map_y,
            .world_x = ox,
            .world_y = oy,
            .distance = 0,
            .side = .x,
        };
    }

    var distance: f32 = 0;
    var side: Side = .x;

    while (true) {
        if (side_dist_x < side_dist_y) {
            distance = side_dist_x;
            side_dist_x += delta_x;
            map_x += step_x;
            side = .x;
        } else {
            distance = side_dist_y;
            side_dist_y += delta_y;
            map_y += step_y;
            side = .y;
        }

        if (distance > max_distance) return null;

        if (!map.is_set(map_x, map_y)) {
            return .{
                .tile_x = map_x,
                .tile_y = map_y,
                .world_x = ox + rx * distance,
                .world_y = oy + ry * distance,
                .distance = distance,
                .side = side,
            };
        }
    }
}

pub fn has_line_of_sight(
    map: *const BitMap,
    tile_size: f32,
    ax: f32,
    ay: f32,
    bx: f32,
    by: f32,
) bool {
    const dx = bx - ax;
    const dy = by - ay;
    const dist = @sqrt(dx * dx + dy * dy);
    if (dist == 0) return true;

    return cast(map, tile_size, ax, ay, dx, dy, dist) == null;
}
