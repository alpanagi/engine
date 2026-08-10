const sdl = @import("sdl");
const std = @import("std");

const util = @import("../../util.zig");

const Material = @import("material.zig").Material;

pub const MeshLocation = struct {
    material: u32,
    gpu_mesh: u32,
};

pub const Materials = struct {
    materials: std.ArrayList(Material) = .empty,
    index_by_id: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    mesh_location_by_id: std.AutoHashMapUnmanaged(u64, MeshLocation) = .empty,

    pub fn deinit(self: *Materials, alloc: std.mem.Allocator) void {
        self.mesh_location_by_id.deinit(alloc);
        self.index_by_id.deinit(alloc);

        for (self.materials.items) |*material| material.deinit(alloc);
        self.materials.deinit(alloc);
    }

    pub fn sdlDeinit(self: *Materials, alloc: std.mem.Allocator, device: *sdl.SDL_GPUDevice) void {
        for (self.materials.items) |*material| {
            material.sdlDeinit(device);
            material.deinit(alloc);
        }

        self.mesh_location_by_id.clearRetainingCapacity();
        self.index_by_id.clearRetainingCapacity();
        self.materials.clearRetainingCapacity();
    }

    pub fn add(
        self: *Materials,
        alloc: std.mem.Allocator,
        id: []const u8,
        material: Material,
    ) !void {
        const index: u32 = @intCast(self.materials.items.len);
        const key = util.hashBytes(id);

        try self.index_by_id.put(alloc, key, index);
        errdefer _ = self.index_by_id.remove(key);

        try self.materials.append(alloc, material);
    }

    pub fn find(self: *const Materials, id: []const u8) ?u32 {
        return self.index_by_id.get(util.hashBytes(id));
    }
};