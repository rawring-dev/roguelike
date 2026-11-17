const Self = @This();
const w4 = @import("wasm4.zig");

const sprite = [8]u8{ 0x00, 0x24, 0x24, 0x00, 0x24, 0x18, 0x00, 0x00 };

x: i32,
y: i32,

pub fn init() Self {
    return .{ .x = 0, .y = 0 };
}

pub fn update(self: *Self) void {
    if ((w4.GAMEPAD1.* & w4.BUTTON_LEFT) != 0) {
        self.x -= 1;
    }
    if ((w4.GAMEPAD1.* & w4.BUTTON_RIGHT) != 0) {
        self.x += 1;
    }
    if ((w4.GAMEPAD1.* & w4.BUTTON_UP) != 0) {
        self.y -= 1;
    }
    if ((w4.GAMEPAD1.* & w4.BUTTON_DOWN) != 0) {
        self.y += 1;
    }
}
pub fn draw(self: *const Self) void {
    _ = self;
    const w = 8;
    const h = 8;
    w4.DRAW_COLORS.* = 4;
    w4.blit(&sprite, w4.SCREEN_SIZE / 2 - (w / 2), w4.SCREEN_SIZE / 2 - (h / 2), w, h, w4.BLIT_1BPP);
}
