const std = @import("std");
const util = @import("../../../util.zig");

const MeshData = @import("../../../data/mesh_data.zig").MeshData;

pub const ObjError = error{
    InvalidVertex,
    InvalidFace,
    VertexIndexOutOfRange,
};

const TokenIterator = std.mem.TokenIterator(u8, .any);

pub fn parse(allocator: std.mem.Allocator, reader: *std.Io.Reader) !MeshData {
    var positions: std.ArrayList([3]f32) = .empty;
    defer positions.deinit(allocator);

    var vertices: std.ArrayList([3]f32) = .empty;
    errdefer vertices.deinit(allocator);

    while (try reader.takeDelimiter('\n')) |line| {
        var tokens = std.mem.tokenizeAny(u8, line, " \t\r");
        const keyword = tokens.next() orelse continue;

        if (std.mem.eql(u8, keyword, "v")) {
            try parseVertex(allocator, &positions, &tokens);
        } else if (std.mem.eql(u8, keyword, "f")) {
            try parseFace(allocator, &vertices, positions.items, &tokens);
        }
    }

    return MeshData{
        .positions = vertices.toOwnedSlice(allocator) catch util.panicOom("obj.parse"),
    };
}

fn parseVertex(
    allocator: std.mem.Allocator,
    positions: *std.ArrayList([3]f32),
    tokens: *TokenIterator,
) !void {
    var position: [3]f32 = undefined;
    for (&position) |*component| {
        const token = tokens.next() orelse return ObjError.InvalidVertex;
        component.* = std.fmt.parseFloat(f32, token) catch return ObjError.InvalidVertex;
    }

    positions.append(allocator, position) catch util.panicOom("obj.parseVertex");
}

fn parseFace(
    allocator: std.mem.Allocator,
    vertices: *std.ArrayList([3]f32),
    positions: []const [3]f32,
    tokens: *TokenIterator,
) !void {
    for (0..3) |_| {
        const token = tokens.next() orelse return ObjError.InvalidFace;

        var vertex_index = std.fmt.parseInt(usize, std.mem.sliceTo(token, '/'), 10) catch
            return ObjError.InvalidFace;
        if (vertex_index == 0) return ObjError.InvalidFace;
        if (vertex_index > positions.len) return ObjError.VertexIndexOutOfRange;

        vertex_index -= 1;
        vertices.append(allocator, positions[vertex_index]) catch util.panicOom("obj.parseFace");
    }

    if (tokens.next() != null) return ObjError.InvalidFace;
}
