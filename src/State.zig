const Self = @This();
const Player = @import("Player.zig");
const dungeon_generation = @import("dungeon_generation.zig");
const w4 = @import("wasm4.zig");
const std = @import("std");

const Dungeon = dungeon_generation.Dungeon;
const Bitmap = dungeon_generation.Bitmap;

const BUFFER_SIZE = 1024 * 5;

player: Player,
dungeon: Dungeon,
level_buffer: [BUFFER_SIZE]u8 = undefined,
fixed_buffer_allocator: std.heap.FixedBufferAllocator,

pub fn init() !Self {
    var self = Self{ .player = .init(), .fixed_buffer_allocator = undefined, .dungeon = undefined };
    self.reset_allocator();
    self.dungeon = try dungeon_generation.generate_dungeon(self.fixed_buffer_allocator.allocator(), 0);

    return self;
}

pub fn update(self: *Self) void {
    // update
    self.player.update();
    // draw
    self.draw_dungeon();
    self.player.draw();
}

fn draw_dungeon(self: *Self) void {
    for (self.dungeon.rooms) |room| {
        w4.rect(room.x * 8 - self.player.x, room.y * 8 - self.player.y, @intCast(room.w * 8), @intCast(room.h * 8));
    }
}

fn reset_allocator(self: *Self) void {
    // discard all previous allocations
    self.fixed_buffer_allocator = std.heap.FixedBufferAllocator.init(&self.level_buffer);
}
