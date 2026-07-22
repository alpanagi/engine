const std = @import("std");

pub const ProjectConfig = struct {
    window: WindowConfig = .{},

    pub fn default(alloc: std.mem.Allocator) !ProjectConfig {
        const window = try WindowConfig.default(alloc);
        return .{ .window = window };
    }

    pub fn deinit(self: *ProjectConfig, alloc: std.mem.Allocator) void {
        self.window.deinit(alloc);
    }
};

pub const WindowConfig = struct {
    title: []const u8 = "Engine",
    clear_color: []const u8 = "#000000",

    pub fn default(alloc: std.mem.Allocator) !WindowConfig {
        var window: WindowConfig = .{};

        window.title = try alloc.dupe(u8, window.title);
        errdefer alloc.free(window.title);

        window.clear_color = try alloc.dupe(u8, window.clear_color);
        errdefer alloc.free(window.clear_color);

        return window;
    }

    pub fn deinit(self: *WindowConfig, alloc: std.mem.Allocator) void {
        alloc.free(self.title);
        alloc.free(self.clear_color);
    }
};
