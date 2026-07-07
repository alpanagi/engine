const sdl = @import("sdl");
const std = @import("std");

const Graphics = @import("graphics.zig").Graphics;
const Window = @import("window.zig").Window;

pub const Engine = struct {
    window: Window,
    graphics: Graphics,
    isRunning: bool = true,

    pub fn init() Engine {
        const window = Window.init();
        const graphics = Graphics.init();

        return Engine{
            .window = window,
            .graphics = graphics,
        };
    }

    pub fn deinit(self: *Engine) void {
        self.graphics.deinit();
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
