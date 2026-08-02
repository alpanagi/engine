const std = @import("std");

const ecs = @import("ecs");

const AssetLoader = @import("../resources/asset_loader.zig").AssetLoader;

pub const RegisterModuleFunction = *const fn (allocator: *const std.mem.Allocator, world: *ecs.World) callconv(.c) void;

pub const ModuleLoaderError = error{
    MissingAssetLoaderResource,
    MissingRegisterModuleSymbol,
};

pub const ModuleLoaderPlugin = struct {
    pub fn build(
        _: *ModuleLoaderPlugin,
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
    ) !void {
        const asset_loader = world.getResource(AssetLoader) orelse {
            return ModuleLoaderError.MissingAssetLoaderResource;
        };

        const modules_path = try std.fs.path.join(
            allocator.*,
            &.{ asset_loader.working_directory, "assets", "modules" },
        );
        defer allocator.free(modules_path);

        var dir = std.Io.Dir.cwd().openDir(
            asset_loader.io,
            modules_path,
            .{ .iterate = true },
        ) catch return;
        defer dir.close(asset_loader.io);

        var it = dir.iterate();
        while (it.next(asset_loader.io) catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".so")) continue;

            const module_path = std.fs.path.join(
                allocator.*,
                &.{ modules_path, entry.name },
            ) catch continue;
            defer allocator.free(module_path);

            loadModule(allocator.*, world, module_path) catch continue;
        }
    }
};

fn loadModule(allocator: std.mem.Allocator, world: *ecs.World, path: []const u8) !void {
    var library = try std.DynLib.open(path);
    errdefer library.close();

    const register = library.lookup(RegisterModuleFunction, "registerModule") orelse {
        return ModuleLoaderError.MissingRegisterModuleSymbol;
    };

    register(&allocator, world);
}
