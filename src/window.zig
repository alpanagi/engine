const builtin = @import("builtin");
const sdl = @import("sdl");
const std = @import("std");

const WINDOW_GRAPHICS_API = switch (builtin.target.os.tag) {
    .macos => sdl.SDL_WINDOW_METAL,
    else => sdl.SDL_WINDOW_VULKAN,
};

fn sdlPanic() noreturn {
    std.log.debug("{s}", .{sdl.SDL_GetError()});
    std.process.exit(1);
}

pub const Window = struct {
    sdl_window: *sdl.SDL_Window,

    pub fn init() Window {
        if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
            sdlPanic();
        }

        const sdl_window: *sdl.SDL_Window = sdl.SDL_CreateWindow(
            "engine",
            1280,
            720,
            sdl.SDL_WINDOW_RESIZABLE | WINDOW_GRAPHICS_API,
        ) orelse sdlPanic();

        return Window{
            .sdl_window = sdl_window,
        };
    }

    pub fn deinit(_: *Window) void {
        sdl.SDL_Quit();
    }

    pub fn readEvent(_: *const Window) ?sdl.SDL_Event {
        var event: sdl.SDL_Event = undefined;
        if (sdl.SDL_PollEvent(&event)) {
            return event;
        }

        return null;
    }
};
