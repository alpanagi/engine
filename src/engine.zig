const sdl = @import("sdl");
const std = @import("std");
const util = @import("util.zig");

const AssetPlugin = @import("plugins/asset_plugin.zig").AssetPlugin;
const ConfigPlugin = @import("plugins/config_plugin.zig").ConfigPlugin;
const GraphicsPlugin = @import("plugins/graphics/graphics_plugin.zig").GraphicsPlugin;
const TimePlugin = @import("plugins/time_plugin.zig").TimePlugin;
const WindowPlugin = @import("plugins/window_plugin.zig").WindowPlugin;

const AssetLoader = resources.AssetLoader;
const Event = @import("ecs").Event;
const EventId = @import("ecs").EventId;
const Materials = resources.Materials;
const Meshes = resources.Meshes;
const ShuttingDown = events.ShuttingDown;
const Time = resources.Time;
const World = @import("ecs").World;

pub const components = struct {
    pub const Active = @import("components/active.zig").Active;
    pub const Camera = @import("components/camera.zig").Camera;
    pub const MeshInstance = @import("components/mesh_instance.zig").MeshInstance;
    pub const Transform = @import("components/transform.zig").Transform;
};

pub const data = struct {
    pub const MeshData = @import("data/mesh_data.zig").MeshData;
};

pub const events = struct {
    pub const component = @import("ecs").events.component;
    pub const resource = @import("ecs").events.resource;
    pub const ComponentAdded = @import("ecs").events.ComponentAdded;
    pub const ComponentDestroying = @import("ecs").events.ComponentDestroying;
    pub const ResourceAdded = @import("ecs").events.ResourceAdded;
    pub const ResourceDestroying = @import("ecs").events.ResourceDestroying;
    pub const ShuttingDown = struct {};
    pub const WindowDestroying = @import("plugins/window_plugin.zig").WindowDestroying;
};

pub const resources = struct {
    pub const AssetLoader = @import("resources/asset_loader/asset_loader.zig").AssetLoader;
    pub const Config = @import("resources/config.zig").Config;
    pub const Materials = @import("resources/materials.zig").Materials;
    pub const Meshes = @import("resources/meshes.zig").Meshes;
    pub const Time = @import("resources/time.zig").Time;
};

pub const Engine = struct {
    pub const Options = struct {
        working_directory: []const u8 = ".",
    };

    world: World,
    has_received_termination_request: bool = false,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, options: Options) Engine {
        if (!sdl.SDL_SetHint(sdl.SDL_HINT_RENDER_DRIVER, "vulkan")) util.sdlPanic();
        if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) util.sdlPanic();

        var world = World.init();
        addResources(&world, allocator, io, options);
        addPlugins(&world, allocator);

        return Engine{
            .world = world,
        };
    }

    fn addResources(
        world: *World,
        allocator: std.mem.Allocator,
        io: std.Io,
        options: Options,
    ) void {
        world.addResource(
            allocator,
            AssetLoader,
            AssetLoader.init(allocator, io, .{
                .working_directory = options.working_directory,
            }),
        );
        world.addResource(allocator, Time, Time.init(io));
        world.addResource(allocator, Materials, .{});
        world.addResource(allocator, Meshes, .{});
    }

    fn addPlugins(world: *World, allocator: std.mem.Allocator) void {
        world.addPlugin(allocator, TimePlugin);
        world.addPlugin(allocator, ConfigPlugin);
        world.addPlugin(allocator, AssetPlugin);
        world.addPlugin(allocator, GraphicsPlugin);
        world.addPlugin(allocator, WindowPlugin);
    }

    pub fn deinit(self: *Engine, allocator: std.mem.Allocator) void {
        self.world.deinit(allocator);
        sdl.SDL_Quit();
    }

    pub fn run(self: *Engine, allocator: std.mem.Allocator) void {
        self.world.addObserver(allocator, EventId.from(ShuttingDown), onShutdown, self);

        while (!self.has_received_termination_request) {
            self.world.runSystems(allocator);
        }
    }

    fn onShutdown(self: *Engine, _: Event(ShuttingDown)) void {
        self.has_received_termination_request = true;
    }
};
