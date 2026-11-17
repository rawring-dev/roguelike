const std = @import("std");

pub const level_width = 64;
pub const level_height = 80;

pub const max_rooms = 32;

pub const Room = struct {
    comptime {
        if (level_width > 255 or level_height > 255)
            @compileError("Room stores coordinates in u8; keep the level below 256 tiles");
    }

    x: u8,
    y: u8,
    w: u8,
    h: u8,

    pub fn center_x(self: Room) i32 {
        return @as(i32, self.x) + @divTrunc(@as(i32, self.w), 2);
    }

    pub fn center_y(self: Room) i32 {
        return @as(i32, self.y) + @divTrunc(@as(i32, self.h), 2);
    }

    pub fn contains(self: Room, x: i32, y: i32) bool {
        return x >= self.x and x < @as(i32, self.x) + self.w and
            y >= self.y and y < @as(i32, self.y) + self.h;
    }

    pub fn intersects(self: Room, other: Room) bool {
        return self.x < @as(i32, other.x) + other.w and
            other.x < @as(i32, self.x) + self.w and
            self.y < @as(i32, other.y) + other.h and
            other.y < @as(i32, self.y) + self.h;
    }
};

pub const Dungeon = struct {
    bitmap: BitMap = .{},
    rooms: [max_rooms]Room = undefined,
    room_count: usize = 0,

    pub fn room_slice(self: *const Dungeon) []const Room {
        return self.rooms[0..self.room_count];
    }
};

pub const BitMap = struct {
    const Self = @This();

    pub const Word = usize;
    const word_bits = @bitSizeOf(Word);
    const Shift = std.math.Log2Int(Word);
    const words_per_row = @divTrunc(level_width + word_bits - 1, word_bits);
    const RowStore = [words_per_row]Word;

    bits: [level_height]RowStore = [_]RowStore{[_]Word{0} ** words_per_row} ** level_height,

    pub fn is_set(self: *const Self, x: isize, y: isize) bool {
        if (!in_bounds(x, y)) return false;
        const shift: Shift = @intCast(@mod(x, word_bits));
        const word = self.bits[@intCast(y)][@intCast(@divFloor(x, word_bits))];
        return (word >> shift) & 1 != 0;
    }

    pub fn set_rect(self: *Self, w: isize, h: isize, x: isize, y: isize) void {
        if (w <= 0 or h <= 0) return;

        const x0 = @max(x, 0);
        const x1 = @min(x + w, level_width);
        if (x0 >= x1) return;

        const y0 = @max(y, 0);
        const y1 = @min(y + h, level_height);
        if (y0 >= y1) return;

        var row_index = y0;
        while (row_index < y1) : (row_index += 1) {
            set_row_bits(&self.bits[@intCast(row_index)], x0, x1);
        }
    }

    pub fn intersects_rect(self: *const Self, w: isize, h: isize, x: isize, y: isize) bool {
        if (w <= 0 or h <= 0) return false;

        const x0 = @max(x, 0);
        const x1 = @min(x + w, level_width);
        if (x0 >= x1) return false;

        const y0 = @max(y, 0);
        const y1 = @min(y + h, level_height);
        if (y0 >= y1) return false;

        var row_index = y0;
        while (row_index < y1) : (row_index += 1) {
            if (row_intersects(&self.bits[@intCast(row_index)], x0, x1)) return true;
        }
        return false;
    }

    fn in_bounds(x: isize, y: isize) bool {
        return x >= 0 and y >= 0 and x < level_width and y < level_height;
    }

    fn set_row_bits(row: *RowStore, start_x: isize, end_x: isize) void {
        var wi = @divFloor(start_x, word_bits);
        const last_word = @divFloor(end_x - 1, word_bits);

        while (wi <= last_word) : (wi += 1) {
            const word_start = wi * word_bits;
            const lo = @max(start_x, word_start);
            const hi = @min(end_x, word_start + word_bits);
            row[@intCast(wi)] |= low_mask(@intCast(hi - lo)) << @as(Shift, @intCast(lo - word_start));
        }
    }

    fn row_intersects(row: *const RowStore, start_x: isize, end_x: isize) bool {
        var wi = @divFloor(start_x, word_bits);
        const last_word = @divFloor(end_x - 1, word_bits);

        while (wi <= last_word) : (wi += 1) {
            const word_start = wi * word_bits;
            const lo = @max(start_x, word_start);
            const hi = @min(end_x, word_start + word_bits);
            const mask = low_mask(@intCast(hi - lo)) << @as(Shift, @intCast(lo - word_start));
            if (row[@intCast(wi)] & mask != 0) return true;
        }
        return false;
    }

    fn low_mask(n: u32) Word {
        if (n >= word_bits) return std.math.maxInt(Word);
        return (@as(Word, 1) << @as(Shift, @intCast(n))) - 1;
    }
};

const min_leaf = 16;
const max_leaf = 24;
const max_depth = 10;

const room_padding = 1;
const min_room = 12;

const wander_percent = 30;
const skip_link_percent = 0;

/// Corridors are carved with a square brush of this size (in tiles).
const corridor_width = 2;

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

    fn build(self: *Generator, rect: Rect, depth: u32) void {
        const can_split_w = rect.w >= 2 * min_leaf;
        const can_split_h = rect.h >= 2 * min_leaf;
        const small_enough = rect.w <= max_leaf and rect.h <= max_leaf;

        if (depth >= max_depth or small_enough or (!can_split_w and !can_split_h)) {
            self.place_room(rect);
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
            self.build(.{ .x = rect.x, .y = rect.y, .w = split, .h = rect.h }, depth + 1);
            self.build(.{ .x = rect.x + split, .y = rect.y, .w = rect.w - split, .h = rect.h }, depth + 1);
        } else {
            const split = self.rng.range(min_leaf, rect.h - min_leaf);
            self.build(.{ .x = rect.x, .y = rect.y, .w = rect.w, .h = split }, depth + 1);
            self.build(.{ .x = rect.x, .y = rect.y + split, .w = rect.w, .h = rect.h - split }, depth + 1);
        }
    }

    fn place_room(self: *Generator, leaf: Rect) void {
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

        const room = Room{
            .x = @intCast(x),
            .y = @intCast(y),
            .w = @intCast(w),
            .h = @intCast(h),
        };
        self.dungeon.bitmap.set_rect(w, h, x, y);

        self.dungeon.rooms[self.dungeon.room_count] = room;
        self.dungeon.room_count += 1;
    }

    fn connect_rooms(self: *Generator) void {
        const count = self.dungeon.room_count;
        if (count < 2) return;

        var i: usize = 0;
        while (i + 1 < count) : (i += 1) {
            self.carve_corridor(self.dungeon.rooms[i], self.dungeon.rooms[i + 1]);

            if (i + 2 < count and self.rng.chance(skip_link_percent)) {
                const j: usize = @intCast(self.rng.range(@intCast(i + 2), @intCast(count - 1)));
                self.carve_corridor(self.dungeon.rooms[i], self.dungeon.rooms[j]);
            }
        }
    }

    fn carve_corridor(self: *Generator, from: Room, to: Room) void {
        const to_x = to.center_x();
        const to_y = to.center_y();

        const from_x: i32 = from.x;
        const from_y: i32 = from.y;
        const from_w: i32 = from.w;
        const from_h: i32 = from.h;

        const dx = to_x - from.center_x();
        const dy = to_y - from.center_y();

        var x: i32 = undefined;
        var y: i32 = undefined;
        if (@abs(dx) >= @abs(dy)) {
            x = if (dx >= 0) from_x + from_w else from_x - 1;
            y = self.rng.range(from_y, from_y + from_h - 1);
        } else {
            y = if (dy >= 0) from_y + from_h else from_y - 1;
            x = self.rng.range(from_x, from_x + from_w - 1);
        }

        const max_steps: u32 = 4 * (@abs(dx) + @abs(dy)) + 32;

        var steps: u32 = 0;
        while (steps < max_steps) : (steps += 1) {
            self.dungeon.bitmap.set_rect(corridor_width, corridor_width, x, y);
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

        self.carve_l_path(x, y, to_x, to_y);
    }

    fn carve_l_path(self: *Generator, from_x: i32, from_y: i32, to_x: i32, to_y: i32) void {
        var x = from_x;
        while (x != to_x) : (x += std.math.sign(to_x - from_x)) {
            self.dungeon.bitmap.set_rect(corridor_width, corridor_width, x, from_y);
        }
        var y = from_y;
        while (y != to_y) : (y += std.math.sign(to_y - from_y)) {
            self.dungeon.bitmap.set_rect(corridor_width, corridor_width, to_x, y);
        }
    }
};

pub fn generate_dungeon(seed: u64) Dungeon {
    var dungeon = Dungeon{};

    var generator = Generator{
        .dungeon = &dungeon,
        .rng = Rng.init(seed),
    };

    generator.build(.{ .x = 0, .y = 0, .w = level_width, .h = level_height }, 0);
    generator.connect_rooms();

    return dungeon;
}
