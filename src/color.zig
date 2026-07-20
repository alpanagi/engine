const std = @import("std");

pub const ParseHexError = error{
    MissingPrefix,
    InvalidLength,
    InvalidCharacter,
};

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32 = 1.0,

    pub fn fromHex(hex: []const u8) ParseHexError!Color {
        if (hex.len == 0) return ParseHexError.InvalidLength;
        if (hex[0] != '#') return ParseHexError.MissingPrefix;
        const digits = hex[1..];

        return switch (digits.len) {
            6 => Color{
                .r = try parseComponent(digits[0..2]),
                .g = try parseComponent(digits[2..4]),
                .b = try parseComponent(digits[4..6]),
            },
            8 => Color{
                .r = try parseComponent(digits[0..2]),
                .g = try parseComponent(digits[2..4]),
                .b = try parseComponent(digits[4..6]),
                .a = try parseComponent(digits[6..8]),
            },
            else => ParseHexError.InvalidLength,
        };
    }
};

fn parseComponent(digits: []const u8) ParseHexError!f32 {
    const byte = std.fmt.parseUnsigned(u8, digits, 16) catch return ParseHexError.InvalidCharacter;
    const value: f32 = @floatFromInt(byte);
    return value / 255.0;
}

test "fromHex parses rgb" {
    const color = try Color.fromHex("#1a2b3c");
    try std.testing.expectApproxEqAbs(@as(f32, 0x1a) / 255.0, color.r, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0x2b) / 255.0, color.g, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0x3c) / 255.0, color.b, 0.0001);
    try std.testing.expectEqual(1.0, color.a);
}

test "fromHex parses rgba" {
    const color = try Color.fromHex("#1a2b3c4d");
    try std.testing.expectApproxEqAbs(@as(f32, 0x1a) / 255.0, color.r, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0x2b) / 255.0, color.g, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0x3c) / 255.0, color.b, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0x4d) / 255.0, color.a, 0.0001);
}

test "fromHex rejects missing hash" {
    try std.testing.expectError(ParseHexError.MissingPrefix, Color.fromHex("1a2b3c"));
}

test "fromHex rejects wrong length" {
    try std.testing.expectError(ParseHexError.InvalidLength, Color.fromHex("#1a2b3"));
}

test "fromHex rejects invalid characters" {
    try std.testing.expectError(ParseHexError.InvalidCharacter, Color.fromHex("#zzzzzz"));
}
