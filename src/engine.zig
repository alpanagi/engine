const sdl = @import("sdl");
const std = @import("std");

const util = @import("util.zig");

const AssetManager = @import("assets.zig").AssetManager;
const Color = @import("color.zig").Color;
const Graphics = @import("graphics.zig").Graphics;
const Window = @import("window.zig").Window;

pub const Engine = struct {
    window: Window,
    graphics: Graphics,
    asset_manager: AssetManager,

    hasReceivedTerminationRequest: bool = false,

    pub fn init(alloc: std.mem.Allocator, io: std.Io, working_directory: []const u8) !Engine {
        const asset_manager = try AssetManager.init(alloc, io, working_directory);

        const window = Window.init(
            asset_manager.project_data.window.title,
            try Color.fromHex(asset_manager.project_data.window.clear_color),
        );
        const graphics = Graphics.init(alloc, &window);

        return Engine{
            .window = window,
            .graphics = graphics,
            .asset_manager = asset_manager,
        };
    }

    pub fn deinit(self: *Engine, alloc: std.mem.Allocator) void {
        self.asset_manager.deinit(alloc);
        self.graphics.deinit(alloc);
        self.window.deinit();
    }

    pub fn run(self: *Engine) void {
        while (!self.hasReceivedTerminationRequest) {
            while (self.window.readEvent()) |event| {
                switch (event.type) {
                    sdl.SDL_EVENT_QUIT,
                    sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED,
                    => self.hasReceivedTerminationRequest = true,
                    else => {},
                }
            }

            self.graphics.draw(&self.window);
        }
    }

    pub fn createMaterial(
        self: *Engine,
        alloc: std.mem.Allocator,
        io: std.Io,
        shaderPath: []const u8,
    ) void {
        const cwd = std.Io.Dir.cwd();
        const file = cwd.openFile(io, shaderPath, .{ .mode = .read_only }) catch {
            util.panic("Failed to open shader file: {s}\n", .{shaderPath});
        };
        defer file.close(io);

        var buffer: [8192]u8 = undefined;
        var reader = file.reader(io, &buffer);
        self.graphics.createMaterial(alloc, &reader.interface) catch {
            util.panic("Failed to parse shader: {s}\n", .{shaderPath});
        };
    }
};
