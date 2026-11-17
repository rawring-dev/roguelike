const w4 = @import("wasm4.zig");
const State = @import("State.zig");

var state: State = undefined;
var static_error: ?anyerror = null;

export fn start() void {
    w4.PALETTE.* = .{
        0x20202f,
        0x80808f,
        0xf0f0ff,
        0xd00040,
    };
    state.init();
}

export fn update() void {
    if (static_error) |e| {
        w4.DRAW_COLORS.* = 4;
        w4.text(@errorName(e), 0, 0);
    } else {
        state.update();
    }
}
