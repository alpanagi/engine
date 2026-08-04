const ecs = @import("ecs");
const sdl = @import("sdl");
const std = @import("std");

const util = @import("../util.zig");

const AssetLoader = @import("../resources/asset_loader.zig").AssetLoader;
const Color = @import("../color.zig").Color;
const Config = @import("../resources/config.zig").Config;
const OnConfigLoaded = @import("config_plugin.zig").OnConfigLoaded;
const OnShutdown = @import("../engine.zig").OnShutdown;

pub const OnWindowDestroy = struct {};

pub const Window = struct {
    sdl_window: *sdl.SDL_Window,

    title: [:0]u8,
    clear_color: Color,
    icon: ?*sdl.SDL_Surface = null,

    width: u32,
    height: u32,

    pub fn init(
        allocator: std.mem.Allocator,
        title: []const u8,
        clear_color: Color,
        icon: ?*sdl.SDL_Surface,
        width: u32,
        height: u32,
    ) !Window {
        const window_title = try allocator.dupeZ(u8, title);

        const sdl_window: *sdl.SDL_Window = sdl.SDL_CreateWindow(
            window_title.ptr,
            @intCast(width),
            @intCast(height),
            sdl.SDL_WINDOW_RESIZABLE,
        ) orelse util.sdlPanic();

        if (icon) |surface| _ = sdl.SDL_SetWindowIcon(sdl_window, surface);

        return Window{
            .sdl_window = sdl_window,
            .title = window_title,
            .clear_color = clear_color,
            .icon = icon,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *Window, allocator: std.mem.Allocator) void {
        if (self.icon) |icon| sdl.SDL_DestroySurface(icon);
        sdl.SDL_DestroyWindow(self.sdl_window);
        allocator.free(self.title);
    }
};

pub const WindowPlugin = struct {
    title: ?[:0]u8 = null,
    icon: ?*sdl.SDL_Surface = null,

    pub fn deinit(self: *WindowPlugin, allocator: std.mem.Allocator) void {
        if (self.title) |title| allocator.free(title);
        if (self.icon) |icon| sdl.SDL_DestroySurface(icon);
    }

    pub fn build(
        self: *WindowPlugin,
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
    ) !void {
        try world.addObserver(allocator.*, onConfigLoaded, self);
        try world.addSystem(allocator.*, "update", readSDLWindowEvents, self);
    }

    pub fn onConfigLoaded(
        _: *WindowPlugin,
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
        _: *const OnConfigLoaded,
    ) void {
        const config = world.getResource(Config) orelse return;

        const clear_color = Color.fromHex(config.window.clear_color) catch Color{ .r = 0, .g = 0, .b = 0 };

        const icon = if (world.getResource(AssetLoader)) |asset_loader|
            asset_loader.loadImage(allocator.*, config.window.icon) catch null
        else
            null;

        var window = Window.init(
            allocator.*,
            config.window.title,
            clear_color,
            icon,
            1280,
            720,
        ) catch return;

        world.spawn(allocator.*, .{window}) catch {
            window.deinit(allocator.*);
            return;
        };
    }

    pub fn readSDLWindowEvents(
        _: *WindowPlugin,
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
    ) void {
        var query = world.query(&.{Window});
        if (query.next(world) == null) return;

        while (readSDLEvent()) |event| {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT,
                sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED,
                => {
                    world.trigger(allocator.*, OnWindowDestroy{});
                    world.trigger(allocator.*, OnShutdown{});
                    return;
                },
                else => {},
            }
        }
    }

};

fn readSDLEvent() ?sdl.SDL_Event {
    var event: sdl.SDL_Event = undefined;
    if (sdl.SDL_PollEvent(&event)) {
        return event;
    }

    return null;
}
