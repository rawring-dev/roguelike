const Self = @This();
const w4 = @import("wasm4.zig");
const Bullet = @import("Bullet.zig");

const w = 8;
const h = 8;
const sprite = [8]u8{ 0xff, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0xff };

bullet: Bullet,

pub fn init(bullet: Bullet) Self {
    return .{ .bullet = bullet };
}

pub fn update(self: *Self) void {
    self.bullet.update();
}
pub fn draw(self: *const Self, camera_x: i32, camera_y: i32) void {
    w4.DRAW_COLORS.* = 0x41;
    w4.blit(&sprite, @as(i32, @trunc(self.bullet.x)) - camera_x, @as(i32, @trunc(self.bullet.y)) - camera_y, w, h, w4.BLIT_1BPP);
}
