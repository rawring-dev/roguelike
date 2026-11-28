const Self = @This();
const w4 = @import("wasm4.zig");
const collision = @import("collision.zig");
const BitMap = @import("dungeon_generation.zig").BitMap;

pub const max_health: f32 = 100;

const w = 8;
const h = 8;
const sprite = [8]u8{ 0x00, 0x24, 0x24, 0x00, 0x24, 0x18, 0x00, 0x00 };
const half_width: i32 = w4.SCREEN_SIZE / 2 - (w / 2);
const half_height: i32 = w4.SCREEN_SIZE / 2 - (h / 2);

x: f32,
y: f32,
camera_x: i32,
camera_y: i32,
health: f32 = max_health,

pub fn init() Self {
    return .{
        .x = half_width,
        .y = half_height,
        .camera_x = 0,
        .camera_y = 0,
    };
}

pub fn place_centered(self: *Self, center_x: f32, center_y: f32) void {
    self.x = center_x - @as(f32, @floatFromInt(w)) / 2.0;
    self.y = center_y - @as(f32, @floatFromInt(h)) / 2.0;
    self.update_camera();
}

pub fn update(self: *Self, blockers: *const BitMap, tile_size: f32) void {
    var dx: f32 = 0;
    var dy: f32 = 0;

    if ((w4.GAMEPAD1.* & w4.BUTTON_LEFT) != 0) dx -= 1;
    if ((w4.GAMEPAD1.* & w4.BUTTON_RIGHT) != 0) dx += 1;
    if ((w4.GAMEPAD1.* & w4.BUTTON_UP) != 0) dy -= 1;
    if ((w4.GAMEPAD1.* & w4.BUTTON_DOWN) != 0) dy += 1;

    self.move(dx, dy, blockers, tile_size);
    self.update_camera();
}

fn move(self: *Self, dx: f32, dy: f32, blockers: *const BitMap, tile_size: f32) void {
    const rect = collision.Rect{
        .x = self.x,
        .y = self.y,
        .w = @floatFromInt(w),
        .h = @floatFromInt(h),
    };
    const moved = collision.move_rect(blockers, tile_size, rect, dx, dy);
    self.x = moved.x;
    self.y = moved.y;
}

fn update_camera(self: *Self) void {
    self.camera_x = @as(i32, @trunc(self.x)) - half_width;
    self.camera_y = @as(i32, @trunc(self.y)) - half_height;
}
pub fn draw(self: *const Self) void {
    w4.DRAW_COLORS.* = 4;
    w4.blit(&sprite, @as(i32, @trunc(self.x)) - self.camera_x, @as(i32, @trunc(self.y)) - self.camera_y, w, h, w4.BLIT_1BPP);
}

pub fn collisionRect(self: *const Self) collision.Rect {
    return collision.Rect{
        .x = self.x,
        .y = self.y,
        .w = 8,
        .h = 8,
    };
}

pub fn damage(self: *Self, points: f32) void {
    self.health -= points;
    if (self.health <= 0) {
        self.die();
    }
}

fn die(self: *Self) void {
    //TODO
    _ = self;
}

pub fn drawHealth(self: *const Self) void {
    const health_dist: u32 = if (self.health >= 0) @intFromFloat(@as(f32, @floatFromInt(w4.SCREEN_SIZE)) * (self.health / max_health)) else 0;
    w4.DRAW_COLORS.* = 4; // red
    w4.rect(0, 0, health_dist, 4);
    w4.DRAW_COLORS.* = 1;
    w4.rect(@intCast(health_dist), 0, w4.SCREEN_SIZE - health_dist, 4);
}
