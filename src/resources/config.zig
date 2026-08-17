const sdl = @import("sdl");
const std = @import("std");
const util = @import("../util.zig");

const Color = @import("../color.zig").Color;

pub const Config = struct {
    window: WindowConfig = .{},
    render: RenderConfig = .{},

    pub fn default(allocator: std.mem.Allocator) Config {
        return .{
            .window = WindowConfig.default(allocator),
            .render = RenderConfig.default(allocator),
        };
    }

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        self.window.deinit(allocator);
        self.render.deinit(allocator);
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

pub const RenderConfig = struct {
    clear_color: []const u8 = "#000000",
    sample_count: u32 = 4,

    pub fn default(allocator: std.mem.Allocator) RenderConfig {
        const defaults: RenderConfig = .{};

        return .{
            .clear_color = allocator.dupe(u8, defaults.clear_color) catch util.panicOom("Config.default"),
        };
    }

    pub fn deinit(self: *RenderConfig, allocator: std.mem.Allocator) void {
        allocator.free(self.clear_color);
    }

    pub fn getClearColor(self: *const RenderConfig) !Color {
        return Color.fromHex(self.clear_color);
    }

    pub fn getSampleCount(self: *const RenderConfig) c_uint {
        return switch (self.sample_count) {
            1 => sdl.SDL_GPU_SAMPLECOUNT_1,
            2 => sdl.SDL_GPU_SAMPLECOUNT_2,
            4 => sdl.SDL_GPU_SAMPLECOUNT_4,
            8 => sdl.SDL_GPU_SAMPLECOUNT_8,
            else => util.panic("Invalid rendering sample count", .{}),
        };
    }
};
