const w4 = @import("wasm4.zig");
const State = @import("State.zig");

var state: State = undefined;
var static_error: ?anyerror = null;

export fn start() void {
    state = State.init() catch |e| {
        w4.trace(@errorName(e));
        static_error = e;
        return;
    };
}

export fn update() void {
    if (static_error) |e| {
        w4.DRAW_COLORS.* = 4;
        w4.text(@errorName(e), 0, 0);
    } else {
        state.update();
    }
}
