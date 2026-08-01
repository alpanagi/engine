const ecs = @import("ecs");
const sdl = @import("sdl");
const std = @import("std");

const util = @import("../util.zig");

const Color = @import("../color.zig").Color;
const OnShutdown = @import("../engine.zig").OnShutdown;

pub const OnWindowCreate = struct { sdl_window: *sdl.SDL_Window };
pub const OnWindowDestroy = struct {};
pub const OnWindowUpdate = struct { sdl_window: *sdl.SDL_Window, clear_color: Color };

pub const WindowPlugin = struct {
    sdl_window: ?*sdl.SDL_Window = null,
    clear_color: Color = Color.fromHex("#000000") catch unreachable,

    hasReceivedTerminationRequest: bool = false,

    pub fn build(self: *WindowPlugin, allocator: std.mem.Allocator, world: *ecs.World) !void {
        const sdl_window: *sdl.SDL_Window = sdl.SDL_CreateWindow(
            "Engine".ptr,
            1280,
            720,
            sdl.SDL_WINDOW_RESIZABLE,
        ) orelse util.sdlPanic();

        // if (icon != null) {
        //     if (!sdl.SDL_SetWindowIcon(sdl_window, icon)) util.sdlPanic();
        // }

        self.sdl_window = sdl_window;
        self.clear_color = try Color.fromHex("#00ff00");

        world.trigger(allocator, OnWindowCreate{ .sdl_window = self.sdl_window.? });

        try world.addSystem(allocator, "update", readSDLWindowEvents, self);
        try world.addSystem(allocator, "update", update, self);
    }

    pub fn readSDLWindowEvents(
        self: *WindowPlugin,
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
    ) void {
        if (self.hasReceivedTerminationRequest) return;

        while (readSDLEvent()) |event| {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT,
                sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED,
                => {
                    self.hasReceivedTerminationRequest = true;

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
        if (self.hasReceivedTerminationRequest) return;

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
