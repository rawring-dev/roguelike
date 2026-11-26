const Self = @This();
const w4 = @import("wasm4.zig");
const collision = @import("collision.zig");
const BitMap = @import("dungeon_generation.zig").BitMap;

const w = 8;
const h = 8;
const sprite = [8]u8{ 0x00, 0x24, 0x24, 0x00, 0x24, 0x18, 0x00, 0x00 };
const half_width: i32 = w4.SCREEN_SIZE / 2 - (w / 2);
const half_height: i32 = w4.SCREEN_SIZE / 2 - (h / 2);

x: f32,
y: f32,
camera_x: i32,
camera_y: i32,
health: f32,

pub fn init() Self {
    return .{
        .x = half_width,
        .y = half_height,
        .camera_x = 0,
        .camera_y = 0,
        .health = 100,
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
