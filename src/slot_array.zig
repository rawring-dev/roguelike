const std = @import("std");

pub fn SlotArray(T: type, length: usize) type {
    return struct {
        const Self = @This();

        buffer: [length]?T = @splat(null),

        const Iterator = struct {
            index: usize = 0,
            buffer: []?T,

            pub fn next(self: *Iterator) ?*T {
                if (self.index >= self.buffer.len) return null;
                for (self.index..self.buffer.len) |i| {
                    if (self.buffer[i]) |*value| {
                        self.index = i + 1;
                        return value;
                    }
                }
                return null;
            }

            pub fn removeCurrent(self: *const Iterator) void {
                self.buffer[self.index - 1] = null;
            }
        };

        pub fn iterator(self: *Self) Iterator {
            return Iterator{ .buffer = &self.buffer };
        }

        pub fn append(self: *Self, value: T) error{OutOfMemory}!void {
            for (0..length) |i| {
                if (self.buffer[i] == null) {
                    self.buffer[i] = value;
                    return;
                }
            }
            return error.OutOfMemory;
        }
    };
}
