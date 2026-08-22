const std = @import("std");
const util = @import("../util.zig");

const Vertex = @import("../data/vertex.zig").Vertex;
const World = @import("ecs").World;

pub const PendingMesh = struct {
    id: []const u8,
    material: []const u8,
    vertices: []Vertex,

    fn init(
        allocator: std.mem.Allocator,
        id: []const u8,
        material: []const u8,
        vertices: []Vertex,
    ) PendingMesh {
        return .{
            .id = allocator.dupe(u8, id) catch util.panicOom("PendingMesh.init"),
            .material = allocator.dupe(u8, material) catch util.panicOom("PendingMesh.init"),
            .vertices = vertices,
        };
    }

    pub fn deinit(self: *PendingMesh, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.material);
        allocator.free(self.vertices);
    }
};

pub const Meshes = struct {
    pub const State = MeshesState;

    state: *State,

    pub fn fromWorld(_: std.mem.Allocator, world: *World) Meshes {
        return .{
            .state = world.resources.get(State) orelse
                util.panic("system requires Meshes but the graphics plugin is not registered", .{}),
        };
    }

    pub fn addOwned(
        self: Meshes,
        allocator: std.mem.Allocator,
        id: []const u8,
        material: []const u8,
        vertices: []Vertex,
    ) void {
        self.state.pending.append(
            allocator,
            PendingMesh.init(allocator, id, material, vertices),
        ) catch util.panicOom("Meshes.addOwned");
    }
};

const MeshesState = struct {
    pending: std.ArrayList(PendingMesh) = .empty,

    pub fn deinit(self: *MeshesState, allocator: std.mem.Allocator) void {
        for (self.pending.items) |*mesh| mesh.deinit(allocator);
        self.pending.deinit(allocator);
    }
};
