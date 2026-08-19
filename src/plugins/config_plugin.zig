const ecs = @import("ecs");
const std = @import("std");

const AssetLoader = @import("../resources/asset_loader/asset_loader.zig").AssetLoader;
const Config = @import("../resources/config.zig").Config;

pub const ConfigPlugin = struct {
    pub fn build(self: *ConfigPlugin, commands: ecs.Commands) void {
        commands.addOneShotSystem(setup, self);
    }

    pub fn setup(
        _: *ConfigPlugin,
        allocator: std.mem.Allocator,
        commands: ecs.Commands,
        asset_loader: ecs.Resource(AssetLoader),
    ) void {
        const config = asset_loader.value.loadToml(allocator, Config, "project.toml") catch
            Config.default(allocator);
        commands.addOwnedResource(Config, config);
    }
};
