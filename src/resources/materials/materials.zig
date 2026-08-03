const std = @import("std");

const Material = @import("material.zig").Material;

pub const Materials = struct {
    materials: std.ArrayList(Material) = .empty,

    pub fn deinit(self: *Materials, alloc: std.mem.Allocator) void {
        self.materials.deinit(alloc);
    }

    pub fn add(self: *Materials, alloc: std.mem.Allocator, material: Material) !void {
        try self.materials.append(alloc, material);
    }
};