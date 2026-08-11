pub const Quat = [4]f32;

pub const identity: Quat = .{ 0, 0, 0, 1 };

pub fn conjugate(q: Quat) Quat {
    return .{ -q[0], -q[1], -q[2], q[3] };
}

pub fn fromAxisAngle(axis: [3]f32, angle: f32) Quat {
    const length = @sqrt(axis[0] * axis[0] + axis[1] * axis[1] + axis[2] * axis[2]);
    if (length == 0) return identity;

    const half = angle * 0.5;
    const scale = @sin(half) / length;

    return .{
        axis[0] * scale,
        axis[1] * scale,
        axis[2] * scale,
        @cos(half),
    };
}

pub fn mul(a: Quat, b: Quat) Quat {
    return .{
        a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1],
        a[3] * b[1] - a[0] * b[2] + a[1] * b[3] + a[2] * b[0],
        a[3] * b[2] + a[0] * b[1] - a[1] * b[0] + a[2] * b[3],
        a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2],
    };
}

pub fn normalize(q: Quat) Quat {
    const length = @sqrt(q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3]);
    if (length == 0) return identity;

    return .{ q[0] / length, q[1] / length, q[2] / length, q[3] / length };
}
