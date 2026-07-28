const std = @import("std");

const World = @import("world.zig").World;

const DeinitFunction = *const fn (*anyopaque, std.mem.Allocator) void;

const PluginEntry = struct {
    state: *anyopaque,
    deinit: DeinitFunction,
};

pub const PluginRegistry = struct {
    plugins: std.ArrayList(PluginEntry) = .empty,

    pub fn init() PluginRegistry {
        return PluginRegistry{};
    }

    pub fn deinit(self: *PluginRegistry, alloc: std.mem.Allocator) void {
        for (self.plugins.items) |entry| entry.deinit(entry.state, alloc);
        self.plugins.deinit(alloc);
    }

    pub fn addPlugin(
        self: *PluginRegistry,
        alloc: std.mem.Allocator,
        world: *World,
        comptime T: type,
        value: T,
    ) !void {
        const instance = try alloc.create(T);
        errdefer alloc.destroy(instance);

        instance.* = value;
        try instance.init(alloc, world);
        errdefer deinitIfPresent(T, instance, alloc);

        try self.plugins.append(alloc, .{
            .state = instance,
            .deinit = getDeinitFunction(T),
        });
    }
};

fn deinitIfPresent(comptime T: type, instance: *T, alloc: std.mem.Allocator) void {
    if (!@hasDecl(T, "deinit")) return;
    const params = @typeInfo(@TypeOf(T.deinit)).@"fn".params;
    switch (params.len) {
        1 => instance.deinit(),
        2 => instance.deinit(alloc),
        else => @compileError(@typeName(T) ++ ".deinit has an unsupported signature"),
    }
}

fn getDeinitFunction(comptime T: type) DeinitFunction {
    return struct {
        fn deinitFunction(ptr: *anyopaque, alloc: std.mem.Allocator) void {
            const instance: *T = @ptrCast(@alignCast(ptr));
            deinitIfPresent(T, instance, alloc);
            alloc.destroy(instance);
        }
    }.deinitFunction;
}

test "addPlugin runs the plugin's init immediately and stores it" {
    const Plugin = struct {
        started: *bool,

        pub fn init(self: *@This(), _: std.mem.Allocator, _: *World) !void {
            self.started.* = true;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var registry = PluginRegistry.init();
    defer registry.deinit(std.testing.allocator);

    var started = false;
    try registry.addPlugin(std.testing.allocator, &world, Plugin, .{ .started = &started });

    try std.testing.expect(started);
    try std.testing.expectEqual(1, registry.plugins.items.len);
}

test "a plugin's init receives the world it was added to" {
    const Plugin = struct {
        seen: **World,

        pub fn init(self: *@This(), _: std.mem.Allocator, world: *World) !void {
            self.seen.* = world;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var registry = PluginRegistry.init();
    defer registry.deinit(std.testing.allocator);

    var seen: *World = undefined;
    try registry.addPlugin(std.testing.allocator, &world, Plugin, .{ .seen = &seen });

    try std.testing.expectEqual(&world, seen);
}

test "deinit calls each plugin's deinit" {
    const Plugin = struct {
        calls: *usize,

        pub fn init(_: *@This(), _: std.mem.Allocator, _: *World) !void {}

        pub fn deinit(self: *@This(), _: std.mem.Allocator) void {
            self.calls.* += 1;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var registry = PluginRegistry.init();

    var calls: usize = 0;
    try registry.addPlugin(std.testing.allocator, &world, Plugin, .{ .calls = &calls });
    try registry.addPlugin(std.testing.allocator, &world, Plugin, .{ .calls = &calls });
    registry.deinit(std.testing.allocator);

    try std.testing.expectEqual(2, calls);
}

test "deinit supports a plugin deinit that takes no allocator" {
    const Plugin = struct {
        calls: *usize,

        pub fn init(_: *@This(), _: std.mem.Allocator, _: *World) !void {}

        pub fn deinit(self: *@This()) void {
            self.calls.* += 1;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var registry = PluginRegistry.init();

    var calls: usize = 0;
    try registry.addPlugin(std.testing.allocator, &world, Plugin, .{ .calls = &calls });
    registry.deinit(std.testing.allocator);

    try std.testing.expectEqual(1, calls);
}

test "a plugin without a deinit is added and freed without error" {
    const Plugin = struct {
        pub fn init(_: *@This(), _: std.mem.Allocator, _: *World) !void {}
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var registry = PluginRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try registry.addPlugin(std.testing.allocator, &world, Plugin, .{});

    try std.testing.expectEqual(1, registry.plugins.items.len);
}

test "addPlugin propagates an init error and stores nothing" {
    const Plugin = struct {
        pub fn init(_: *@This(), _: std.mem.Allocator, _: *World) !void {
            return error.Boom;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var registry = PluginRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try std.testing.expectError(
        error.Boom,
        registry.addPlugin(std.testing.allocator, &world, Plugin, .{}),
    );

    try std.testing.expectEqual(0, registry.plugins.items.len);
}

test "a failed init does not trigger the plugin's deinit" {
    const Plugin = struct {
        deinit_calls: *usize,

        pub fn init(_: *@This(), _: std.mem.Allocator, _: *World) !void {
            return error.Boom;
        }

        pub fn deinit(self: *@This(), _: std.mem.Allocator) void {
            self.deinit_calls.* += 1;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var registry = PluginRegistry.init();
    defer registry.deinit(std.testing.allocator);

    var deinit_calls: usize = 0;
    try std.testing.expectError(
        error.Boom,
        registry.addPlugin(std.testing.allocator, &world, Plugin, .{ .deinit_calls = &deinit_calls }),
    );

    try std.testing.expectEqual(0, deinit_calls);
}
