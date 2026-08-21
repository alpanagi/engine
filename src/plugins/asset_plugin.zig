const ecs = @import("ecs");
const std = @import("std");

const AssetLoader = @import("../resources/asset_loader/asset_loader.zig").AssetLoader;
const panicOom = @import("../util.zig").panicOom;

pub const AssetPlugin = struct {
    io: std.Io,
    working_directory: []const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        working_directory: []const u8,
    ) AssetPlugin {
        return .{
            .io = io,
            .working_directory = allocator.dupe(u8, working_directory) catch
                panicOom("AssetPlugin.init"),
        };
    }

    pub fn deinit(self: *AssetPlugin, allocator: std.mem.Allocator) void {
        allocator.free(self.working_directory);
    }

    pub fn build(
        self: *AssetPlugin,
        allocator: std.mem.Allocator,
        resources: ecs.Resources,
        systems: ecs.Systems,
    ) void {
        resources.addOwned(allocator, AssetLoader, AssetLoader.init(allocator, self.io, .{
            .working_directory = self.working_directory,
        }));
        systems.addSystem(allocator, "pre_update", consumeCompletedFiles, self);
    }

    pub fn consumeCompletedFiles(
        _: *AssetPlugin,
        allocator: std.mem.Allocator,
        asset_loader: ecs.Resource(AssetLoader),
    ) void {
        const files = asset_loader.value.takeCompletedFiles(allocator);
        defer allocator.free(files);

        for (files) |*file| file.deinit(allocator);
    }
};
