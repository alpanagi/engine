const std = @import("std");

const Commands = @import("ecs").Commands;
const Event = @import("ecs").Event;
const Observers = @import("ecs").Observers;
const Resource = @import("ecs").Resource;

const AssetLoader = @import("../resources/asset_loader/asset_loader.zig").AssetLoader;
const File = @import("../resources/asset_loader/asset_loader.zig").File;
const RegisterMesh = @import("graphics/graphics_plugin.zig").RegisterMesh;

pub const LoadMesh = struct {
    id: []const u8,
    material: []const u8,
    path: []const u8,

    fn dupe(self: *const LoadMesh, allocator: std.mem.Allocator) !LoadMesh {
        const id = try allocator.dupe(u8, self.id);
        errdefer allocator.free(id);

        const material = try allocator.dupe(u8, self.material);
        errdefer allocator.free(material);

        const path = try allocator.dupe(u8, self.path);

        return LoadMesh{ .id = id, .material = material, .path = path };
    }

    fn deinit(self: *LoadMesh, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.material);
        allocator.free(self.path);
    }
};

const Request = union(enum) {
    mesh: LoadMesh,

    fn path(self: Request) []const u8 {
        return switch (self) {
            .mesh => |mesh| mesh.path,
        };
    }

    fn deinit(self: *Request, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .mesh => |*mesh| mesh.deinit(allocator),
        }
    }
};

pub const AssetPlugin = struct {
    requests: std.ArrayList(Request) = .empty,

    pub fn deinit(self: *AssetPlugin, allocator: std.mem.Allocator) void {
        for (self.requests.items) |*request| request.deinit(allocator);
        self.requests.deinit(allocator);
    }

    pub fn build(self: *AssetPlugin, commands: Commands) !void {
        try commands.addObserver(onMeshLoad, self);
        try commands.addSystem("pre-update", publishCompletedFiles, self);
    }

    pub fn onMeshLoad(
        self: *AssetPlugin,
        allocator: std.mem.Allocator,
        asset_loader: Resource(AssetLoader),
        event: Event(LoadMesh),
    ) !void {
        var request = Request{ .mesh = try event.value.dupe(allocator) };
        errdefer request.deinit(allocator);

        try self.requests.append(allocator, request);
        errdefer _ = self.requests.pop();

        try asset_loader.value.readFileAsync(allocator, event.value.path);
    }

    pub fn publishCompletedFiles(
        self: *AssetPlugin,
        allocator: std.mem.Allocator,
        asset_loader: Resource(AssetLoader),
        observers: Observers,
    ) void {
        const files = asset_loader.value.takeCompletedFiles(allocator);
        defer allocator.free(files);

        for (files) |*file| {
            defer file.deinit(allocator);

            self.publish(allocator, asset_loader.value, observers, file);
        }
    }

    fn publish(
        self: *AssetPlugin,
        allocator: std.mem.Allocator,
        asset_loader: *AssetLoader,
        observers: Observers,
        file: *File,
    ) void {
        var request = self.takeRequest(file.path) orelse return;
        defer request.deinit(allocator);

        const bytes = file.data orelse return;

        switch (request) {
            .mesh => |mesh| publishMesh(allocator, asset_loader, observers, mesh, bytes),
        }
    }

    fn publishMesh(
        allocator: std.mem.Allocator,
        asset_loader: *AssetLoader,
        observers: Observers,
        mesh: LoadMesh,
        bytes: []const u8,
    ) void {
        var data = asset_loader.parseObj(allocator, bytes) catch |err| {
            std.log.err("failed to parse mesh {s}: {t}\n", .{ mesh.path, err });
            return;
        };
        defer data.deinit(allocator);

        var event = RegisterMesh.fromOwnedAlloc(
            allocator,
            mesh.id,
            mesh.material,
            &data,
        ) catch {
            std.log.err("out of memory registering mesh {s}\n", .{mesh.path});
            return;
        };
        defer event.deinit(allocator);

        observers.trigger(event);
    }

    fn takeRequest(self: *AssetPlugin, path: []const u8) ?Request {
        for (self.requests.items, 0..) |request, index| {
            if (!std.mem.eql(u8, request.path(), path)) continue;
            return self.requests.swapRemove(index);
        }
        return null;
    }
};