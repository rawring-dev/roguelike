const std = @import("std");

const Vec2 = @Vector(2, f32);

pub fn dot(a: Vec2, b: Vec2) f32 {
    return @reduce(.Add, a * b);
}

pub fn length(vec: Vec2) f32 {
    return std.math.sqrt(dot(vec, vec));
}

pub fn normalize(x: f32, y: f32) Vec2 {
    const vec: Vec2 = .{ x, y };
    const len = length(vec);
    if (len < 1e-6) return vec; // zero vector has no direction
    const len_vec: Vec2 = @splat(len);
    return vec / len_vec;
}

pub fn setLength(x: f32, y: f32, len: f32) Vec2 {
    return normalize(x, y) * @as(Vec2, @splat(len));
}
