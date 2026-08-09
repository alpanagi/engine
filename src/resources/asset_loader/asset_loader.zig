const sdl = @import("sdl");
const sdl_image = @import("sdl_image");
const std = @import("std");
const toml = @import("toml");

const obj = @import("obj.zig");

const util = @import("../../util.zig");

const MeshData = @import("../mesh_data.zig").MeshData;

pub const File = struct {
    path: []const u8,
    data: ?[]u8,

    fn init(allocator: std.mem.Allocator, path: []const u8) !File {
        return File{
            .path = try allocator.dupe(u8, path),
            .data = null,
        };
    }

    pub fn deinit(self: *File, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        if (self.data) |bytes| allocator.free(bytes);
    }
};

pub const AssetLoader = struct {
    pub const Options = struct {
        isConcurrent: bool = true,
        working_directory: []const u8,
    };

    isConcurrent: bool,
    working_directory: []const u8,

    io: std.Io,
    pending_group: std.Io.Group = .init,
    completed_mutex: std.Io.Mutex = .init,
    completed: std.ArrayList(File) = .empty,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, options: Options) !AssetLoader {
        return AssetLoader{
            .io = io,
            .isConcurrent = options.isConcurrent,
            .working_directory = try allocator.dupe(u8, options.working_directory),
        };
    }

    pub fn deinit(self: *AssetLoader, allocator: std.mem.Allocator) void {
        self.pending_group.cancel(self.io);

        for (self.completed.items) |*file| file.deinit(allocator);
        self.completed.deinit(allocator);

        allocator.free(self.working_directory);
    }

    pub fn readFileAsync(
        self: *AssetLoader,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) !void {
        var file = try File.init(allocator, path);
        errdefer file.deinit(allocator);

        if (!self.isConcurrent) {
            file.data = self.readData(allocator, file.path);
            self.complete(allocator, file);
            return;
        }

        try self.pending_group.concurrent(self.io, readFileWorker, .{ self, allocator, file });
    }

    fn readFileWorker(self: *AssetLoader, allocator: std.mem.Allocator, requested: File) void {
        var file = requested;
        file.data = self.readData(allocator, file.path);

        self.complete(allocator, file);
    }

    fn complete(self: *AssetLoader, allocator: std.mem.Allocator, file: File) void {
        self.completed_mutex.lockUncancelable(self.io);
        defer self.completed_mutex.unlock(self.io);

        self.completed.append(allocator, file) catch {
            util.panic("Out of memory for completed file.\n", .{});
        };
    }

    fn readData(self: *AssetLoader, allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
        return self.readBinaryFileAlloc(allocator, path) catch |err| {
            std.log.err("failed to read {s}: {t}\n", .{ path, err });
            return null;
        };
    }

    pub fn takeCompletedFiles(self: *AssetLoader, allocator: std.mem.Allocator) []File {
        self.completed_mutex.lockUncancelable(self.io);
        defer self.completed_mutex.unlock(self.io);

        return self.completed.toOwnedSlice(allocator) catch {
            util.panic("Out of memory for completed files.\n", .{});
        };
    }

    pub fn readToml(
        self: *AssetLoader,
        allocator: std.mem.Allocator,
        comptime T: type,
        path: []const u8,
    ) !T {
        const text = try self.readBinaryFileAlloc(allocator, path);
        defer allocator.free(text);

        return self.parseToml(allocator, T, text);
    }

    pub fn parseToml(
        _: *AssetLoader,
        allocator: std.mem.Allocator,
        comptime T: type,
        text: []const u8,
    ) !T {
        return toml.parse(T, allocator, text) catch T.default(allocator);
    }

    pub fn readBinaryFileAlloc(
        self: *AssetLoader,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) ![]u8 {
        const full_path = try std.fs.path.join(allocator, &.{ self.working_directory, path });
        defer allocator.free(full_path);

        const cwd = std.Io.Dir.cwd();
        return cwd.readFileAlloc(self.io, full_path, allocator, .unlimited);
    }

    pub fn loadObj(
        self: *AssetLoader,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) !MeshData {
        const bytes = try self.readBinaryFileAlloc(allocator, path);
        defer allocator.free(bytes);

        return self.parseObj(allocator, bytes);
    }

    pub fn parseObj(
        _: *AssetLoader,
        allocator: std.mem.Allocator,
        bytes: []const u8,
    ) !MeshData {
        var reader = std.Io.Reader.fixed(bytes);
        return obj.parse(allocator, &reader);
    }

    pub fn loadImage(
        self: *AssetLoader,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) !?*sdl.SDL_Surface {
        const full_path = try std.fs.path.joinZ(allocator, &.{ self.working_directory, path });
        defer allocator.free(full_path);
        const image = sdl_image.IMG_Load(full_path.ptr);
        return @as(?*sdl.SDL_Surface, @ptrCast(image));
    }
};
