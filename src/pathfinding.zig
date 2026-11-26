const std = @import("std");
const dungeon_generation = @import("dungeon_generation.zig");
const BitMap = dungeon_generation.BitMap;

pub const Cell = struct {
    x: i16,
    y: i16,
};

pub const beam_width = 4;

pub const Pathfinder = struct {
    const Self = @This();

    const width = dungeon_generation.level_width;
    const height = dungeon_generation.level_height;
    const cell_count = width * height;
    const closed_words = @divTrunc(cell_count + 63, 64);
    const no_parent = std.math.maxInt(u16);

    const straight_cost: u32 = 10;
    const diagonal_cost: u32 = 14;

    const Node = struct {
        index: u16,
        g: u32,
        h: u32,
    };

    const Dir = struct {
        dx: i32,
        dy: i32,
    };

    const dirs = [_]Dir{
        .{ .dx = 1, .dy = 0 },
        .{ .dx = -1, .dy = 0 },
        .{ .dx = 0, .dy = 1 },
        .{ .dx = 0, .dy = -1 },
        .{ .dx = 1, .dy = 1 },
        .{ .dx = 1, .dy = -1 },
        .{ .dx = -1, .dy = 1 },
        .{ .dx = -1, .dy = -1 },
    };

    parent: [cell_count]u16 = undefined,
    closed: [closed_words]u64 = undefined,

    pub fn find_path(
        self: *Self,
        map: *const BitMap,
        start: Cell,
        goal: Cell,
        out: []Cell,
    ) ?usize {
        if (out.len == 0) return null;

        const start_index = cell_index(start) orelse return null;
        const goal_index = cell_index(goal) orelse return null;
        if (!walkable(map, start.x, start.y) or !walkable(map, goal.x, goal.y)) return null;

        @memset(&self.parent, no_parent);
        @memset(&self.closed, 0);

        if (start_index == goal_index) {
            out[0] = start;
            return 1;
        }

        mark_closed(self, start_index);

        var beam: [beam_width]Node = undefined;
        var beam_len: usize = 1;
        beam[0] = .{ .index = start_index, .g = 0, .h = heuristic(start, goal) };

        var candidates: [beam_width * 8]Node = undefined;
        var iterations: usize = 0;

        while (beam_len > 0 and iterations < cell_count) : (iterations += 1) {
            var candidate_len: usize = 0;

            for (beam[0..beam_len]) |node| {
                const from = cell_of(node.index);
                const cx: i32 = from.x;
                const cy: i32 = from.y;

                for (dirs) |dir| {
                    const nx = cx + dir.dx;
                    const ny = cy + dir.dy;

                    const next_index = cell_index_coords(nx, ny) orelse continue;
                    if (is_closed(self, next_index)) continue;
                    if (!walkable(map, nx, ny)) continue;

                    const is_diagonal = dir.dx != 0 and dir.dy != 0;
                    if (is_diagonal) {
                        if (!walkable(map, cx + dir.dx, cy) or !walkable(map, cx, cy + dir.dy)) continue;
                    }

                    self.parent[next_index] = node.index;

                    const step = if (is_diagonal) diagonal_cost else straight_cost;
                    candidates[candidate_len] = .{
                        .index = next_index,
                        .g = node.g + step,
                        .h = heuristic(.{ .x = @intCast(nx), .y = @intCast(ny) }, goal),
                    };
                    candidate_len += 1;

                    if (next_index == goal_index) {
                        return self.reconstruct(start_index, goal_index, out);
                    }
                }
            }

            sort_by_f(candidates[0..candidate_len]);

            beam_len = 0;
            for (candidates[0..candidate_len]) |candidate| {
                if (beam_len == beam_width) break;
                if (is_closed(self, candidate.index)) continue;

                mark_closed(self, candidate.index);
                beam[beam_len] = candidate;
                beam_len += 1;
            }
        }

        return null;
    }

    fn reconstruct(self: *const Self, start_index: u16, goal_index: u16, out: []Cell) ?usize {
        var index = goal_index;
        var len: usize = 0;

        while (true) {
            if (len == out.len) return null;
            out[len] = cell_of(index);
            len += 1;

            if (index == start_index) break;

            index = self.parent[index];
            if (index == no_parent) return null;
        }

        var i: usize = 0;
        while (i < len / 2) : (i += 1) {
            const tmp = out[i];
            out[i] = out[len - 1 - i];
            out[len - 1 - i] = tmp;
        }

        return len;
    }

    fn mark_closed(self: *Self, index: u16) void {
        self.closed[index / 64] |= @as(u64, 1) << @intCast(index % 64);
    }

    fn is_closed(self: *const Self, index: u16) bool {
        return self.closed[index / 64] & (@as(u64, 1) << @intCast(index % 64)) != 0;
    }
};

fn walkable(map: *const BitMap, x: i32, y: i32) bool {
    return map.is_set(x, y);
}

fn cell_index(cell: Cell) ?u16 {
    return cell_index_coords(cell.x, cell.y);
}

fn cell_index_coords(x: i32, y: i32) ?u16 {
    if (x < 0 or y < 0 or x >= dungeon_generation.level_width or y >= dungeon_generation.level_height) return null;
    const width = dungeon_generation.level_width;
    return @intCast(@as(usize, @intCast(y)) * width + @as(usize, @intCast(x)));
}

fn cell_of(index: u16) Cell {
    const width = dungeon_generation.level_width;
    return .{
        .x = @intCast(index % width),
        .y = @intCast(index / width),
    };
}

fn heuristic(a: Cell, b: Cell) u32 {
    const dx: u32 = @intCast(@abs(@as(i32, b.x) - a.x));
    const dy: u32 = @intCast(@abs(@as(i32, b.y) - a.y));
    const diagonal = @min(dx, dy);
    const straight = @max(dx, dy) - diagonal;
    return diagonal * 14 + straight * 10;
}

fn sort_by_f(nodes: []Pathfinder.Node) void {
    var i: usize = 1;
    while (i < nodes.len) : (i += 1) {
        const key = nodes[i];
        var j = i;
        while (j > 0 and less(key, nodes[j - 1])) : (j -= 1) {
            nodes[j] = nodes[j - 1];
        }
        nodes[j] = key;
    }
}

fn less(a: Pathfinder.Node, b: Pathfinder.Node) bool {
    const fa = a.g + a.h;
    const fb = b.g + b.h;
    if (fa != fb) return fa < fb;
    return a.h < b.h;
}
