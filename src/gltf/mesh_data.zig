const gltf = @import("gltf");
const std = @import("std");
const util = @import("../util.zig");

const Vertex = @import("../data/vertex.zig").Vertex;

pub const MeshDataError = error{
    MissingUvs,
    MismatchedUvs,
    InvalidUvSet,
    UnnamedMesh,
    DuplicateMesh,
    DuplicateMeshMaterial,
};

pub const Entry = struct {
    name: []const u8,
    vertices: []Vertex,

    pub fn deinit(self: *Entry, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.vertices);
        self.name = &.{};
        self.vertices = &.{};
    }
};

pub fn meshDataFrom(
    allocator: std.mem.Allocator,
    source: gltf.Gltf,
    _: []const u8,
) ![]Entry {
    try validateUniqueMeshes(source);

    var entries: std.ArrayList(Entry) = .empty;
    errdefer {
        for (entries.items) |*entry| entry.deinit(allocator);
        entries.deinit(allocator);
    }

    for (source.meshes) |mesh| {
        for (mesh.primitives) |primitive| {
            const vertices = try verticesFromPrimitive(allocator, source, primitive);

            entries.append(allocator, .{
                .name = allocator.dupe(u8, mesh.name) catch
                    util.panicOom("gltf.meshDataFrom"),
                .vertices = vertices,
            }) catch util.panicOom("gltf.meshDataFrom");
        }
    }

    return entries.toOwnedSlice(allocator) catch util.panicOom("gltf.meshDataFrom");
}

fn validateUniqueMeshes(source: gltf.Gltf) !void {
    for (source.meshes, 0..) |mesh, index| {
        if (mesh.name.len == 0) return MeshDataError.UnnamedMesh;

        for (source.meshes[0..index]) |earlier| {
            if (std.mem.eql(u8, earlier.name, mesh.name)) return MeshDataError.DuplicateMesh;
        }

        for (mesh.primitives, 0..) |primitive, primitive_index| {
            for (mesh.primitives[0..primitive_index]) |earlier| {
                if (std.meta.eql(earlier.material, primitive.material))
                    return MeshDataError.DuplicateMeshMaterial;
            }
        }
    }
}

fn verticesFromPrimitive(
    allocator: std.mem.Allocator,
    source: gltf.Gltf,
    primitive: gltf.Primitive,
) ![]Vertex {
    if (primitive.texcoords.len == 0) return MeshDataError.MissingUvs;

    const uv_set = baseColorUvSet(source, primitive);
    if (uv_set >= primitive.texcoords.len) return MeshDataError.InvalidUvSet;

    const texcoords = primitive.texcoords[uv_set];
    if (texcoords.len != primitive.positions.len) return MeshDataError.MismatchedUvs;

    const vertices = allocator.alloc(Vertex, primitive.positions.len) catch
        util.panicOom("gltf.verticesFromPrimitive");

    for (vertices, primitive.positions, texcoords) |*vertex, position, uv| {
        vertex.* = .{ .position = position, .uv = uv };
    }

    return vertices;
}

fn baseColorUvSet(source: gltf.Gltf, primitive: gltf.Primitive) u32 {
    const material_index = primitive.material orelse return 0;

    return source.materials[material_index].base_color_uv;
}
