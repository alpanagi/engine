const ecs = @import("ecs");
const sdl = @import("sdl");
const std = @import("std");

const util = @import("../util.zig");

const AssetLoader = @import("../resources/asset_loader.zig").AssetLoader;
const Color = @import("../color.zig").Color;
const Config = @import("../resources/config.zig").Config;
const OnConfigLoaded = @import("config.zig").OnConfigLoaded;
const OnShutdown = @import("../engine.zig").OnShutdown;

pub const OnWindowCreate = struct { sdl_window: *sdl.SDL_Window };
pub const OnWindowDestroy = struct {};
pub const OnWindowUpdate = struct { sdl_window: *sdl.SDL_Window, clear_color: Color };

pub const WindowPlugin = struct {
    sdl_window: ?*sdl.SDL_Window = null,
    title: ?[:0]u8 = null,
    icon: ?*sdl.SDL_Surface = null,
    clear_color: Color = Color.fromHex("#000000") catch unreachable,

    pub fn deinit(self: *WindowPlugin, allocator: std.mem.Allocator) void {
        if (self.title) |title| allocator.free(title);
        if (self.icon) |icon| sdl.SDL_DestroySurface(icon);
    }

    pub fn build(
        self: *WindowPlugin,
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
    ) !void {
        try world.addOneShotSystem(allocator.*, setup, self);
        try world.addObserver(allocator.*, onConfigLoaded, self);
        try world.addSystem(allocator.*, "update", readSDLWindowEvents, self);
        try world.addSystem(allocator.*, "update", update, self);
    }

    pub fn onConfigLoaded(
        self: *WindowPlugin,
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
        _: *const OnConfigLoaded,
    ) void {
        const config = world.getResource(Config) orelse return;

        self.clear_color = Color.fromHex(config.window.clear_color) catch self.clear_color;

        const title = allocator.dupeZ(u8, config.window.title) catch return;
        if (self.title) |old| allocator.free(old);
        self.title = title;

        if (world.getResource(AssetLoader)) |asset_loader| {
            if (asset_loader.loadImage(allocator.*, config.window.icon) catch null) |icon| {
                if (self.icon) |old| sdl.SDL_DestroySurface(old);
                self.icon = icon;
            }
        }

        if (self.sdl_window) |sdl_window| {
            _ = sdl.SDL_SetWindowTitle(sdl_window, title.ptr);

            if (self.icon) |icon| {
                _ = sdl.SDL_SetWindowIcon(sdl_window, icon);
                sdl.SDL_DestroySurface(icon);
                self.icon = null;
            }
        }
    }

    pub fn setup(self: *WindowPlugin, allocator: *const std.mem.Allocator, world: *ecs.World) void {
        const sdl_window: *sdl.SDL_Window = sdl.SDL_CreateWindow(
            if (self.title) |title| title.ptr else "Engine".ptr,
            1280,
            720,
            sdl.SDL_WINDOW_RESIZABLE,
        ) orelse util.sdlPanic();

        self.sdl_window = sdl_window;

        if (self.icon) |icon| {
            _ = sdl.SDL_SetWindowIcon(sdl_window, icon);
            sdl.SDL_DestroySurface(icon);
            self.icon = null;
        }

        world.trigger(allocator.*, OnWindowCreate{ .sdl_window = self.sdl_window.? });
    }

    pub fn readSDLWindowEvents(
        self: *WindowPlugin,
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
    ) void {
        if (self.sdl_window == null) return;

        while (readSDLEvent()) |event| {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT,
                sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED,
                => {
                    world.trigger(allocator.*, OnWindowDestroy{});
                    if (self.sdl_window) |window| sdl.SDL_DestroyWindow(window);
                    self.sdl_window = null;

                    world.trigger(allocator.*, OnShutdown{});
                },
                else => {},
            }
        }
    }

    pub fn update(
        self: *WindowPlugin,
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
    ) void {
        if (self.sdl_window == null) return;

        world.trigger(allocator.*, OnWindowUpdate{
            .sdl_window = self.sdl_window.?,
            .clear_color = self.clear_color,
        });
    }
};

fn readSDLEvent() ?sdl.SDL_Event {
    var event: sdl.SDL_Event = undefined;
    if (sdl.SDL_PollEvent(&event)) {
        return event;
    }

    return null;
}
