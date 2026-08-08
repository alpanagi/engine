const ecs = @import("ecs");
const std = @import("std");

const AssetLoader = @import("../resources/asset_loader/asset_loader.zig").AssetLoader;
const Config = @import("../resources/config.zig").Config;

pub const ConfigLoaded = struct {};

pub const ConfigPlugin = struct {
    pub fn build(self: *ConfigPlugin, commands: ecs.Commands) !void {
        try commands.addOneShotSystem(load, self);
    }

    pub fn load(
        self: *ConfigPlugin,
        allocator: std.mem.Allocator,
        commands: ecs.Commands,
        asset_loader: ecs.Resource(AssetLoader),
    ) !void {
        const config = try readConfig(allocator, asset_loader.value);
        try commands.addResource(Config, config);
        try commands.addOneShotSystem(announceConfigLoaded, self);
    }

    pub fn announceConfigLoaded(_: *ConfigPlugin, commands: ecs.Commands) void {
        commands.trigger(ConfigLoaded{});
    }
};

fn readConfig(allocator: std.mem.Allocator, asset_loader: *AssetLoader) !Config {
    return asset_loader.readToml(allocator, Config, "project.toml") catch {
        return Config.default(allocator);
    };
}