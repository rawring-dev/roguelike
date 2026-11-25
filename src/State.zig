const Self = @This();
const Player = @import("Player.zig");
const Cat = @import("Cat.zig");
const BulletYarn = @import("BulletYarn.zig");
const SlotArray = @import("slot_array.zig").SlotArray;
const BulletsInterface = @import("bullets_interface.zig").Interface;
const dungeon_generation = @import("dungeon_generation.zig");
const w4 = @import("wasm4.zig");
const std = @import("std");

const Dungeon = dungeon_generation.Dungeon;
const BUFFER_SIZE = 1024 * 4;
const YarnBullets = SlotArray(BulletYarn, 50);

player: Player,
level_buffer: [BUFFER_SIZE]u8 = undefined,
fixed_buffer_allocator: std.heap.FixedBufferAllocator,
tiles: TileMap = @splat(@splat(TileType.empty)),
cats: std.ArrayList(Cat),
yarn_bullets: YarnBullets,

pub fn init(self: *Self) void {
    self.reset_allocator();
    self.player = .init();
    self.tiles = @splat(@splat(TileType.empty));
    self.cats = .empty;
    //TESTING
    self.cats.append(self.fixed_buffer_allocator.allocator(), .init(23, 23)) catch {};

    const dungeon = dungeon_generation.generate_dungeon(1);
    generate_dungeon(&self.tiles, dungeon);
}
pub fn update(self: *Self) void {
    // update
    self.player.update();
    const yarn_bullets_interface = BulletsInterface(YarnBullets, BulletYarn){ .ptr = &self.yarn_bullets, .vtable = &.{
        .append = &YarnBullets.append,
    } };
    for (self.cats.items) |*cat| {
        cat.update(self.player.x, self.player.y, yarn_bullets_interface);
    }
    {
        var iter = self.yarn_bullets.iterator();
        while (iter.next()) |bullet| {
            if (bullet.bullet.lifetime == 0) {
                self.yarn_bullets.buffer[iter.index - 1] = null;
                continue;
            }
            bullet.update();
        }
    }
    // draw
    self.draw_dungeon();
    self.player.draw();
    for (self.cats.items) |*cat| {
        cat.draw(self.player.camera_x, self.player.camera_y);
    }
    {
        var iter = self.yarn_bullets.iterator();
        while (iter.next()) |bullet| {
            bullet.draw(self.player.camera_x, self.player.camera_y);
        }
    }
}

const WallSides = packed struct {
    up: bool = false,
    down: bool = false,
    left: bool = false,
    right: bool = false,
};

const TileType = union(enum) {
    empty,
    wall: WallSides,
    room_floor,
    hallway_floor,

    replace_me,
};

const TileTypeEnum = std.meta.Tag(TileType);

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
                            tiles[@intCast(y)][@intCast(x)] = .{ .wall = .{} };
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
                    tiles[y][x] = .{ .wall = .{} };
                }
            }
        }
    }
    for (tiles) |*row| {
        for (row) |*tile| {
            if (tile.* == .replace_me) {
                tile.* = .hallway_floor;
            }
        }
    }
    for (0..dungeon_generation.level_height) |y| {
        for (0..dungeon_generation.level_width) |x| {
            if (tiles[y][x] == .wall) {
                tiles[y][x].wall.up = y > 0 and tiles[y - 1][x] != .empty and tiles[y - 1][x] != .wall;
                tiles[y][x].wall.left = x > 0 and tiles[y][x - 1] != .empty and tiles[y][x - 1] != .wall;
                tiles[y][x].wall.right = x != dungeon_generation.level_width -| 1 and tiles[y][x + 1] != .empty and tiles[y][x + 1] != .wall;
                tiles[y][x].wall.down = y != dungeon_generation.level_height -| 1 and tiles[y + 1][x] != .empty and tiles[y + 1][x] != .wall;
            }
        }
    }
    for (tiles, 0..) |row, y| {
        for (row, 0..) |tile, x| {
            if (tile == .replace_me) {
                w4.tracef("found a replace_me at %d %d", @as(u32, x), @as(u32, y));
                @panic("found a replace_me");
            }
        }
    }
}

fn is_touching(tiles: *const TileMap, tile: TileTypeEnum, x: usize, y: usize) bool {
    return (y != 0 and @as(TileTypeEnum, tiles[y - 1][x]) == tile) or
        (y != dungeon_generation.level_height - 1 and @as(TileTypeEnum, tiles[y + 1][x]) == tile) or
        (x != 0 and @as(TileTypeEnum, tiles[y][x - 1]) == tile) or
        (x != dungeon_generation.level_width - 1 and @as(TileTypeEnum, tiles[y][x + 1]) == tile);
}

fn draw_dungeon(self: *Self) void {
    const TILE_SIZE = 16;
    const sprite_0 = [8]u8{ 0xee, 0xff, 0xee, 0x44, 0xee, 0xff, 0xee, 0x44 };
    const sprite_1 = [8]u8{ 0x67, 0xfe, 0x3b, 0x29, 0xbd, 0xf7, 0x4d, 0xc5 };
    const wall_0 = [8]u8{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xab, 0x66, 0x00 };
    const wall_1 = [8]u8{ 0xfc, 0xfe, 0xfc, 0xf8, 0xfe, 0xfe, 0xfa, 0xfc };
    const wall_2 = [8]u8{ 0x00, 0x66, 0xaf, 0xff, 0xff, 0xff, 0xff, 0xff };
    const wall_3 = [8]u8{ 0x5f, 0x7f, 0x5f, 0x1f, 0x3f, 0x7f, 0x3f, 0x3f };

    for (&self.tiles, 0..) |row, y| {
        for (row, 0..) |tile, x| {
            w4.DRAW_COLORS.* = switch (tile) {
                .empty => 0,
                .hallway_floor => 2,
                .room_floor => 2,
                .wall => 3,
                .replace_me => unreachable,
            };
            switch (tile) {
                .hallway_floor => {
                    w4.blit(&sprite_1, @as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y, 8, 8, w4.BLIT_1BPP);
                    w4.blit(&sprite_1, @as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x + 8, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y, 8, 8, w4.BLIT_1BPP);
                    w4.blit(&sprite_1, @as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x + 8, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y + 8, 8, 8, w4.BLIT_1BPP);
                    w4.blit(&sprite_1, @as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y + 8, 8, 8, w4.BLIT_1BPP);
                },
                .room_floor => {
                    w4.blit(&sprite_0, @as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y, 8, 8, w4.BLIT_1BPP);
                    w4.blit(&sprite_0, @as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x + 8, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y, 8, 8, w4.BLIT_1BPP);
                    w4.blit(&sprite_0, @as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x + 8, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y + 8, 8, 8, w4.BLIT_1BPP);
                    w4.blit(&sprite_0, @as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y + 8, 8, 8, w4.BLIT_1BPP);
                },
                .wall => |sides| {
                    if (sides.up) {
                        w4.blit(&wall_2, @as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y, 8, 8, w4.BLIT_1BPP);
                        w4.blit(&wall_2, @as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x + 8, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y, 8, 8, w4.BLIT_1BPP);
                    }
                    if (sides.right) {
                        w4.blit(&wall_1, @as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x + 8, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y, 8, 8, w4.BLIT_1BPP);
                        w4.blit(&wall_1, @as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x + 8, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y + 8, 8, 8, w4.BLIT_1BPP);
                    }
                    if (sides.left) {
                        w4.blit(&wall_3, @as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y, 8, 8, w4.BLIT_1BPP);
                        w4.blit(&wall_3, @as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y + 8, 8, 8, w4.BLIT_1BPP);
                    }
                    if (sides.down) {
                        w4.blit(&wall_0, @as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y + 8, 8, 8, w4.BLIT_1BPP);
                        w4.blit(&wall_0, @as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x + 8, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y + 8, 8, 8, w4.BLIT_1BPP);
                    }
                },
                else => {
                    w4.rect(@as(i32, @intCast(x)) * TILE_SIZE - self.player.camera_x, @as(i32, @intCast(y)) * TILE_SIZE - self.player.camera_y, TILE_SIZE, TILE_SIZE);
                },
            }
        }
    }
}

fn reset_allocator(self: *Self) void {
    // discard all previous allocations
    self.fixed_buffer_allocator = std.heap.FixedBufferAllocator.init(&self.level_buffer);
}
