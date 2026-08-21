const gltf = @import("gltf");
const obj = @import("parsers/obj.zig");
const sdl = @import("sdl");
const sdl_image = @import("sdl_image");
const std = @import("std");
const toml = @import("toml");
const util = @import("../../util.zig");

const MeshData = @import("../../data/mesh_data.zig").MeshData;
const World = @import("ecs").World;

pub const AssetLoaderError = error{
    ImageLoadFailed,
};

pub const File = struct {
    path: []const u8,
    data: ?[]u8,

    fn init(allocator: std.mem.Allocator, path: []const u8) File {
        return File{
            .path = allocator.dupe(u8, path) catch util.panicOom("File.init"),
            .data = null,
        };
    }

    pub fn deinit(self: *File, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        if (self.data) |bytes| allocator.free(bytes);
    }
};

pub const AssetLoader = struct {
    pub const State = AssetLoaderState;

    state: *State,

    pub fn fromWorld(_: std.mem.Allocator, world: *World) AssetLoader {
        return .{
            .state = world.resources.get(State) orelse
                util.panic("system requires AssetLoader but the asset plugin is not registered", .{}),
        };
    }

    pub fn readBinaryFileAlloc(
        self: AssetLoader,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) ![]u8 {
        return self.state.readBinaryFile(allocator, path);
    }

    pub fn readFileAsync(
        self: AssetLoader,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) void {
        self.state.readFileAsync(allocator, path);
    }

    pub fn loadGlb(
        self: AssetLoader,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) !gltf.Gltf {
        const bytes = try self.readBinaryFileAlloc(allocator, path);
        defer allocator.free(bytes);

        return self.parseGlb(allocator, bytes);
    }

    pub fn loadImage(
        self: AssetLoader,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) !*sdl.SDL_Surface {
        const full_path = std.fs.path.joinZ(allocator, &.{ self.state.working_directory, path }) catch
            util.panicOom("AssetLoader.loadImage");
        defer allocator.free(full_path);

        const image = sdl_image.IMG_Load(full_path.ptr);
        if (image == null) {
            std.log.err("failed to load image {s}: {s}\n", .{ path, sdl.SDL_GetError() });
            return AssetLoaderError.ImageLoadFailed;
        }

        return @ptrCast(image);
    }

    pub fn loadObj(
        self: AssetLoader,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) !MeshData {
        const bytes = try self.readBinaryFileAlloc(allocator, path);
        defer allocator.free(bytes);

        return self.parseObj(allocator, bytes);
    }

    pub fn loadToml(
        self: AssetLoader,
        allocator: std.mem.Allocator,
        comptime T: type,
        path: []const u8,
    ) !T {
        const text = try self.readBinaryFileAlloc(allocator, path);
        defer allocator.free(text);

        return self.parseToml(allocator, T, text);
    }

    pub fn parseGlb(
        _: AssetLoader,
        allocator: std.mem.Allocator,
        bytes: []const u8,
    ) !gltf.Gltf {
        return gltf.parseAlloc(allocator, bytes);
    }

    pub fn parseObj(
        _: AssetLoader,
        allocator: std.mem.Allocator,
        bytes: []const u8,
    ) !MeshData {
        var reader = std.Io.Reader.fixed(bytes);
        return obj.parse(allocator, &reader);
    }

    pub fn parseToml(
        _: AssetLoader,
        allocator: std.mem.Allocator,
        comptime T: type,
        text: []const u8,
    ) T {
        return toml.parseAlloc(allocator, T, text) catch T.default(allocator);
    }
};

const AssetLoaderState = struct {
    pub const Options = struct {
        is_concurrent: bool = true,
        working_directory: []const u8,
    };

    is_concurrent: bool,
    working_directory: []const u8,

    io: std.Io,
    pending_group: std.Io.Group = .init,
    completed_mutex: std.Io.Mutex = .init,
    completed: std.ArrayList(File) = .empty,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, options: Options) AssetLoaderState {
        return AssetLoaderState{
            .io = io,
            .is_concurrent = options.is_concurrent,
            .working_directory = allocator.dupe(u8, options.working_directory) catch
                util.panicOom("AssetLoader.State.init"),
        };
    }

    pub fn deinit(self: *AssetLoaderState, allocator: std.mem.Allocator) void {
        self.pending_group.cancel(self.io);

        for (self.completed.items) |*file| file.deinit(allocator);
        self.completed.deinit(allocator);

        allocator.free(self.working_directory);
    }

    pub fn readBinaryFile(
        self: *AssetLoaderState,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) ![]u8 {
        const full_path = std.fs.path.join(allocator, &.{ self.working_directory, path }) catch
            util.panicOom("AssetLoader.State.readBinaryFile");
        defer allocator.free(full_path);

        const cwd = std.Io.Dir.cwd();
        return cwd.readFileAlloc(self.io, full_path, allocator, .unlimited) catch |err| switch (err) {
            error.OutOfMemory => util.panicOom("AssetLoader.State.readBinaryFile"),
            else => |e| return e,
        };
    }

    pub fn readFileAsync(
        self: *AssetLoaderState,
        allocator: std.mem.Allocator,
        path: []const u8,
    ) void {
        const file = File.init(allocator, path);

        if (!self.is_concurrent) {
            self.readFileWorker(allocator, file);
            return;
        }

        self.pending_group.concurrent(
            self.io,
            AssetLoaderState.readFileWorker,
            .{ self, allocator, file },
        ) catch {
            self.readFileWorker(allocator, file);
        };
    }

    pub fn takeCompletedFiles(self: *AssetLoaderState, allocator: std.mem.Allocator) []File {
        self.completed_mutex.lockUncancelable(self.io);
        defer self.completed_mutex.unlock(self.io);

        return self.completed.toOwnedSlice(allocator) catch
            util.panicOom("AssetLoader.State.takeCompletedFiles");
    }

    fn readFileWorker(self: *AssetLoaderState, allocator: std.mem.Allocator, requested: File) void {
        var file = requested;

        if (self.readBinaryFile(allocator, file.path)) |data| {
            file.data = data;
        } else |err| {
            std.log.err("failed to read {s}: {t}\n", .{ file.path, err });
        }

        self.completed_mutex.lockUncancelable(self.io);
        defer self.completed_mutex.unlock(self.io);

        self.completed.append(allocator, file) catch
            util.panicOom("AssetLoader.State.readFileWorker");
    }
};
