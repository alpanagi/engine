const sdl = @import("sdl");
const sdl_image = @import("sdl_image");
const std = @import("std");
const toml = @import("toml");

const obj = @import("obj.zig");

const MeshData = @import("../mesh_data.zig").MeshData;

pub const AssetLoader = struct {
    io: std.Io,
    working_directory: []const u8,

    pub fn init(alloc: std.mem.Allocator, io: std.Io, working_directory: []const u8) !AssetLoader {
        return AssetLoader{
            .io = io,
            .working_directory = try alloc.dupe(u8, working_directory),
        };
    }

    pub fn deinit(self: *AssetLoader, alloc: std.mem.Allocator) void {
        alloc.free(self.working_directory);
    }

    pub fn readToml(
        self: *AssetLoader,
        alloc: std.mem.Allocator,
        comptime T: type,
        path: []const u8,
    ) !T {
        const full_path = try std.fs.path.join(alloc, &.{ self.working_directory, path });
        defer alloc.free(full_path);

        const cwd = std.Io.Dir.cwd();
        const text = try cwd.readFileAlloc(self.io, full_path, alloc, .unlimited);
        defer alloc.free(text);

        return toml.parse(T, alloc, text) catch T.default(alloc);
    }

    pub fn readBinaryFileAlloc(
        self: *AssetLoader,
        alloc: std.mem.Allocator,
        path: []const u8,
    ) ![]u8 {
        const full_path = try std.fs.path.join(alloc, &.{ self.working_directory, path });
        defer alloc.free(full_path);

        const cwd = std.Io.Dir.cwd();
        return cwd.readFileAlloc(self.io, full_path, alloc, .unlimited);
    }

    pub fn loadObj(
        self: *AssetLoader,
        alloc: std.mem.Allocator,
        path: []const u8,
    ) !MeshData {
        const full_path = try std.fs.path.join(alloc, &.{ self.working_directory, path });
        defer alloc.free(full_path);

        var file = try std.Io.Dir.cwd().openFile(self.io, full_path, .{ .mode = .read_only });
        defer file.close(self.io);

        var buffer: [4096]u8 = undefined;
        var reader = file.reader(self.io, &buffer);

        return obj.parse(alloc, &reader.interface);
    }

    pub fn loadImage(
        self: *AssetLoader,
        alloc: std.mem.Allocator,
        path: []const u8,
    ) !?*sdl.SDL_Surface {
        const full_path = try std.fs.path.joinZ(alloc, &.{ self.working_directory, path });
        defer alloc.free(full_path);
        const image = sdl_image.IMG_Load(full_path.ptr);
        return @as(?*sdl.SDL_Surface, @ptrCast(image));
    }
};
