const ecs = @import("ecs");
const sdl = @import("sdl");
const std = @import("std");

const util = @import("../util.zig");

const AssetLoader = @import("../resources/asset_loader/asset_loader.zig").AssetLoader;
const Color = @import("../color.zig").Color;
const Config = @import("../resources/config.zig").Config;
const ShuttingDown = @import("../engine.zig").events.ShuttingDown;

pub const WindowDestroying = struct {};

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

    pub fn build(self: *WindowPlugin, commands: ecs.Commands) !void {
        try commands.addObserver(onConfigAdded, self);
        try commands.addSystem("update", readSDLWindowEvents, self);
    }

    pub fn onConfigAdded(
        _: *WindowPlugin,
        allocator: std.mem.Allocator,
        commands: ecs.Commands,
        config: ecs.Resource(Config),
        asset_loader: ecs.Resource(AssetLoader),
        _: ecs.Event(ecs.events.resource.Added(Config)),
    ) !void {
        const clear_color = Color.fromHex(config.value.window.clear_color) catch Color{ .r = 0, .g = 0, .b = 0 };

        const icon = asset_loader.value.loadImage(allocator, config.value.window.icon) catch null;

        var window = try Window.init(
            allocator,
            config.value.window.title,
            clear_color,
            icon,
            1280,
            720,
        );
        errdefer window.deinit(allocator);

        try commands.spawn(.{window});
    }

    pub fn readSDLWindowEvents(
        _: *WindowPlugin,
        observers: ecs.Observers,
        windows: ecs.Query(&.{Window}),
    ) void {
        var it = windows.iterator();
        if (it.next() == null) return;

        while (readSDLEvent()) |event| {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT,
                sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED,
                => {
                    observers.trigger(WindowDestroying{});
                    observers.trigger(ShuttingDown{});
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
