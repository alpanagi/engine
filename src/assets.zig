const std = @import("std");
const toml = @import("toml");

const ProjectConfig = @import("config.zig").ProjectConfig;

pub const AssetManager = struct {
    working_directory: []const u8,

    pub fn init(alloc: std.mem.Allocator, working_directory: []const u8) !AssetManager {
        return AssetManager{
            .working_directory = try alloc.dupe(u8, working_directory),
        };
    }

    pub fn deinit(self: *AssetManager, alloc: std.mem.Allocator) void {
        alloc.free(self.working_directory);
    }

    pub fn readToml(
        self: *AssetManager,
        comptime T: type,
        alloc: std.mem.Allocator,
        io: std.Io,
        toml_path: []const u8,
    ) !T {
        const full_toml_path = try std.fs.path.join(
            alloc,
            &.{ self.working_directory, toml_path },
        );
        defer alloc.free(full_toml_path);

        const cwd = std.Io.Dir.cwd();
        const text = try cwd.readFileAlloc(io, full_toml_path, alloc, .unlimited);
        defer alloc.free(text);

        return toml.parse(T, alloc, text) catch T.default(alloc);
    }
};
