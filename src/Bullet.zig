const Self = @This();

x: f32,
y: f32,
vx: f32,
vy: f32,
// despawns when lifetime==0. Set to -1 to never despawn
lifetime: i32,

pub fn init(x: f32, y: f32, vx: f32, vy: f32, lifetime: i32) Self {
    return .{ .x = x, .y = y, .vx = vx, .vy = vy, .lifetime = lifetime };
}

pub fn update(self: *Self) void {
    self.x += self.vx;
    self.y += self.vy;
    self.lifetime -|= 1;
}
