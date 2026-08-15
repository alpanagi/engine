const std = @import("std");
const util = @import("../util.zig");

pub const PendingMaterial = struct {
    id: []const u8,
    shader_data: []const u8,

    fn init(allocator: std.mem.Allocator, id: []const u8, shader_data: []const u8) PendingMaterial {
        return .{
            .id = allocator.dupe(u8, id) catch util.panicOom("PendingMaterial.init"),
            .shader_data = shader_data,
        };
    }

    pub fn deinit(self: *PendingMaterial, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.shader_data);
    }
};

pub const Materials = struct {
    pending: std.ArrayList(PendingMaterial) = .empty,

    pub fn deinit(self: *Materials, allocator: std.mem.Allocator) void {
        for (self.pending.items) |*material| material.deinit(allocator);
        self.pending.deinit(allocator);
    }

    pub fn addOwned(
        self: *Materials,
        allocator: std.mem.Allocator,
        id: []const u8,
        shader_data: []const u8,
    ) void {
        self.pending.append(allocator, PendingMaterial.init(allocator, id, shader_data)) catch
            util.panicOom("Materials.addOwned");
    }
};
