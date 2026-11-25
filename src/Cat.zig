const Self = @This();
const std = @import("std");
const w4 = @import("wasm4.zig");
const BulletYarn = @import("BulletYarn.zig");
const Bullet = @import("Bullet.zig");
const SlotArray = @import("slot_array.zig").SlotArray;
const BulletsInterface = @import("bullets_interface.zig").Interface;
const YarnBulletsInterface = BulletsInterface(YarnBullets, BulletYarn);
const math = @import("math.zig");

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
const speed: i32 = 1;
const bullet_speed: i32 = 1;
const YarnBullets = SlotArray(BulletYarn, 50);
const bullet_timer_delay = 1;
const bullet_lifetime = 2;

x: f32,
y: f32,
bullet_timer: u32,

pub fn init(x: i32, y: i32) Self {
    return .{ .x = @floatFromInt(x), .y = @floatFromInt(y), .bullet_timer = bullet_timer_delay };
}

pub fn update(self: *Self, player_x: f32, player_y: f32, bullet_interface: YarnBulletsInterface) void {
    const player_distance = 64;
    const dist = std.math.hypot(player_x - self.x, player_y - self.y);
    if (dist > player_distance) {
        const dir = math.setLength(player_x - self.x, player_y - self.y, speed);

        self.x += dir[0];
        self.y += dir[1];
    } else {
        self.bullet_timer -|= 1;

        if (self.bullet_timer == 0) {
            const dir = math.setLength(player_x - self.x, player_y - self.y, bullet_speed);
            bullet_interface.append(.init(Bullet.init(
                self.x,
                self.y,
                dir[0],
                dir[1],
                bullet_lifetime * 60,
            ))) catch {};

            self.bullet_timer = bullet_timer_delay;
        }
    }
}
pub fn draw(self: *const Self, camera_x: i32, camera_y: i32) void {
    const w = 8;
    const h = 8;
    w4.DRAW_COLORS.* = 0x430;
    w4.blit(&sprite, @as(i32, @trunc(self.x)) - camera_x, @as(i32, @trunc(self.y)) - camera_y, w, h, w4.BLIT_2BPP);
}
