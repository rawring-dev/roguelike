const std = @import("std");
const ringbuf = @import("ringbuf.zig");
const RingBuffer = ringbuf.RingBuffer;

/// Upper bound on the number of rooms a level can contain.
pub const max_rooms = 48;

pub const Room = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub fn center_x(self: Room) i32 {
        return self.x + @divTrunc(self.w, 2);
    }

    pub fn center_y(self: Room) i32 {
        return self.y + @divTrunc(self.h, 2);
    }

    pub fn contains(self: Room, x: i32, y: i32) bool {
        return x >= self.x and x < self.x + self.w and
            y >= self.y and y < self.y + self.h;
    }

    pub fn intersects(self: Room, other: Room) bool {
        return self.x < other.x + other.w and other.x < self.x + self.w and
            self.y < other.y + other.h and other.y < self.y + self.h;
    }
};

pub const Dungeon = struct {
    bitmap: BitMap,
    rooms: [max_rooms]Room = undefined,
    room_count: usize = 0,

    pub fn deinit(self: *Dungeon) void {
        self.bitmap.deinit();
    }

    pub fn room_slice(self: *const Dungeon) []const Room {
        return self.rooms[0..self.room_count];
    }
};

pub const BitMap = struct {
    const Self = @This();

    pub const Word = usize;
    const word_bits = @bitSizeOf(Word);
    const Shift = std.math.Log2Int(Word);
    const Row = RingBuffer(Word, 0);
    const RowBuffer = RingBuffer(?Row, null);

    rows: RowBuffer,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !Self {
        return .{ .rows = try RowBuffer.init(alloc), .alloc = alloc };
    }

    pub fn deinit(self: *Self) void {
        var i: usize = 0;
        while (i < self.rows.buffer.len) : (i += 1) {
            if (self.rows.buffer[i]) |*row| row.deinit();
        }
        self.rows.deinit();
    }

    pub fn is_set(self: *const Self, x: isize, y: isize) bool {
        const row = self.lookup_row(y) orelse return false;
        const word = row.get(@divFloor(x, word_bits)) orelse return false;
        const shift: Shift = @intCast(@mod(x, word_bits));
        return (word >> shift) & 1 != 0;
    }

    pub fn set_rect(self: *Self, w: isize, h: isize, x: isize, y: isize) !void {
        var dy: isize = 0;
        while (dy < h) : (dy += 1) {
            const row = try self.get_row(y + dy);
            try set_row_bits(row, w, x);
        }
    }

    pub fn intersects_rect(self: *const Self, w: isize, h: isize, x: isize, y: isize) bool {
        var dy: isize = 0;
        while (dy < h) : (dy += 1) {
            const row = self.lookup_row(y + dy) orelse continue;
            if (row_intersects(&row, w, x)) return true;
        }
        return false;
    }

    fn lookup_row(self: *const Self, y: isize) ?Row {
        const maybe_row = self.rows.get(y) orelse return null;
        return maybe_row;
    }

    fn get_row(self: *Self, y: isize) !*Row {
        const slot = try self.rows.expanding_get(y);
        if (slot.* == null) slot.* = try Row.init(self.alloc);
        return &slot.*.?;
    }

    fn set_row_bits(row: *Row, w: isize, start_x: isize) !void {
        const end_x = start_x + w;
        var wi = @divFloor(start_x, word_bits);
        const last_word = @divFloor(end_x - 1, word_bits);

        while (wi <= last_word) : (wi += 1) {
            const word_start = wi * word_bits;
            const lo = @max(start_x, word_start);
            const hi = @min(end_x, word_start + word_bits);
            const mask = low_mask(@intCast(hi - lo)) << @as(Shift, @intCast(lo - word_start));
            (try row.expanding_get(wi)).* |= mask;
        }
    }

    fn row_intersects(row: *const Row, w: isize, start_x: isize) bool {
        const end_x = start_x + w;
        var wi = @divFloor(start_x, word_bits);
        const last_word = @divFloor(end_x - 1, word_bits);

        while (wi <= last_word) : (wi += 1) {
            const word = row.get(wi) orelse continue;
            const word_start = wi * word_bits;
            const lo = @max(start_x, word_start);
            const hi = @min(end_x, word_start + word_bits);
            const mask = low_mask(@intCast(hi - lo)) << @as(Shift, @intCast(lo - word_start));
            if (word & mask != 0) return true;
        }
        return false;
    }

    fn low_mask(n: u32) Word {
        if (n >= word_bits) return std.math.maxInt(Word);
        return (@as(Word, 1) << @as(Shift, @intCast(n))) - 1;
    }
};

pub const level_width: i32 = 80;
pub const level_height: i32 = 80;

const min_leaf = 16;
const max_leaf = 24;
const max_depth = 10;

const room_padding = 1;
const min_room = 8;

const wander_percent = 50;
const skip_link_percent = 0;

const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
};

const Rng = struct {
    state: u32,

    fn init(seed: u64) Rng {
        var rng = Rng{ .state = @truncate(seed) };
        if (rng.state == 0) rng.state = 0x9e3779b9;
        return rng;
    }

    fn next(self: *Rng) u32 {
        var x = self.state;
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        self.state = x;
        return x;
    }

    fn range(self: *Rng, lo: i32, hi: i32) i32 {
        std.debug.assert(hi >= lo);
        const span: u32 = @intCast(hi - lo + 1);
        return lo + @as(i32, @intCast(self.next() % span));
    }

    fn chance(self: *Rng, percent: u32) bool {
        return self.next() % 100 < percent;
    }
};

const Generator = struct {
    dungeon: *Dungeon,
    rng: Rng,

    fn build(self: *Generator, rect: Rect, depth: u32) !void {
        const can_split_w = rect.w >= 2 * min_leaf;
        const can_split_h = rect.h >= 2 * min_leaf;
        const small_enough = rect.w <= max_leaf and rect.h <= max_leaf;

        if (depth >= max_depth or small_enough or (!can_split_w and !can_split_h)) {
            try self.place_room(rect);
            return;
        }

        const split_vertical = if (!can_split_w)
            false
        else if (!can_split_h)
            true
        else if (rect.w * 4 > rect.h * 5)
            true
        else if (rect.h * 4 > rect.w * 5)
            false
        else
            self.rng.chance(50);

        if (split_vertical) {
            const split = self.rng.range(min_leaf, rect.w - min_leaf);
            try self.build(.{ .x = rect.x, .y = rect.y, .w = split, .h = rect.h }, depth + 1);
            try self.build(.{ .x = rect.x + split, .y = rect.y, .w = rect.w - split, .h = rect.h }, depth + 1);
        } else {
            const split = self.rng.range(min_leaf, rect.h - min_leaf);
            try self.build(.{ .x = rect.x, .y = rect.y, .w = rect.w, .h = split }, depth + 1);
            try self.build(.{ .x = rect.x, .y = rect.y + split, .w = rect.w, .h = rect.h - split }, depth + 1);
        }
    }

    fn place_room(self: *Generator, leaf: Rect) !void {
        if (self.dungeon.room_count == max_rooms) return;

        const max_w = leaf.w - 2 * room_padding;
        const max_h = leaf.h - 2 * room_padding;
        if (max_w < min_room or max_h < min_room) return;

        const min_w = @max(min_room, @divTrunc(max_w * 2, 3));
        const min_h = @max(min_room, @divTrunc(max_h * 2, 3));
        const w = self.rng.range(min_w, max_w);
        const h = self.rng.range(min_h, max_h);
        const x = leaf.x + room_padding + self.rng.range(0, leaf.w - 2 * room_padding - w);
        const y = leaf.y + room_padding + self.rng.range(0, leaf.h - 2 * room_padding - h);

        const room = Room{ .x = x, .y = y, .w = w, .h = h };
        try self.dungeon.bitmap.set_rect(w, h, x, y);

        self.dungeon.rooms[self.dungeon.room_count] = room;
        self.dungeon.room_count += 1;
    }

    fn connect_rooms(self: *Generator) !void {
        const count = self.dungeon.room_count;
        if (count < 2) return;

        var i: usize = 0;
        while (i + 1 < count) : (i += 1) {
            try self.carve_corridor(self.dungeon.rooms[i], self.dungeon.rooms[i + 1]);

            if (i + 2 < count and self.rng.chance(skip_link_percent)) {
                const j: usize = @intCast(self.rng.range(@intCast(i + 2), @intCast(count - 1)));
                try self.carve_corridor(self.dungeon.rooms[i], self.dungeon.rooms[j]);
            }
        }
    }

    fn carve_corridor(self: *Generator, from: Room, to: Room) !void {
        const to_x = to.center_x();
        const to_y = to.center_y();
        const dx = to_x - from.center_x();
        const dy = to_y - from.center_y();

        var x: i32 = undefined;
        var y: i32 = undefined;
        if (@abs(dx) >= @abs(dy)) {
            x = if (dx >= 0) from.x + from.w else from.x - 1;
            y = self.rng.range(from.y, from.y + from.h - 1);
        } else {
            y = if (dy >= 0) from.y + from.h else from.y - 1;
            x = self.rng.range(from.x, from.x + from.w - 1);
        }

        const max_steps: u32 = 4 * (@abs(dx) + @abs(dy)) + 32;

        var steps: u32 = 0;
        while (steps < max_steps) : (steps += 1) {
            try self.dungeon.bitmap.set_rect(1, 1, x, y);
            if (to.contains(x, y)) return;

            if (self.rng.chance(wander_percent)) {
                switch (self.rng.next() % 4) {
                    0 => x += 1,
                    1 => x -= 1,
                    2 => y += 1,
                    else => y -= 1,
                }
            } else {
                const rem_x = to_x - x;
                const rem_y = to_y - y;
                if (@abs(rem_x) > @abs(rem_y)) {
                    x += std.math.sign(rem_x);
                } else if (rem_y != 0) {
                    y += std.math.sign(rem_y);
                } else {
                    x += std.math.sign(rem_x);
                }
            }

            x = std.math.clamp(x, 0, level_width - 1);
            y = std.math.clamp(y, 0, level_height - 1);
        }

        try self.carve_l_path(x, y, to_x, to_y);
    }

    fn carve_l_path(self: *Generator, from_x: i32, from_y: i32, to_x: i32, to_y: i32) !void {
        var x = from_x;
        while (x != to_x) : (x += std.math.sign(to_x - from_x)) {
            try self.dungeon.bitmap.set_rect(1, 1, x, from_y);
        }
        var y = from_y;
        while (y != to_y) : (y += std.math.sign(to_y - from_y)) {
            try self.dungeon.bitmap.set_rect(1, 1, to_x, y);
        }
    }
};

pub fn generate_dungeon(alloc: std.mem.Allocator, seed: u64) !Dungeon {
    var dungeon = Dungeon{ .bitmap = try BitMap.init(alloc) };
    errdefer dungeon.deinit();

    var generator = Generator{
        .dungeon = &dungeon,
        .rng = Rng.init(seed),
    };

    try generator.build(.{ .x = 0, .y = 0, .w = level_width, .h = level_height }, 0);

    try generator.connect_rooms();

    return dungeon;
}
