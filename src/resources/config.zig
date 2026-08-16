const std = @import("std");
const util = @import("../util.zig");

pub const Config = struct {
    clear_color: []const u8 = "#000000",

    window: WindowConfig = .{},

    pub fn default(allocator: std.mem.Allocator) Config {
        const defaults: Config = .{};

        return .{
            .clear_color = allocator.dupe(u8, defaults.clear_color) catch util.panicOom("Config.default"),
            .window = WindowConfig.default(allocator),
        };
    }

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        allocator.free(self.clear_color);
        self.window.deinit(allocator);
    }
};

pub const WindowConfig = struct {
    title: []const u8 = "Engine",
    icon: []const u8 = "icon.png",

    pub fn default(allocator: std.mem.Allocator) WindowConfig {
        const defaults: WindowConfig = .{};

        return .{
            .title = allocator.dupe(u8, defaults.title) catch util.panicOom("WindowConfig.default"),
            .icon = allocator.dupe(u8, defaults.icon) catch util.panicOom("WindowConfig.default"),
        };
    }

    pub fn deinit(self: *WindowConfig, allocator: std.mem.Allocator) void {
        allocator.free(self.title);
        allocator.free(self.icon);
    }
};
