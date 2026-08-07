const sdl = @import("sdl");
const std = @import("std");

const util = @import("util.zig");

pub const commands = struct {
    pub const RegisterMesh = @import("plugins/graphics/graphics_plugin.zig").RegisterMesh;
};

pub const components = struct {
    pub const Mesh = @import("components/mesh.zig").Mesh;
    pub const Transform = @import("components/transform.zig").Transform;
};

pub const data = struct {
    pub const MeshData = @import("resources/mesh_data.zig").MeshData;
};

pub const events = struct {
    pub const Added = @import("ecs").events.Added;
    pub const ConfigLoaded = @import("plugins/config_plugin.zig").ConfigLoaded;
    pub const Destroying = @import("ecs").events.Destroying;
    pub const ShuttingDown = struct {};
    pub const WindowDestroying = @import("plugins/window_plugin.zig").WindowDestroying;
};

const plugins = struct {
    pub const ConfigPlugin = @import("plugins/config_plugin.zig").ConfigPlugin;
    pub const GraphicsPlugin = @import("plugins/graphics/graphics_plugin.zig").GraphicsPlugin;
    pub const TimePlugin = @import("plugins/time_plugin.zig").TimePlugin;
    pub const WindowPlugin = @import("plugins/window_plugin.zig").WindowPlugin;
};

pub const resources = struct {
    pub const AssetLoader = @import("resources/asset_loader/asset_loader.zig").AssetLoader;
    pub const Config = @import("resources/config.zig").Config;
    pub const Materials = @import("resources/materials/materials.zig").Materials;
    pub const Time = @import("resources/time.zig").Time;
};

const AssetLoader = resources.AssetLoader;
const ConfigPlugin = plugins.ConfigPlugin;
const GraphicsPlugin = plugins.GraphicsPlugin;
const Materials = resources.Materials;
const ShuttingDown = events.ShuttingDown;
const Time = resources.Time;
const TimePlugin = plugins.TimePlugin;
const WindowPlugin = plugins.WindowPlugin;
const World = @import("ecs").World;

pub const Engine = struct {
    pub const Options = struct {
        working_directory: []const u8 = ".",
    };

    world: World,
    hasReceivedTerminationRequest: bool = false,

    pub fn init(alloc: std.mem.Allocator, io: std.Io, options: Options) !Engine {
        if (!sdl.SDL_SetHint(sdl.SDL_HINT_RENDER_DRIVER, "vulkan")) util.sdlPanic();
        if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) util.sdlPanic();

        var world = World.init();
        try addResources(&world, alloc, io, options);
        try addPlugins(&world, alloc);

        return Engine{
            .world = world,
        };
    }

    fn addResources(
        world: *World,
        alloc: std.mem.Allocator,
        io: std.Io,
        options: Options,
    ) !void {
        try world.addResource(
            alloc,
            AssetLoader,
            try AssetLoader.init(alloc, io, options.working_directory),
        );
        try world.addResource(alloc, Time, Time.init(io));
        try world.addResource(alloc, Materials, .{});
    }

    fn addPlugins(world: *World, alloc: std.mem.Allocator) !void {
        try world.addPlugin(alloc, TimePlugin);
        try world.addPlugin(alloc, ConfigPlugin);
        try world.addPlugin(alloc, GraphicsPlugin);
        try world.addPlugin(alloc, WindowPlugin);
    }

    pub fn deinit(self: *Engine, alloc: std.mem.Allocator) void {
        self.world.deinit(alloc);
        sdl.SDL_Quit();
    }

    pub fn run(self: *Engine, allocator: std.mem.Allocator) !void {
        try self.world.addObserver(allocator, onShutdown, self);

        while (!self.hasReceivedTerminationRequest) {
            try self.world.runSystems(allocator);
        }
    }

    fn onShutdown(
        self: *Engine,
        _: std.mem.Allocator,
        _: *World,
        _: *const ShuttingDown,
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
