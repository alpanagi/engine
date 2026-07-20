const builtin = @import("builtin");
const sdl = @import("sdl");
const std = @import("std");

const util = @import("util.zig");

const Color = @import("color.zig").Color;

pub const Window = struct {
    sdl_window: *sdl.SDL_Window,

    clear_color: Color,

    pub fn init(window_title: []const u8, clear_color: Color) Window {
        if (!sdl.SDL_SetHint(sdl.SDL_HINT_RENDER_DRIVER, "vulkan")) util.sdlPanic();
        if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
            util.sdlPanic();
        }

        const sdl_window: *sdl.SDL_Window = sdl.SDL_CreateWindow(
            window_title.ptr,
            1280,
            720,
            sdl.SDL_WINDOW_RESIZABLE,
        ) orelse util.sdlPanic();

        return Window{
            .sdl_window = sdl_window,
            .clear_color = clear_color,
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
