const std = @import("std");

const MeshData = @import("../mesh_data.zig").MeshData;

pub const ObjError = error{
    InvalidVertex,
    InvalidFace,
    VertexIndexOutOfRange,
};

const TokenIterator = std.mem.TokenIterator(u8, .any);

pub fn parse(alloc: std.mem.Allocator, reader: *std.Io.Reader) !MeshData {
    var positions: std.ArrayList(f32) = .empty;
    defer positions.deinit(alloc);

    var vertices: std.ArrayList(f32) = .empty;
    errdefer vertices.deinit(alloc);

    while (try reader.takeDelimiter('\n')) |line| {
        var tokens = std.mem.tokenizeAny(u8, line, " \t\r");
        const keyword = tokens.next() orelse continue;

        if (std.mem.eql(u8, keyword, "v")) {
            try parseVertex(alloc, &positions, &tokens);
        } else if (std.mem.eql(u8, keyword, "f")) {
            try parseFace(alloc, &vertices, positions.items, &tokens);
        }
    }

    return MeshData{ .positions = try vertices.toOwnedSlice(alloc) };
}

fn parseVertex(
    alloc: std.mem.Allocator,
    positions: *std.ArrayList(f32),
    tokens: *TokenIterator,
) !void {
    for (0..3) |_| {
        const token = tokens.next() orelse return ObjError.InvalidVertex;
        const value = std.fmt.parseFloat(f32, token) catch return ObjError.InvalidVertex;
        try positions.append(alloc, value);
    }
}

fn parseFace(
    alloc: std.mem.Allocator,
    vertices: *std.ArrayList(f32),
    positions: []const f32,
    tokens: *TokenIterator,
) !void {
    const first = try resolveIndex(positions, tokens.next() orelse return ObjError.InvalidFace);
    var previous = try resolveIndex(positions, tokens.next() orelse return ObjError.InvalidFace);

    var triangles: usize = 0;
    while (tokens.next()) |token| {
        const current = try resolveIndex(positions, token);

        try appendPosition(alloc, vertices, positions, first);
        try appendPosition(alloc, vertices, positions, previous);
        try appendPosition(alloc, vertices, positions, current);

        previous = current;
        triangles += 1;
    }

    if (triangles == 0) return ObjError.InvalidFace;
}

fn resolveIndex(positions: []const f32, token: []const u8) !usize {
    const field = std.mem.sliceTo(token, '/');
    const value = std.fmt.parseInt(usize, field, 10) catch return ObjError.InvalidFace;
    if (value == 0) return ObjError.InvalidFace;

    const index = value - 1;
    if (index >= positions.len / 3) return ObjError.VertexIndexOutOfRange;

    return index;
}

fn appendPosition(
    alloc: std.mem.Allocator,
    vertices: *std.ArrayList(f32),
    positions: []const f32,
    index: usize,
) !void {
    try vertices.appendSlice(alloc, positions[index * 3 ..][0..3]);
}