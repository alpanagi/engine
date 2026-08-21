const ecs = @import("ecs");
const sdl = @import("sdl");
const std = @import("std");
const util = @import("../util.zig");

const AssetLoader = @import("../params/asset_loader/asset_loader.zig").AssetLoader;
const Config = @import("../resources/config.zig").Config;
const ShuttingDown = @import("../engine.zig").ShuttingDown;

pub const WindowDestroying = struct {};
pub const WindowPixelSizeChanged = struct {
    width: u32,
    height: u32,
};

pub const Window = struct {
    sdl_window: *sdl.SDL_Window,

    title: [:0]u8,
    icon: ?*sdl.SDL_Surface = null,

    width: u32,
    height: u32,

    pub fn init(
        allocator: std.mem.Allocator,
        title: []const u8,
        icon: ?*sdl.SDL_Surface,
        width: u32,
        height: u32,
    ) Window {
        const window_title = allocator.dupeZ(u8, title) catch util.panicOom("Window.init");

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
        allocator: std.mem.Allocator,
        observers: ecs.Observers,
        systems: ecs.Systems,
    ) void {
        observers.add(allocator, ecs.events.resourceAdded(Config), onConfigAdded, self);
        systems.add(allocator, "update", readSDLWindowEvents, self);
    }

    pub fn onConfigAdded(
        _: *WindowPlugin,
        allocator: std.mem.Allocator,
        entities: ecs.Entities,
        config: ecs.Resource(Config),
        asset_loader: AssetLoader,
        _: ecs.Event(ecs.events.ResourceAdded),
    ) void {
        const icon = asset_loader.loadImage(allocator, config.value.window.icon) catch null;
        const window = Window.init(allocator, config.value.window.title, icon, 1280, 720);
        entities.spawnOwned(allocator, .{window});
    }

    pub fn readSDLWindowEvents(
        _: *WindowPlugin,
        allocator: std.mem.Allocator,
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
                    observers.dispatchOwnedEvent(allocator, WindowDestroying{});
                    observers.dispatchOwnedEvent(allocator, ShuttingDown{});
                    return;
                },
                sdl.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED => {
                    const width: c_int = event.window.data1;
                    const height: c_int = event.window.data2;
                    if (width <= 0 or height <= 0) continue;

                    observers.dispatchOwnedEvent(allocator, WindowPixelSizeChanged{
                        .width = @intCast(width),
                        .height = @intCast(height),
                    });
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
