const engine = @import("engine");
const std = @import("std");

fn freeEntries(allocator: std.mem.Allocator, entries: []engine.gltf.Entry) void {
    for (entries) |*entry| entry.deinit(allocator);
    allocator.free(entries);
}

test "the gltf converter names every entry after the mesh its primitive belongs to" {
    const allocator = std.testing.allocator;

    var positions = [_][3]f32{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 0, 1, 0 } };
    var texcoord_0 = [_][2]f32{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 } };
    var texcoords = [_][]const [2]f32{&texcoord_0};

    var primitives = [_]engine.gltf.Primitive{
        .{ .positions = &positions, .texcoords = &texcoords, .material = 0 },
        .{ .positions = &positions, .texcoords = &texcoords, .material = 1 },
    };
    var meshes = [_]engine.gltf.Mesh{.{ .name = "Floor", .primitives = &primitives }};
    var materials = [_]engine.gltf.Material{ .{}, .{} };

    const entries = try engine.gltf.meshDataFrom(
        allocator,
        .{ .meshes = &meshes, .materials = &materials },
        "engine.diffuse",
    );
    defer freeEntries(allocator, entries);

    try std.testing.expectEqual(2, entries.len);
    try std.testing.expectEqualStrings("Floor", entries[0].name);
    try std.testing.expectEqualStrings("Floor", entries[1].name);
    try std.testing.expectEqual(3, entries[0].vertices.len);
    try std.testing.expectEqualSlices(engine.data.Vertex, &.{
        .{ .position = .{ 0, 0, 0 }, .uv = .{ 0, 0 } },
        .{ .position = .{ 1, 0, 0 }, .uv = .{ 1, 0 } },
        .{ .position = .{ 0, 1, 0 }, .uv = .{ 0, 1 } },
    }, entries[0].vertices);
}

test "the gltf converter keeps the uv set the base color texture reads" {
    const allocator = std.testing.allocator;

    var positions = [_][3]f32{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 0, 1, 0 } };
    var texcoord_0 = [_][2]f32{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 } };
    var texcoord_1 = [_][2]f32{ .{ 0.25, 0.25 }, .{ 0.5, 0.25 }, .{ 0.25, 0.5 } };
    var texcoords = [_][]const [2]f32{ &texcoord_0, &texcoord_1 };

    var primitives = [_]engine.gltf.Primitive{.{
        .positions = &positions,
        .texcoords = &texcoords,
        .material = 0,
    }};
    var meshes = [_]engine.gltf.Mesh{.{ .name = "Floor", .primitives = &primitives }};
    var materials = [_]engine.gltf.Material{.{ .base_color = 0, .base_color_uv = 1 }};

    const entries = try engine.gltf.meshDataFrom(
        allocator,
        .{ .meshes = &meshes, .materials = &materials },
        "engine.diffuse",
    );
    defer freeEntries(allocator, entries);

    try std.testing.expectEqualSlices(engine.data.Vertex, &.{
        .{ .position = .{ 0, 0, 0 }, .uv = .{ 0.25, 0.25 } },
        .{ .position = .{ 1, 0, 0 }, .uv = .{ 0.5, 0.25 } },
        .{ .position = .{ 0, 1, 0 }, .uv = .{ 0.25, 0.5 } },
    }, entries[0].vertices);
}

test "the gltf converter keeps the first uv set for an untextured material" {
    const allocator = std.testing.allocator;

    var positions = [_][3]f32{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 0, 1, 0 } };
    var texcoord_0 = [_][2]f32{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 } };
    var texcoords = [_][]const [2]f32{&texcoord_0};

    var primitives = [_]engine.gltf.Primitive{.{
        .positions = &positions,
        .texcoords = &texcoords,
        .material = 0,
    }};
    var meshes = [_]engine.gltf.Mesh{.{ .name = "Floor", .primitives = &primitives }};
    var materials = [_]engine.gltf.Material{.{}};

    const entries = try engine.gltf.meshDataFrom(
        allocator,
        .{ .meshes = &meshes, .materials = &materials },
        "engine.diffuse",
    );
    defer freeEntries(allocator, entries);

    try std.testing.expectEqualSlices(engine.data.Vertex, &.{
        .{ .position = .{ 0, 0, 0 }, .uv = .{ 0, 0 } },
        .{ .position = .{ 1, 0, 0 }, .uv = .{ 1, 0 } },
        .{ .position = .{ 0, 1, 0 }, .uv = .{ 0, 1 } },
    }, entries[0].vertices);
}

test "the gltf converter rejects a primitive without texcoords" {
    const allocator = std.testing.allocator;

    var positions = [_][3]f32{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 0, 1, 0 } };
    var texcoord_0 = [_][2]f32{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 } };
    var texcoords = [_][]const [2]f32{&texcoord_0};

    var primitives = [_]engine.gltf.Primitive{
        .{ .positions = &positions, .texcoords = &texcoords, .material = 0 },
        .{ .positions = &positions, .material = 1 },
    };
    var meshes = [_]engine.gltf.Mesh{.{ .name = "Floor", .primitives = &primitives }};
    var materials = [_]engine.gltf.Material{ .{}, .{} };

    try std.testing.expectError(error.MissingUvs, engine.gltf.meshDataFrom(
        allocator,
        .{ .meshes = &meshes, .materials = &materials },
        "engine.diffuse",
    ));
}

test "the gltf converter rejects a base color that reads an absent uv set" {
    const allocator = std.testing.allocator;

    var positions = [_][3]f32{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 0, 1, 0 } };
    var texcoord_0 = [_][2]f32{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 } };
    var texcoords = [_][]const [2]f32{&texcoord_0};

    var primitives = [_]engine.gltf.Primitive{.{
        .positions = &positions,
        .texcoords = &texcoords,
        .material = 0,
    }};
    var meshes = [_]engine.gltf.Mesh{.{ .name = "Floor", .primitives = &primitives }};
    var materials = [_]engine.gltf.Material{.{ .base_color = 0, .base_color_uv = 1 }};

    try std.testing.expectError(error.InvalidUvSet, engine.gltf.meshDataFrom(
        allocator,
        .{ .meshes = &meshes, .materials = &materials },
        "engine.diffuse",
    ));
}

test "the gltf converter rejects a primitive with fewer uvs than positions" {
    const allocator = std.testing.allocator;

    var positions = [_][3]f32{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 0, 1, 0 } };
    var texcoord_0 = [_][2]f32{ .{ 0, 0 }, .{ 1, 0 } };
    var texcoords = [_][]const [2]f32{&texcoord_0};

    var primitives = [_]engine.gltf.Primitive{.{
        .positions = &positions,
        .texcoords = &texcoords,
    }};
    var meshes = [_]engine.gltf.Mesh{.{ .name = "Floor", .primitives = &primitives }};

    try std.testing.expectError(error.MismatchedUvs, engine.gltf.meshDataFrom(
        allocator,
        .{ .meshes = &meshes },
        "engine.diffuse",
    ));
}

test "the gltf converter rejects two meshes sharing a name" {
    const allocator = std.testing.allocator;

    var positions = [_][3]f32{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 0, 1, 0 } };
    var texcoord_0 = [_][2]f32{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 } };
    var texcoords = [_][]const [2]f32{&texcoord_0};

    var primitives = [_]engine.gltf.Primitive{.{
        .positions = &positions,
        .texcoords = &texcoords,
    }};
    var meshes = [_]engine.gltf.Mesh{
        .{ .name = "Floor", .primitives = &primitives },
        .{ .name = "Floor", .primitives = &primitives },
    };

    try std.testing.expectError(error.DuplicateMesh, engine.gltf.meshDataFrom(
        allocator,
        .{ .meshes = &meshes },
        "engine.diffuse",
    ));
}

test "the gltf converter rejects two primitives of a mesh sharing a material" {
    const allocator = std.testing.allocator;

    var positions = [_][3]f32{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 0, 1, 0 } };
    var texcoord_0 = [_][2]f32{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 } };
    var texcoords = [_][]const [2]f32{&texcoord_0};

    var primitives = [_]engine.gltf.Primitive{
        .{ .positions = &positions, .texcoords = &texcoords, .material = 0 },
        .{ .positions = &positions, .texcoords = &texcoords, .material = 0 },
    };
    var meshes = [_]engine.gltf.Mesh{.{ .name = "Floor", .primitives = &primitives }};
    var materials = [_]engine.gltf.Material{.{}};

    try std.testing.expectError(error.DuplicateMeshMaterial, engine.gltf.meshDataFrom(
        allocator,
        .{ .meshes = &meshes, .materials = &materials },
        "engine.diffuse",
    ));
}

test "the gltf converter rejects two primitives of a mesh without materials" {
    const allocator = std.testing.allocator;

    var positions = [_][3]f32{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 0, 1, 0 } };
    var texcoord_0 = [_][2]f32{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 } };
    var texcoords = [_][]const [2]f32{&texcoord_0};

    var primitives = [_]engine.gltf.Primitive{
        .{ .positions = &positions, .texcoords = &texcoords },
        .{ .positions = &positions, .texcoords = &texcoords },
    };
    var meshes = [_]engine.gltf.Mesh{.{ .name = "Floor", .primitives = &primitives }};

    try std.testing.expectError(error.DuplicateMeshMaterial, engine.gltf.meshDataFrom(
        allocator,
        .{ .meshes = &meshes },
        "engine.diffuse",
    ));
}

test "the gltf converter rejects a mesh without a name" {
    const allocator = std.testing.allocator;

    var positions = [_][3]f32{ .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ 0, 1, 0 } };
    var texcoord_0 = [_][2]f32{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 } };
    var texcoords = [_][]const [2]f32{&texcoord_0};

    var primitives = [_]engine.gltf.Primitive{.{
        .positions = &positions,
        .texcoords = &texcoords,
    }};
    var meshes = [_]engine.gltf.Mesh{.{ .name = "", .primitives = &primitives }};

    try std.testing.expectError(error.UnnamedMesh, engine.gltf.meshDataFrom(
        allocator,
        .{ .meshes = &meshes },
        "engine.diffuse",
    ));
}
