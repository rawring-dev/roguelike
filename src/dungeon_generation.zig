const std = @import("std");
const ringbuf = @import("ringbuf.zig");
const RingBuffer = ringbuf.RingBuffer;

pub const Dungeon = struct {
    bitmap: BitMap,

    pub fn deinit(self: *Dungeon) void {
        self.bitmap.deinit();
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

pub fn generate_dungeon(alloc: std.mem.Allocator) !Dungeon {
    const dungeon = Dungeon{ .bitmap = try BitMap.init(alloc) };
    return dungeon;
}
