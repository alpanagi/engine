const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.addModule("shaders", .{
        .root_source_file = b.path("shaders.zig"),
    });
}