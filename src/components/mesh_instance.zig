const std = @import("std");

pub const MeshInstance = struct {
    id: []const u8,
    instance_index: ?u32 = null,

    pub fn init(alloc: std.mem.Allocator, id: []const u8) !MeshInstance {
        return MeshInstance{
            .id = try alloc.dupe(u8, id),
        };
    }

    pub fn deinit(self: *MeshInstance, alloc: std.mem.Allocator) void {
        alloc.free(self.id);
    }
};