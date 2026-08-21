const sdl = @import("sdl");
const std = @import("std");
const util = @import("util.zig");

const AssetPlugin = @import("plugins/asset_plugin.zig").AssetPlugin;
const ConfigPlugin = @import("plugins/config_plugin.zig").ConfigPlugin;
const GraphicsPlugin = @import("plugins/graphics/graphics_plugin.zig").GraphicsPlugin;
const TimePlugin = @import("plugins/time_plugin.zig").TimePlugin;
const TimerPlugin = @import("plugins/timer_plugin.zig").TimerPlugin;
const WindowPlugin = @import("plugins/window_plugin.zig").WindowPlugin;

const Event = @import("ecs").Event;
const Observers = @import("ecs").Observers;
const World = @import("ecs").World;
const eventId = @import("ecs").eventId;

pub const ShuttingDown = struct {};

pub const Engine = struct {
    pub const Options = struct {
        working_directory: []const u8 = ".",
    };

    world: World,
    has_received_termination_request: bool = false,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, options: Options) Engine {
        if (!sdl.SDL_SetHint(sdl.SDL_HINT_RENDER_DRIVER, "vulkan")) util.sdlPanic();
        if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) util.sdlPanic();

        var world = World.init(allocator);
        addPlugins(&world, allocator, io, options);

        return Engine{
            .world = world,
        };
    }

    fn addPlugins(
        world: *World,
        allocator: std.mem.Allocator,
        io: std.Io,
        options: Options,
    ) void {
        world.addOwnedPlugin(allocator, TimePlugin{ .io = io });
        world.addOwnedPlugin(allocator, TimerPlugin{});
        world.addOwnedPlugin(allocator, ConfigPlugin{});
        world.addOwnedPlugin(allocator, AssetPlugin.init(allocator, io, options.working_directory));
        world.addOwnedPlugin(allocator, GraphicsPlugin.init());
        world.addOwnedPlugin(allocator, WindowPlugin{});
    }

    pub fn deinit(self: *Engine, allocator: std.mem.Allocator) void {
        self.world.deinit(allocator);
        sdl.SDL_Quit();
    }

    pub fn addOwnedPlugin(self: *Engine, allocator: std.mem.Allocator, plugin: anytype) void {
        self.world.addOwnedPlugin(allocator, plugin);
    }

    pub fn run(self: *Engine, allocator: std.mem.Allocator) void {
        const observers = Observers.fromWorld(allocator, &self.world);
        observers.add(allocator, eventId(ShuttingDown), onShutdown, self);

        while (!self.has_received_termination_request) {
            self.world.runSystems(allocator);
        }
    }

    fn onShutdown(self: *Engine, _: Event(ShuttingDown)) void {
        self.has_received_termination_request = true;
    }
};
