const ecs = @import("ecs");
const std = @import("std");

const AssetLoader = @import("../resources/asset_loader/asset_loader.zig").AssetLoader;
const Config = @import("../resources/config.zig").Config;

pub const ConfigLoaded = struct {};

pub const ConfigPlugin = struct {
    pub fn build(
        self: *ConfigPlugin,
        allocator: std.mem.Allocator,
        world: *ecs.World,
    ) !void {
        try world.addOneShotSystem(allocator, load, self);
    }

    pub fn load(
        _: *ConfigPlugin,
        allocator: std.mem.Allocator,
        world: *ecs.World,
    ) !void {
        const config = try readConfig(allocator, world);
        try world.addResource(allocator, Config, config);
        world.trigger(allocator, ConfigLoaded{});
    }
};

fn readConfig(allocator: std.mem.Allocator, world: *ecs.World) !Config {
    const asset_loader = world.getResource(AssetLoader) orelse {
        return Config.default(allocator);
    };

    return asset_loader.readToml(allocator, Config, "project.toml") catch {
        return Config.default(allocator);
    };
}