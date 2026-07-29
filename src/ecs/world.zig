const std = @import("std");
const ComponentRegistry = @import("component_registry.zig").ComponentRegistry;
const ComponentStorage = @import("component_storage.zig").ComponentStorage;
const Entity = @import("domain.zig").Entity;
const EntityManager = @import("entity_manager.zig").EntityManager;
const EntityIterator = @import("entity_manager.zig").EntityIterator;
const SystemRegistry = @import("system_registry.zig").SystemRegistry;
const SystemEntry = @import("system_registry.zig").SystemEntry;
const SystemIterator = @import("system_registry.zig").SystemIterator;
const PluginRegistry = @import("plugin_registry.zig").PluginRegistry;

pub const World = struct {
    component_registry: ComponentRegistry,
    entity_manager: EntityManager,
    component_storage: ComponentStorage,
    system_registry: SystemRegistry,
    plugin_registry: PluginRegistry,

    pub fn init() World {
        return World{
            .component_registry = ComponentRegistry.init(),
            .entity_manager = EntityManager.init(),
            .component_storage = ComponentStorage.init(),
            .system_registry = SystemRegistry.init(),
            .plugin_registry = PluginRegistry.init(),
        };
    }

    pub fn deinit(self: *World, alloc: std.mem.Allocator) void {
        self.component_registry.deinit(alloc);
        self.entity_manager.deinit(alloc);
        self.component_storage.deinit(alloc);
        self.system_registry.deinit(alloc);
        self.plugin_registry.deinit(alloc);
    }

    pub fn createEntity(self: *World, alloc: std.mem.Allocator) !Entity {
        return self.entity_manager.createEntity(alloc);
    }

    pub fn deleteEntity(self: *World, alloc: std.mem.Allocator, entity: Entity) !void {
        try self.entity_manager.deleteEntity(alloc, entity);
    }

    fn hasComponent(self: *World, entity: Entity, comptime T: type) bool {
        const bitmask = self.entity_manager.getBitmaskForEntity(entity) orelse return false;
        const index = self.component_registry.getComponentIndex(T) orelse return false;
        return bitmask & (@as(u64, 1) << @intCast(index)) != 0;
    }

    pub fn addComponent(
        self: *World,
        alloc: std.mem.Allocator,
        entity: Entity,
        comptime T: type,
        value: T,
    ) !void {
        if (!self.entity_manager.isValidEntity(entity)) return;

        if (comptime @sizeOf(T) == 0) {
            try self.component_registry.registerComponent(alloc, T);
            self.entity_manager.enableComponentForEntity(&self.component_registry, entity, T);
            return;
        }

        try self.component_storage.addComponent(&self.component_registry, alloc, entity, T, value);
        self.entity_manager.enableComponentForEntity(&self.component_registry, entity, T);
    }

    pub fn getComponent(self: *World, entity: Entity, comptime T: type) ?*align(1) T {
        if (!self.hasComponent(entity, T)) return null;

        if (comptime @sizeOf(T) == 0) {
            return &(struct {
                var instance: T = undefined;
            }).instance;
        }

        return self.component_storage.getComponent(&self.component_registry, entity, T);
    }

    pub fn removeComponent(
        self: *World,
        alloc: std.mem.Allocator,
        entity: Entity,
        comptime T: type,
    ) void {
        if (!self.hasComponent(entity, T)) return;

        if (comptime @sizeOf(T) == 0) {
            self.entity_manager.disableComponentForEntity(&self.component_registry, entity, T);
            return;
        }

        self.component_storage.removeComponent(&self.component_registry, alloc, entity, T);
        self.entity_manager.disableComponentForEntity(&self.component_registry, entity, T);
    }

    pub fn query(self: *World, comptime types: []const type) EntityIterator {
        const bitmask = self.component_registry.calculateBitmask(types) orelse {
            return EntityIterator{ .index = std.math.maxInt(usize) };
        };
        return EntityIterator{ .bitmask = bitmask };
    }

    pub fn addSystem(
        self: *World,
        alloc: std.mem.Allocator,
        group: []const u8,
        comptime function: anytype,
        plugin: anytype,
    ) !void {
        const hash = std.hash.Wyhash.hash(0, group);
        try self.system_registry.registerSystem(alloc, hash, function, plugin);
    }

    pub fn iterateSystems(self: *World) SystemIterator {
        return self.system_registry.iterateSystems();
    }

    pub fn addPlugin(self: *World, alloc: std.mem.Allocator, comptime T: type) !void {
        try self.plugin_registry.addPlugin(alloc, self, T);
    }
};

test "addComponent then getComponent returns the stored value" {
    const Position = struct { x: f32, y: f32 };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    const entity = try world.createEntity(std.testing.allocator);
    try world.addComponent(std.testing.allocator, entity, Position, .{ .x = 1, .y = 2 });

    const got = world.getComponent(entity, Position).?;
    try std.testing.expectEqual(1, got.x);
    try std.testing.expectEqual(2, got.y);
}

test "addComponent registers the type without a separate call" {
    const Position = struct { x: f32, y: f32 };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    const entity = try world.createEntity(std.testing.allocator);
    try world.addComponent(std.testing.allocator, entity, Position, .{ .x = 1, .y = 2 });

    try std.testing.expectEqual(0, world.component_registry.getComponentIndex(Position));
}

test "addComponent sets the entity's bitmask bit" {
    const Position = struct { x: f32, y: f32 };
    const Velocity = struct { dx: f32, dy: f32 };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    const entity = try world.createEntity(std.testing.allocator);
    try world.addComponent(std.testing.allocator, entity, Position, .{ .x = 1, .y = 2 });
    try world.addComponent(std.testing.allocator, entity, Velocity, .{ .dx = 0, .dy = 0 });

    try std.testing.expectEqual(0b11, world.entity_manager.getBitmaskForEntity(entity));
}

test "addComponent is a no-op for an invalid entity" {
    const Position = struct { x: f32, y: f32 };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    try world.addComponent(
        std.testing.allocator,
        Entity{ .id = 0, .generation = 0 },
        Position,
        .{ .x = 1, .y = 2 },
    );

    try std.testing.expectEqual(0, world.component_registry.count);
}

test "addComponent over an existing component calls deinit on the old value" {
    var deinit_calls: usize = 0;
    const Tracked = struct {
        calls: *usize,

        pub fn deinit(self: *@This()) void {
            self.calls.* += 1;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    const entity = try world.createEntity(std.testing.allocator);
    try world.addComponent(std.testing.allocator, entity, Tracked, .{ .calls = &deinit_calls });
    try world.addComponent(std.testing.allocator, entity, Tracked, .{ .calls = &deinit_calls });

    try std.testing.expectEqual(1, deinit_calls);
}

test "addComponent to a recycled entity id frees the previous occupant's component" {
    var deinit_calls: usize = 0;
    const Tracked = struct {
        calls: *usize,

        pub fn deinit(self: *@This()) void {
            self.calls.* += 1;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    const a = try world.createEntity(std.testing.allocator);
    try world.addComponent(std.testing.allocator, a, Tracked, .{ .calls = &deinit_calls });
    try world.deleteEntity(std.testing.allocator, a);

    const b = try world.createEntity(std.testing.allocator);
    try world.addComponent(std.testing.allocator, b, Tracked, .{ .calls = &deinit_calls });

    try std.testing.expectEqual(1, deinit_calls);
}

test "getComponent returns null for an invalid entity" {
    const Position = struct { x: f32, y: f32 };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    try std.testing.expectEqual(null, world.getComponent(Entity{ .id = 0, .generation = 0 }, Position));
}

test "removeComponent clears the value and the bitmask bit" {
    const Position = struct { x: f32, y: f32 };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    const entity = try world.createEntity(std.testing.allocator);
    try world.addComponent(std.testing.allocator, entity, Position, .{ .x = 1, .y = 2 });
    world.removeComponent(std.testing.allocator, entity, Position);

    try std.testing.expectEqual(null, world.getComponent(entity, Position));
    try std.testing.expectEqual(0, world.entity_manager.getBitmaskForEntity(entity));
}

test "removeComponent is a no-op for an invalid entity" {
    const Position = struct { x: f32, y: f32 };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    world.removeComponent(std.testing.allocator, Entity{ .id = 0, .generation = 0 }, Position);
}

test "removeComponent called twice does not double-free" {
    var deinit_calls: usize = 0;
    const Tracked = struct {
        calls: *usize,

        pub fn deinit(self: *@This()) void {
            self.calls.* += 1;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    const entity = try world.createEntity(std.testing.allocator);
    try world.addComponent(std.testing.allocator, entity, Tracked, .{ .calls = &deinit_calls });

    world.removeComponent(std.testing.allocator, entity, Tracked);
    world.removeComponent(std.testing.allocator, entity, Tracked);

    try std.testing.expectEqual(1, deinit_calls);
}

test "addComponent, getComponent, and removeComponent work for a zero-sized tag type" {
    const IsDead = struct {};

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    const entity = try world.createEntity(std.testing.allocator);

    try std.testing.expectEqual(null, world.getComponent(entity, IsDead));

    try world.addComponent(std.testing.allocator, entity, IsDead, .{});
    try std.testing.expect(world.getComponent(entity, IsDead) != null);
    try std.testing.expectEqual(0b1, world.entity_manager.getBitmaskForEntity(entity));

    world.removeComponent(std.testing.allocator, entity, IsDead);
    try std.testing.expectEqual(null, world.getComponent(entity, IsDead));
    try std.testing.expectEqual(0, world.entity_manager.getBitmaskForEntity(entity));
}

test "query yields only entities with every requested component" {
    const Position = struct { x: f32, y: f32 };
    const Velocity = struct { dx: f32, dy: f32 };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    const a = try world.createEntity(std.testing.allocator);
    try world.addComponent(std.testing.allocator, a, Position, .{ .x = 1, .y = 2 });
    try world.addComponent(std.testing.allocator, a, Velocity, .{ .dx = 1, .dy = 1 });

    const b = try world.createEntity(std.testing.allocator);
    try world.addComponent(std.testing.allocator, b, Position, .{ .x = 3, .y = 4 });

    var q = world.query(&.{ Position, Velocity });

    try std.testing.expectEqual(a, q.next(&world.entity_manager).?);
    try std.testing.expectEqual(null, q.next(&world.entity_manager));
}

test "query yields nothing for a type that was never registered" {
    const Tag = struct { unused: bool = true };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var q = world.query(&.{Tag});

    try std.testing.expectEqual(null, q.next(&world.entity_manager));
}

test "query for an unregistered type stays empty even if entities are created afterward" {
    const Tag = struct { unused: bool = true };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    var q = world.query(&.{Tag});

    _ = try world.createEntity(std.testing.allocator);
    _ = try world.createEntity(std.testing.allocator);

    try std.testing.expectEqual(null, q.next(&world.entity_manager));
}

test "deleteEntity invalidates the entity" {
    var world = World.init();
    defer world.deinit(std.testing.allocator);

    const entity = try world.createEntity(std.testing.allocator);
    try world.deleteEntity(std.testing.allocator, entity);

    try std.testing.expect(!world.entity_manager.isValidEntity(entity));
}

test "addSystem then iterateSystems yields the system" {
    const State = struct {
        var called = false;
    };
    const system = struct {
        fn call(_: *World) callconv(.c) void {
            State.called = true;
        }
    }.call;

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    try world.addSystem(std.testing.allocator, "physics", system, null);

    var it = world.iterateSystems();
    it.next(&world.system_registry).?.run(&world);
    try std.testing.expect(State.called);
    try std.testing.expectEqual(null, it.next(&world.system_registry));
}

test "addSystem groups systems by the same group name in call order" {
    const State = struct {
        var calls: [2]u8 = undefined;
        var count: usize = 0;
    };
    const a = struct {
        fn call(_: *World) callconv(.c) void {
            State.calls[State.count] = 1;
            State.count += 1;
        }
    }.call;
    const b = struct {
        fn call(_: *World) callconv(.c) void {
            State.calls[State.count] = 2;
            State.count += 1;
        }
    }.call;

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    try world.addSystem(std.testing.allocator, "physics", a, null);
    try world.addSystem(std.testing.allocator, "physics", b, null);

    var it = world.iterateSystems();
    it.next(&world.system_registry).?.run(&world);
    it.next(&world.system_registry).?.run(&world);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2 }, &State.calls);
    try std.testing.expectEqual(null, it.next(&world.system_registry));
}

test "addPlugin runs the plugin's init immediately" {
    const State = struct {
        var initialized: bool = false;
    };
    const Plugin = struct {
        pub fn init(_: std.mem.Allocator) !@This() {
            State.initialized = true;
            return .{};
        }

        pub fn build(_: *@This(), _: std.mem.Allocator, _: *World) !void {}
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    try world.addPlugin(std.testing.allocator, Plugin);

    try std.testing.expect(State.initialized);
}

test "a plugin's build can register systems" {
    const Plugin = struct {
        calls: usize = 0,

        pub fn init(_: std.mem.Allocator) !@This() {
            return .{};
        }

        pub fn build(self: *@This(), alloc: std.mem.Allocator, world: *World) !void {
            try world.addSystem(alloc, "update", system, self);
        }

        fn system(self: *@This(), _: *World) void {
            self.calls += 1;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    try world.addPlugin(std.testing.allocator, Plugin);

    var it = world.iterateSystems();
    const entry: SystemEntry = it.next(&world.system_registry).?;
    entry.run(&world);
    const plugin_system = entry.plugin_function;
    const plugin: *Plugin = @ptrCast(@alignCast(plugin_system.plugin));
    try std.testing.expectEqual(1, plugin.calls);
    try std.testing.expectEqual(null, it.next(&world.system_registry));
}

test "deinit calls a plugin's deinit" {
    const State = struct {
        var count: usize = 0;
    };
    const Plugin = struct {
        pub fn init(_: std.mem.Allocator) !@This() {
            return .{};
        }

        pub fn build(_: *@This(), _: std.mem.Allocator, _: *World) !void {}

        pub fn deinit(_: *@This(), _: std.mem.Allocator) void {
            State.count += 1;
        }
    };

    var world = World.init();
    try world.addPlugin(std.testing.allocator, Plugin);
    world.deinit(std.testing.allocator);

    try std.testing.expectEqual(1, State.count);
}

test "plugin systems share state across runs" {
    const Plugin = struct {
        count: usize = 0,

        pub fn init(_: std.mem.Allocator) !@This() {
            return .{};
        }

        pub fn build(self: *@This(), alloc: std.mem.Allocator, world: *World) !void {
            try world.addSystem(alloc, "update", increment, self);
            try world.addSystem(alloc, "observe", increment, self);
        }

        fn increment(self: *@This(), _: *World) void {
            self.count += 1;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);
    try world.addPlugin(std.testing.allocator, Plugin);

    var first = world.iterateSystems();
    while (first.next(&world.system_registry)) |entry| entry.run(&world);
    var second = world.iterateSystems();
    while (second.next(&world.system_registry)) |entry| entry.run(&world);

    const first_entry = world.system_registry.groups.values()[0].items[0].plugin_function;
    const plugin: *Plugin = @ptrCast(@alignCast(first_entry.plugin));
    try std.testing.expectEqual(4, plugin.count);
    const second_entry = world.system_registry.groups.values()[1].items[0].plugin_function;
    try std.testing.expectEqual(first_entry.plugin, second_entry.plugin);
}

test "systems registered before a plugin build failure remain valid" {
    const Plugin = struct {
        calls: usize = 0,

        pub fn init(_: std.mem.Allocator) !@This() {
            return .{};
        }

        pub fn build(self: *@This(), alloc: std.mem.Allocator, world: *World) !void {
            try world.addSystem(alloc, "update", update, self);
            return error.Boom;
        }

        fn update(self: *@This(), _: *World) void {
            self.calls += 1;
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    try std.testing.expectError(
        error.Boom,
        world.addPlugin(std.testing.allocator, Plugin),
    );
    var iterator = world.iterateSystems();
    const entry = iterator.next(&world.system_registry).?;
    entry.run(&world);
    const plugin: *Plugin = @ptrCast(@alignCast(entry.plugin_function.plugin));
    try std.testing.expectEqual(1, plugin.calls);
}
