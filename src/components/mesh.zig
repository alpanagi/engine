const std = @import("std");

pub const Mesh = struct {
    id: []const u8,
    material: []const u8,
    material_index: ?u32 = null,
    gpu_mesh_index: ?u32 = null,
    instance_index: ?u32 = null,

    pub fn init(alloc: std.mem.Allocator, id: []const u8, material: []const u8) !Mesh {
        const owned_id = try alloc.dupe(u8, id);
        errdefer alloc.free(owned_id);

        return Mesh{
            .id = owned_id,
            .material = try alloc.dupe(u8, material),
        };
    }

    pub fn deinit(self: *Mesh, alloc: std.mem.Allocator) void {
        alloc.free(self.id);
        alloc.free(self.material);
    }
};
