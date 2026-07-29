const std = @import("std");

const World = @import("world.zig").World;

const DeinitFunction = *const fn (*anyopaque, std.mem.Allocator) void;

const PluginEntry = struct {
    plugin: *anyopaque,
    deinit: DeinitFunction,
};

pub const PluginRegistry = struct {
    plugins: std.ArrayList(PluginEntry) = .empty,

    pub fn init() PluginRegistry {
        return PluginRegistry{};
    }

    pub fn deinit(self: *PluginRegistry, alloc: std.mem.Allocator) void {
        for (self.plugins.items) |entry| entry.deinit(entry.plugin, alloc);
        self.plugins.deinit(alloc);
    }

    pub fn addPlugin(
        self: *PluginRegistry,
        alloc: std.mem.Allocator,
        world: *World,
        comptime T: type,
    ) !void {
        const plugin = try alloc.create(T);
        {
            errdefer alloc.destroy(plugin);

            if (@hasDecl(T, "init")) {
                const params = @typeInfo(@TypeOf(T.init)).@"fn".params;
                plugin.* = switch (params.len) {
                    0 => try T.init(),
                    1 => try T.init(alloc),
                    else => @compileError(@typeName(T) ++ ".init has an unsupported signature"),
                };
            } else {
                plugin.* = .{};
            }
            errdefer deinitIfPresent(T, plugin, alloc);

            try self.plugins.append(alloc, .{
                .plugin = plugin,
                .deinit = getDeinitFunction(T),
            });
        }

        if (!@hasDecl(T, "build")) {
            @compileError(@typeName(T) ++ " must declare build");
        }
        try plugin.build(alloc, world);
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
    const State = struct {
        var initialized: bool = false;
    };
    const Plugin = struct {
        pub fn init() !@This() {
            State.initialized = true;
            return .{};
        }

        pub fn build(_: *@This(), _: std.mem.Allocator, _: *World) !void {}
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var registry = PluginRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try registry.addPlugin(std.testing.allocator, &world, Plugin);

    try std.testing.expect(State.initialized);
    try std.testing.expectEqual(1, registry.plugins.items.len);
}

test "a plugin's build receives the initialized plugin and world" {
    const State = struct {
        var seen: ?*World = null;
    };
    const Plugin = struct {
        initialized: bool,

        pub fn init(_: std.mem.Allocator) !@This() {
            return .{ .initialized = true };
        }

        pub fn build(self: *@This(), _: std.mem.Allocator, world: *World) !void {
            try std.testing.expect(self.initialized);
            State.seen = world;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var registry = PluginRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try registry.addPlugin(std.testing.allocator, &world, Plugin);

    try std.testing.expectEqual(&world, State.seen.?);
}

test "a plugin can allocate state in init and free it in deinit" {
    const Plugin = struct {
        buffer: []u8,

        pub fn init(alloc: std.mem.Allocator) !@This() {
            return .{ .buffer = try alloc.alloc(u8, 8) };
        }

        pub fn build(_: *@This(), _: std.mem.Allocator, _: *World) !void {}

        pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
            alloc.free(self.buffer);
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var registry = PluginRegistry.init();
    try registry.addPlugin(std.testing.allocator, &world, Plugin);
    registry.deinit(std.testing.allocator);
}

test "deinit calls each plugin's deinit" {
    const State = struct {
        var count: usize = 0;
    };
    const PluginA = struct {
        pub fn init(_: std.mem.Allocator) !@This() {
            return .{};
        }

        pub fn build(_: *@This(), _: std.mem.Allocator, _: *World) !void {}

        pub fn deinit(_: *@This(), _: std.mem.Allocator) void {
            State.count += 1;
        }
    };
    const PluginB = struct {
        pub fn init(_: std.mem.Allocator) !@This() {
            return .{};
        }

        pub fn build(_: *@This(), _: std.mem.Allocator, _: *World) !void {}

        pub fn deinit(_: *@This(), _: std.mem.Allocator) void {
            State.count += 1;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var registry = PluginRegistry.init();

    try registry.addPlugin(std.testing.allocator, &world, PluginA);
    try registry.addPlugin(std.testing.allocator, &world, PluginB);
    registry.deinit(std.testing.allocator);

    try std.testing.expectEqual(2, State.count);
}

test "the same plugin type can currently be added more than once" {
    const State = struct {
        var init_count: usize = 0;
    };
    const Plugin = struct {
        pub fn init(_: std.mem.Allocator) !@This() {
            State.init_count += 1;
            return .{};
        }

        pub fn build(_: *@This(), _: std.mem.Allocator, _: *World) !void {}
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);
    var registry = PluginRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try registry.addPlugin(std.testing.allocator, &world, Plugin);
    try registry.addPlugin(std.testing.allocator, &world, Plugin);
    try std.testing.expectEqual(2, State.init_count);
    try std.testing.expectEqual(2, registry.plugins.items.len);
}

test "deinit supports a plugin deinit that takes no allocator" {
    const State = struct {
        var count: usize = 0;
    };
    const Plugin = struct {
        pub fn init(_: std.mem.Allocator) !@This() {
            return .{};
        }

        pub fn build(_: *@This(), _: std.mem.Allocator, _: *World) !void {}

        pub fn deinit(_: *@This()) void {
            State.count += 1;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var registry = PluginRegistry.init();

    try registry.addPlugin(std.testing.allocator, &world, Plugin);
    registry.deinit(std.testing.allocator);

    try std.testing.expectEqual(1, State.count);
}

test "a plugin without a deinit is added and freed without error" {
    const Plugin = struct {
        pub fn build(_: *@This(), _: std.mem.Allocator, _: *World) !void {}
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var registry = PluginRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try registry.addPlugin(std.testing.allocator, &world, Plugin);

    try std.testing.expectEqual(1, registry.plugins.items.len);
}

test "addPlugin propagates an init error and stores nothing" {
    const Plugin = struct {
        pub fn init(_: std.mem.Allocator) !@This() {
            return error.Boom;
        }

        pub fn build(_: *@This(), _: std.mem.Allocator, _: *World) !void {}
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var registry = PluginRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try std.testing.expectError(
        error.Boom,
        registry.addPlugin(std.testing.allocator, &world, Plugin),
    );

    try std.testing.expectEqual(0, registry.plugins.items.len);
}

test "a failed init does not trigger the plugin's deinit" {
    const State = struct {
        var deinit_count: usize = 0;
    };
    const Plugin = struct {
        pub fn init(_: std.mem.Allocator) !@This() {
            return error.Boom;
        }

        pub fn build(_: *@This(), _: std.mem.Allocator, _: *World) !void {}

        pub fn deinit(_: *@This(), _: std.mem.Allocator) void {
            State.deinit_count += 1;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var registry = PluginRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try std.testing.expectError(
        error.Boom,
        registry.addPlugin(std.testing.allocator, &world, Plugin),
    );

    try std.testing.expectEqual(0, State.deinit_count);
}

test "a plugin remains stored when its build fails" {
    const Plugin = struct {
        pub fn init(_: std.mem.Allocator) !@This() {
            return .{};
        }

        pub fn build(_: *@This(), _: std.mem.Allocator, _: *World) !void {
            return error.Boom;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);
    var registry = PluginRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try std.testing.expectError(
        error.Boom,
        registry.addPlugin(std.testing.allocator, &world, Plugin),
    );
    try std.testing.expectEqual(1, registry.plugins.items.len);
}
