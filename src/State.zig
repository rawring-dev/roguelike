const Self = @This();
const Player = @import("Player.zig");
const dungeon_generation = @import("dungeon_generation.zig");
const w4 = @import("wasm4.zig");
const std = @import("std");

const Dungeon = dungeon_generation.Dungeon;
const Bitmap = dungeon_generation.Bitmap;

const BUFFER_SIZE = 1024 * 4;

player: Player,
level_buffer: [BUFFER_SIZE]u8 = undefined,
fixed_buffer_allocator: std.heap.FixedBufferAllocator,
tiles: TileMap = @splat(@splat(TileType.empty)),

pub fn init() !Self {
    var self = Self{ .player = .init(), .fixed_buffer_allocator = undefined };
    self.reset_allocator();
    var dungeon = try dungeon_generation.generate_dungeon(self.fixed_buffer_allocator.allocator(), 1);
    defer dungeon.deinit();
    generate_dungeon(&self.tiles, dungeon);
    return self;
}

pub fn update(self: *Self) void {
    // update
    self.player.update();
    // draw
    self.draw_dungeon();
    self.player.draw();
}

const TileType = enum {
    empty,
    wall,
    room_floor,
    hallway_floor,

    replace_me,
};
const TileMap = [dungeon_generation.level_height][dungeon_generation.level_width]TileType;

// Take in tiles as an outparam to save on memory
fn generate_dungeon(tiles: *TileMap, dungeon: Dungeon) void {
    {
        var y: i32 = 0;
        while (y < dungeon_generation.level_height) : (y += 1) {
            var x: i32 = 0;
            blk: while (x < dungeon_generation.level_width) : (x += 1) {
                if (!dungeon.bitmap.is_set(x, y)) {
                    continue;
                }
                for (dungeon.room_slice()) |room| {
                    if (room.contains(x, y)) {
                        if (x == room.x or y == room.y or (x == room.x + room.w - 1) or (y == room.y + room.h - 1)) {
                            tiles[@intCast(y)][@intCast(x)] = .wall;
                        } else {
                            tiles[@intCast(y)][@intCast(x)] = .room_floor;
                        }
                        continue :blk;
                    }
                }
                tiles[@intCast(y)][@intCast(x)] = .hallway_floor;
            }
        }
    }
    // post processing
    for (0..dungeon_generation.level_height) |y| {
        for (0..dungeon_generation.level_width) |x| {
            if (tiles[y][x] == .wall) {
                if (is_touching(tiles, .hallway_floor, x, y)) {
                    tiles[y][x] = .replace_me;
                }
            }
            if (tiles[y][x] == .empty) {
                if (is_touching(tiles, .hallway_floor, x, y)) {
                    tiles[y][x] = .wall;
                }
            }
        }
    }
    for (0..dungeon_generation.level_height) |y| {
        std.mem.replaceScalar(TileType, &tiles[y], .replace_me, .hallway_floor);
    }
}

fn is_touching(tiles: *const TileMap, tile: TileType, x: usize, y: usize) bool {
    return (y != 0 and tiles[y - 1][x] == tile) or
        (y != dungeon_generation.level_height - 1 and tiles[y + 1][x] == tile) or
        (x != 0 and tiles[y][x - 1] == tile) or
        (x != dungeon_generation.level_width - 1 and tiles[y][x + 1] == tile);
}

fn draw_dungeon(self: *Self) void {
    const TILE_SIZE = 16;

    for (self.tiles, 0..) |row, y| {
        for (row, 0..) |tile, x| {
            w4.DRAW_COLORS.* = switch (tile) {
                .empty => 0,
                .hallway_floor => 2,
                .room_floor => 3,
                .wall => 4,
                .replace_me => @panic("found a replace_me"),
            };
            w4.rect(@as(i32, @intCast(x)) * TILE_SIZE - self.player.x, @as(i32, @intCast(y)) * TILE_SIZE - self.player.y, TILE_SIZE, TILE_SIZE);
        }
    }
}

fn reset_allocator(self: *Self) void {
    // discard all previous allocations
    self.fixed_buffer_allocator = std.heap.FixedBufferAllocator.init(&self.level_buffer);
}
