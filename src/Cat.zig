const Self = @This();
const std = @import("std");
const w4 = @import("wasm4.zig");
const BulletYarn = @import("BulletYarn.zig");
const Bullet = @import("Bullet.zig");
const SlotArray = @import("slot_array.zig").SlotArray;
const BulletsInterface = @import("bullets_interface.zig").Interface;
const YarnBulletsInterface = BulletsInterface(YarnBullets, BulletYarn);
const math = @import("math.zig");
const dda = @import("dda.zig");
const collision = @import("collision.zig");
const pathfinding = @import("pathfinding.zig");
const BitMap = @import("dungeon_generation.zig").BitMap;

const sprite = [16]u8{
    0b00_00_01_00, 0b00_00_01_00,
    0b00_01_01_01, 0b00_01_01_01,
    0b00_01_01_01, 0b01_01_01_01,
    0b00_01_10_01, 0b01_01_10_01,
    0b00_01_01_01, 0b01_01_01_01,
    0b00_01_10_01, 0b10_01_10_01,
    0b00_01_01_10, 0b01_10_01_01,
    0b00_00_01_01, 0b01_01_01_00,
};
const speed: f32 = 1;
const bullet_speed: f32 = 1;
const YarnBullets = SlotArray(BulletYarn, 50);
const bullet_cooldown: u32 = 60;
const bullet_lifetime = 2;

const body_w = 8;
const body_h = 8;
const player_distance: f32 = 64;
const sight_distance: f32 = 12 * 16;
const repath_interval: u32 = 30;
const max_path = 64;
const max_health: f32 = 5;

x: f32,
y: f32,
bullet_timer: u32,

path: [max_path]pathfinding.Cell = undefined,
path_len: usize = 0,
path_index: usize = 0,
repath_timer: u32 = 0,
health: f32 = max_health,

pub fn init(x: i32, y: i32) Self {
    return .{ .x = @floatFromInt(x), .y = @floatFromInt(y), .bullet_timer = 0 };
}

pub fn init_at_center(cx: f32, cy: f32) Self {
    return .{
        .x = cx - @as(f32, @floatFromInt(body_w)) / 2.0,
        .y = cy - @as(f32, @floatFromInt(body_h)) / 2.0,
        .bullet_timer = 0,
    };
}

pub fn update(
    self: *Self,
    player_x: f32,
    player_y: f32,
    bullet_interface: YarnBulletsInterface,
    blockers: *const BitMap,
    pathfinder: *pathfinding.Pathfinder,
    tile_size: f32,
) void {
    const player_cx = player_x + @as(f32, @floatFromInt(body_w)) / 2.0;
    const player_cy = player_y + @as(f32, @floatFromInt(body_h)) / 2.0;
    const dx = player_cx - self.center_x();
    const dy = player_cy - self.center_y();
    const dist = std.math.hypot(dx, dy);

    const can_see = dist <= sight_distance and dda.has_line_of_sight(
        blockers,
        tile_size,
        self.center_x(),
        self.center_y(),
        player_cx,
        player_cy,
    );

    self.bullet_timer -|= 1;

    if (can_see) {
        self.path_len = 0;

        if (dist > player_distance) {
            const dir = math.setLength(dx, dy, speed);
            self.move(dir[0], dir[1], blockers, tile_size);
        } else if (self.bullet_timer == 0) {
            const dir = math.setLength(dx, dy, bullet_speed);
            bullet_interface.append(.init(Bullet.init(
                self.x,
                self.y,
                dir[0],
                dir[1],
                bullet_lifetime * 60,
            ))) catch {};

            self.bullet_timer = bullet_cooldown;
        }
        return;
    }

    if (self.repath_timer > 0) self.repath_timer -= 1;
    if (self.path_len == 0 or self.path_index >= self.path_len or self.repath_timer == 0) {
        self.repath(blockers, pathfinder, tile_size, player_cx, player_cy);
        self.repath_timer = repath_interval;
    }

    self.follow_path(blockers, tile_size);
}

fn center_x(self: *const Self) f32 {
    return self.x + @as(f32, @floatFromInt(body_w)) / 2.0;
}

fn center_y(self: *const Self) f32 {
    return self.y + @as(f32, @floatFromInt(body_h)) / 2.0;
}

fn repath(
    self: *Self,
    blockers: *const BitMap,
    pathfinder: *pathfinding.Pathfinder,
    tile_size: f32,
    player_cx: f32,
    player_cy: f32,
) void {
    const start = tile_of(self.center_x(), self.center_y(), tile_size);
    const goal = tile_of(player_cx, player_cy, tile_size);

    self.path_len = pathfinder.find_path(blockers, start, goal, &self.path) orelse 0;
    self.path_index = if (self.path_len > 1) 1 else 0;
}

fn follow_path(self: *Self, blockers: *const BitMap, tile_size: f32) void {
    while (self.path_index < self.path_len) {
        const cell = self.path[self.path_index];
        const target_x = (@as(f32, @floatFromInt(cell.x)) + 0.5) * tile_size;
        const target_y = (@as(f32, @floatFromInt(cell.y)) + 0.5) * tile_size;

        const dx = target_x - self.center_x();
        const dy = target_y - self.center_y();
        const dist = std.math.hypot(dx, dy);

        if (dist < 1.0) {
            self.path_index += 1;
            continue;
        }

        const dir = math.setLength(dx, dy, @min(speed, dist));
        self.move(dir[0], dir[1], blockers, tile_size);
        return;
    }
}

fn move(self: *Self, dx: f32, dy: f32, blockers: *const BitMap, tile_size: f32) void {
    const rect = collision.Rect{
        .x = self.x,
        .y = self.y,
        .w = @floatFromInt(body_w),
        .h = @floatFromInt(body_h),
    };
    const moved = collision.move_rect(blockers, tile_size, rect, dx, dy);
    self.x = moved.x;
    self.y = moved.y;
}

fn tile_of(world_x: f32, world_y: f32, tile_size: f32) pathfinding.Cell {
    return .{
        .x = @intFromFloat(@floor(world_x / tile_size)),
        .y = @intFromFloat(@floor(world_y / tile_size)),
    };
}

// returns true if this entity died
pub fn damage(self: *Self, points: f32) bool {
    self.health -= points;
    return self.health <= 0;
}

pub fn draw(self: *const Self, camera_x: i32, camera_y: i32) void {
    const w = 8;
    const h = 8;
    w4.DRAW_COLORS.* = 0x430;
    w4.blit(&sprite, @as(i32, @trunc(self.x)) - camera_x, @as(i32, @trunc(self.y)) - camera_y, w, h, w4.BLIT_2BPP);
}
