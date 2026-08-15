const Quat = @import("quat.zig").Quat;
const Vec4 = @import("vec4.zig").Vec4;

pub const Mat4 = [4]Vec4;

pub const identity: Mat4 = .{
    .{ 1, 0, 0, 0 },
    .{ 0, 1, 0, 0 },
    .{ 0, 0, 1, 0 },
    .{ 0, 0, 0, 1 },
};

pub fn fromTransform(position: Vec4, rotation: Quat, scale: Vec4) Mat4 {
    var result = fromRotation(rotation);

    for (0..3) |c| {
        for (0..3) |r| result[c][r] *= scale[c];
    }

    result[3] = .{ position[0], position[1], position[2], 1 };

    return result;
}

pub fn fromRotation(rotation: Quat) Mat4 {
    const x = rotation[0];
    const y = rotation[1];
    const z = rotation[2];
    const w = rotation[3];

    return .{
        .{ 1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w), 0 },
        .{ 2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w), 0 },
        .{ 2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y), 0 },
        .{ 0, 0, 0, 1 },
    };
}

pub fn mul(a: Mat4, b: Mat4) Mat4 {
    var result: Mat4 = undefined;

    for (0..4) |c| {
        for (0..4) |r| {
            result[c][r] =
                a[0][r] * b[c][0] +
                a[1][r] * b[c][1] +
                a[2][r] * b[c][2] +
                a[3][r] * b[c][3];
        }
    }

    return result;
}
