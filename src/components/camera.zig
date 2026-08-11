const std = @import("std");

pub const Camera = struct {
    fov_y: f32 = std.math.degreesToRadians(60),
    near: f32 = 0.1,
    far: f32 = 1000,
};
