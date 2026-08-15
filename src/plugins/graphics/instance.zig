const std = @import("std");

const Vec4 = @import("../../math/vec4.zig").Vec4;

pub const Instance = extern struct {
    position: Vec4,
};

comptime {
    std.debug.assert(@sizeOf(Instance) == 16);
}
