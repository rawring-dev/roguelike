const std = @import("std");

pub fn RingBuffer(comptime T: type, comptime DefaultValue: T) type {
    return struct {
        const Self = @This();

        buffer: []T,
        alloc: std.mem.Allocator,

        min: isize = 0,

        pub fn init(alloc: std.mem.Allocator) !Self {
            const buffer = try alloc.alloc(T, 8);
            for (buffer) |*slot| slot.* = DefaultValue;
            return .{ .buffer = buffer, .alloc = alloc };
        }

        pub fn deinit(self: *Self) void {
            self.alloc.free(self.buffer);
        }

        pub fn contains(self: *const Self, index: isize) bool {
            return index >= self.min and index < self.min + @as(isize, @intCast(self.buffer.len));
        }

        pub fn get(self: *const Self, index: isize) ?T {
            if (!self.contains(index)) return null;
            return self.buffer[@intCast(index - self.min)];
        }

        pub fn expanding_get(self: *Self, index: isize) !*T {
            if (!self.contains(index)) try self.grow(index);
            return &self.buffer[@intCast(index - self.min)];
        }

        fn grow(self: *Self, index: isize) !void {
            const old_len = self.buffer.len;
            const old_min = self.min;
            const old_end = old_min + @as(isize, @intCast(old_len));

            var new_len = @max(old_len * 2, 8);
            var new_min = old_min;

            if (index < old_min) {
                const deficit: usize = @intCast(old_min - index);
                new_len = @max(new_len, old_len + deficit);
                new_min = old_min - @as(isize, @intCast(new_len - old_len));
            } else {
                const deficit: usize = @intCast(index - old_end + 1);
                new_len = @max(new_len, old_len + deficit);
            }

            const new_buffer = try self.alloc.alloc(T, new_len);
            for (new_buffer) |*slot| slot.* = DefaultValue;
            const offset: usize = @intCast(old_min - new_min);
            @memcpy(new_buffer[offset .. offset + old_len], self.buffer);
            self.alloc.free(self.buffer);
            self.buffer = new_buffer;
            self.min = new_min;
        }
    };
}
