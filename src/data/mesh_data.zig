const std = @import("std");

pub const MeshData = struct {
    positions: [][3]f32,

    pub fn deinit(self: *MeshData, allocator: std.mem.Allocator) void {
        allocator.free(self.positions);
        self.positions = &.{};
    }

    pub fn vertexCount(self: *const MeshData) u32 {
        return @intCast(self.positions.len);
    }
};
