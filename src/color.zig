const std = @import("std");

pub const ParseHexError = error{
    MissingPrefix,
    InvalidLength,
    InvalidCharacter,
};

pub const Color = struct {
    pub const black: Color = Color{ .r = 0, .g = 0, .b = 0 };

    r: f32,
    g: f32,
    b: f32,
    a: f32 = 1.0,

    pub fn fromHex(hex: []const u8) !Color {
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

fn parseComponent(digits: []const u8) !f32 {
    const byte = std.fmt.parseUnsigned(u8, digits, 16) catch return ParseHexError.InvalidCharacter;
    const value: f32 = @floatFromInt(byte);
    return value / 255.0;
}

test "fromHex: parses a six digit rgb value" {
    const color = try Color.fromHex("#1a2b3c");
    try std.testing.expectApproxEqAbs(@as(f32, 0x1a) / 255.0, color.r, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0x2b) / 255.0, color.g, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0x3c) / 255.0, color.b, 0.0001);
}

test "fromHex: defaults alpha to one when omitted" {
    const color = try Color.fromHex("#1a2b3c");
    try std.testing.expectEqual(1.0, color.a);
}

test "fromHex: parses an eight digit rgba value" {
    const color = try Color.fromHex("#1a2b3c4d");
    try std.testing.expectApproxEqAbs(@as(f32, 0x1a) / 255.0, color.r, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0x2b) / 255.0, color.g, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0x3c) / 255.0, color.b, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0x4d) / 255.0, color.a, 0.0001);
}

test "fromHex: ignores digit case" {
    try std.testing.expectEqual(
        try Color.fromHex("#1a2b3c4d"),
        try Color.fromHex("#1A2B3C4D"),
    );
}

test "fromHex: maps the lowest digit value to zero" {
    const color = try Color.fromHex("#000000");
    try std.testing.expectEqual(0.0, color.r);
    try std.testing.expectEqual(0.0, color.g);
    try std.testing.expectEqual(0.0, color.b);
}

test "fromHex: maps the highest digit value to one" {
    const color = try Color.fromHex("#ffffff");
    try std.testing.expectEqual(1.0, color.r);
    try std.testing.expectEqual(1.0, color.g);
    try std.testing.expectEqual(1.0, color.b);
}

test "fromHex: rejects a value without a leading hash" {
    try std.testing.expectError(ParseHexError.MissingPrefix, Color.fromHex("1a2b3c"));
}

test "fromHex: rejects an empty value" {
    try std.testing.expectError(ParseHexError.InvalidLength, Color.fromHex(""));
}

test "fromHex: rejects a value with no digits" {
    try std.testing.expectError(ParseHexError.InvalidLength, Color.fromHex("#"));
}

test "fromHex: rejects a value of the wrong length" {
    try std.testing.expectError(ParseHexError.InvalidLength, Color.fromHex("#1a2b3"));
}

test "fromHex: rejects non hexadecimal characters" {
    try std.testing.expectError(ParseHexError.InvalidCharacter, Color.fromHex("#zzzzzz"));
}
