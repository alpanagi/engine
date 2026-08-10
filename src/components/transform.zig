const Quat = @import("../math/quat.zig").Quat;
const Vec4 = @import("../math/vec4.zig").Vec4;

pub const Transform = struct {
    position: Vec4 = .{ 0, 0, 0, 1 },
    rotation: Quat = .{ 0, 0, 0, 1 },
    scale: Vec4 = .{ 1, 1, 1, 1 },
};