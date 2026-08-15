const mat4 = @import("../../math/mat4.zig");
const quat = @import("../../math/quat.zig");

const Mat4 = mat4.Mat4;
const Quat = quat.Quat;
const Vec4 = @import("../../math/vec4.zig").Vec4;

pub fn viewFromTransform(position: Vec4, rotation: Quat) Mat4 {
    var result = mat4.fromRotation(quat.conjugate(rotation));

    result[3] = .{
        -(result[0][0] * position[0] + result[1][0] * position[1] + result[2][0] * position[2]),
        -(result[0][1] * position[0] + result[1][1] * position[1] + result[2][1] * position[2]),
        -(result[0][2] * position[0] + result[1][2] * position[1] + result[2][2] * position[2]),
        1,
    };

    return result;
}

pub fn perspective(fov_y: f32, aspect: f32, near: f32, far: f32) Mat4 {
    const f = 1 / @tan(fov_y * 0.5);
    const depth = near - far;

    return .{
        .{ f / aspect, 0, 0, 0 },
        .{ 0, -f, 0, 0 },
        .{ 0, 0, far / depth, -1 },
        .{ 0, 0, (near * far) / depth, 0 },
    };
}
