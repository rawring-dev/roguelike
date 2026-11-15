const Self = @This();
const Player = @import("Player.zig");

camera_x: i32,
camera_y: i32,
player: Player,

fn init() Self {
    return Self{ .camera_x = 0, .camera_y = 0, .player = .init() };
}
