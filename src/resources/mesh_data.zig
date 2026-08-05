const std = @import("std");

pub const MeshData = struct {
    positions: []f32,

    pub fn deinit(self: *MeshData, alloc: std.mem.Allocator) void {
        alloc.free(self.positions);
        self.positions = &.{};
    }

    pub fn vertexCount(self: *const MeshData) u32 {
        return @intCast(self.positions.len / 3);
    }
};