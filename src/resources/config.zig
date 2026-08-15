const std = @import("std");
const util = @import("../util.zig");

pub const Config = struct {
    window: WindowConfig = .{},

    pub fn default(allocator: std.mem.Allocator) Config {
        return .{ .window = WindowConfig.default(allocator) };
    }

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        self.window.deinit(allocator);
    }
};

pub const WindowConfig = struct {
    title: []const u8 = "Engine",
    clear_color: []const u8 = "#000000",
    icon: []const u8 = "icon.png",

    pub fn default(allocator: std.mem.Allocator) WindowConfig {
        const defaults: WindowConfig = .{};

        return .{
            .title = allocator.dupe(u8, defaults.title) catch util.panicOom("WindowConfig.default"),
            .clear_color = allocator.dupe(u8, defaults.clear_color) catch util.panicOom("WindowConfig.default"),
            .icon = allocator.dupe(u8, defaults.icon) catch util.panicOom("WindowConfig.default"),
        };
    }

    pub fn deinit(self: *WindowConfig, allocator: std.mem.Allocator) void {
        allocator.free(self.title);
        allocator.free(self.clear_color);
        allocator.free(self.icon);
    }
};
