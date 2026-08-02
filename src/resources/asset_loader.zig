const sdl = @import("sdl");
const sdl_image = @import("sdl_image");
const std = @import("std");
const toml = @import("toml");

pub const AssetLoader = struct {
    working_directory: []const u8,

    pub fn init(alloc: std.mem.Allocator, working_directory: []const u8) !AssetLoader {
        return AssetLoader{
            .working_directory = try alloc.dupe(u8, working_directory),
        };
    }

    pub fn deinit(self: *AssetLoader, alloc: std.mem.Allocator) void {
        alloc.free(self.working_directory);
    }

    pub fn readToml(
        self: *AssetLoader,
        comptime T: type,
        alloc: std.mem.Allocator,
        io: std.Io,
        path: []const u8,
    ) !T {
        const full_path = try std.fs.path.join(alloc, &.{ self.working_directory, path });
        defer alloc.free(full_path);

        const cwd = std.Io.Dir.cwd();
        const text = try cwd.readFileAlloc(io, full_path, alloc, .unlimited);
        defer alloc.free(text);

        return toml.parse(T, alloc, text) catch T.default(alloc);
    }

    pub fn loadImage(
        self: *AssetLoader,
        alloc: std.mem.Allocator,
        path: []const u8,
    ) !?*sdl.SDL_Surface {
        const full_path = try std.fs.path.join(alloc, &.{ self.working_directory, path });
        defer alloc.free(full_path);
        const image = sdl_image.IMG_Load(full_path.ptr);
        return @as(?*sdl.SDL_Surface, @ptrCast(image));
    }
};
