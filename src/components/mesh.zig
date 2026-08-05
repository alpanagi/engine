const std = @import("std");

pub const Mesh = struct {
    material: []const u8,
    material_index: ?u32 = null,
    gpu_mesh_index: ?u32 = null,
    instance_index: ?u32 = null,

    pub fn init(alloc: std.mem.Allocator, material: []const u8) !Mesh {
        return Mesh{
            .material = try alloc.dupe(u8, material),
        };
    }

    pub fn deinit(self: *Mesh, alloc: std.mem.Allocator) void {
        alloc.free(self.material);
    }
};
