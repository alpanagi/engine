const std = @import("std");
const util = @import("../util.zig");

pub const MeshInstance = struct {
    id: []const u8,
    instance_index: ?u32 = null,

    pub fn init(allocator: std.mem.Allocator, id: []const u8) MeshInstance {
        return MeshInstance{
            .id = allocator.dupe(u8, id) catch util.panicOom("MeshInstance.init"),
        };
    }

    pub fn deinit(self: *MeshInstance, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
    }
};
