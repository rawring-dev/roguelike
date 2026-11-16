const std = @import("std");
const dungeon_generation = @import("dungeon_generation.zig");

const default_seed: u64 = 1;

pub fn main(init: std.process.Init) !void {
    var arg_it = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer arg_it.deinit();
    _ = arg_it.next();

    var seed: u64 = default_seed;
    if (arg_it.next()) |arg| {
        seed = std.fmt.parseInt(u64, arg, 0) catch {
            std.log.err("invalid seed '{s}' (expected a number, e.g. 42 or 0xdead)", .{arg});
            return error.InvalidSeed;
        };
    }

    var dungeon = try dungeon_generation.generate_dungeon(init.gpa, seed);
    defer dungeon.deinit();

    var stdout_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const out = &stdout.interface;

    try out.print("seed {d}: {d} rooms, {d}x{d}\n", .{
        seed,
        dungeon.room_count,
        dungeon_generation.level_width,
        dungeon_generation.level_height,
    });

    var row: [dungeon_generation.level_width]u8 = undefined;
    var y: i32 = 0;
    while (y < dungeon_generation.level_height) : (y += 1) {
        var x: i32 = 0;
        while (x < dungeon_generation.level_width) : (x += 1) {
            row[@intCast(x)] = cell_char(&dungeon, x, y);
        }
        try out.writeAll(&row);
        try out.writeAll("\n");
    }

    try out.flush();
}

fn cell_char(dungeon: *const dungeon_generation.Dungeon, x: i32, y: i32) u8 {
    if (!dungeon.bitmap.is_set(x, y)) return '.';
    for (dungeon.room_slice()) |room| {
        if (room.contains(x, y)) return 'R';
    }
    return '#';
}
