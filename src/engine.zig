const std = @import("std");
const sdl = @import("sdl");

const Window = @import("window.zig").Window;

pub const Engine = struct {
    window: Window,
    isRunning: bool = true,

    pub fn init() Engine {
        const window = Window.init();

        return Engine{
            .window = window,
        };
    }

    pub fn deinit(self: *Engine) void {
        self.window.deinit();
    }

    pub fn run(self: *Engine) void {
        while (self.isRunning) {
            while (self.window.readEvent()) |event| {
                switch (event.type) {
                    sdl.SDL_EVENT_QUIT, sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED => self.isRunning = false,
                    else => {},
                }
            }
        }
    }
};
