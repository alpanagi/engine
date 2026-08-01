const sdl = @import("sdl");
const std = @import("std");

const World = @import("ecs").World;

const util = @import("util.zig");

pub const OnShutdown = struct {};

pub const Engine = struct {
    world: World,

    hasReceivedTerminationRequest: bool = false,

    pub fn init(_: std.mem.Allocator, _: std.Io, _: []const u8) !Engine {
        if (!sdl.SDL_SetHint(sdl.SDL_HINT_RENDER_DRIVER, "vulkan")) util.sdlPanic();
        if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) util.sdlPanic();

        return Engine{
            .world = World.init(),
        };
    }

    pub fn deinit(self: *Engine, alloc: std.mem.Allocator) void {
        self.world.deinit(alloc);
        sdl.SDL_Quit();
    }

    pub fn run(self: *Engine, allocator: std.mem.Allocator) !void {
        try self.world.addObserver(allocator, onShutdown, self);

        while (!self.hasReceivedTerminationRequest) {
            var it = self.world.iterateSystems();
            while (it.next(&self.world)) |system| system.run(allocator, &self.world);
        }
    }

    fn onShutdown(
        self: *Engine,
        _: *const std.mem.Allocator,
        _: *World,
        _: *const OnShutdown,
    ) void {
        self.hasReceivedTerminationRequest = true;
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
