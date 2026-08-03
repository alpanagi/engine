const ecs = @import("ecs");
const std = @import("std");

const AssetLoader = @import("../resources/asset_loader.zig").AssetLoader;
const Config = @import("../resources/config.zig").Config;

pub const OnConfigLoaded = struct {};

pub const ConfigPlugin = struct {
    pub fn build(
        self: *ConfigPlugin,
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
    ) !void {
        try world.addOneShotSystem(allocator.*, load, self);
    }

    pub fn load(
        _: *ConfigPlugin,
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
    ) void {
        const config = readConfig(allocator.*, world) catch return;
        world.addResource(allocator.*, Config, config) catch return;
        world.trigger(allocator.*, OnConfigLoaded{});
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