const std = @import("std");

const AssetLoader = @import("../resources/asset_loader/asset_loader.zig").AssetLoader;
const Commands = @import("ecs").Commands;
const Resource = @import("ecs").Resource;

pub const AssetPlugin = struct {
    pub fn build(self: *AssetPlugin, allocator: std.mem.Allocator, commands: Commands) void {
        commands.addSystem(allocator, "pre-update", consumeCompletedFiles, self);
    }

    pub fn consumeCompletedFiles(
        _: *AssetPlugin,
        allocator: std.mem.Allocator,
        asset_loader: Resource(AssetLoader),
    ) void {
        const files = asset_loader.value.takeCompletedFiles(allocator);
        defer allocator.free(files);

        for (files) |*file| file.deinit(allocator);
    }
};
