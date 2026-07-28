const std = @import("std");
const ComponentRegistry = @import("component_registry.zig").ComponentRegistry;
const ComponentStorage = @import("component_storage.zig").ComponentStorage;
const Entity = @import("domain.zig").Entity;
const EntityManager = @import("entity_manager.zig").EntityManager;
const EntityIterator = @import("entity_manager.zig").EntityIterator;
const SystemRegistry = @import("system_registry.zig").SystemRegistry;
const SystemFunction = @import("system_registry.zig").SystemFunction;
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
        function: SystemFunction,
    ) !void {
        const hash = std.hash.Wyhash.hash(0, group);
        try self.system_registry.registerSystem(alloc, hash, function);
    }

    pub fn iterateSystems(self: *World) SystemIterator {
        return self.system_registry.iterateSystems();
    }

    pub fn addPlugin(self: *World, alloc: std.mem.Allocator, comptime T: type, value: T) !void {
        try self.plugin_registry.addPlugin(alloc, self, T, value);
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
    const system = struct {
        fn call(_: *World) callconv(.c) void {}
    }.call;

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    try world.addSystem(std.testing.allocator, "physics", system);

    var it = world.iterateSystems();
    try std.testing.expectEqual(system, it.next(&world.system_registry).?);
    try std.testing.expectEqual(null, it.next(&world.system_registry));
}

test "addSystem groups systems by the same group name in call order" {
    const a = struct {
        fn call(_: *World) callconv(.c) void {}
    }.call;
    const b = struct {
        fn call(_: *World) callconv(.c) void {}
    }.call;

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    try world.addSystem(std.testing.allocator, "physics", a);
    try world.addSystem(std.testing.allocator, "physics", b);

    var it = world.iterateSystems();
    try std.testing.expectEqual(a, it.next(&world.system_registry).?);
    try std.testing.expectEqual(b, it.next(&world.system_registry).?);
    try std.testing.expectEqual(null, it.next(&world.system_registry));
}

test "addPlugin runs the plugin's init immediately" {
    const Plugin = struct {
        started: *bool,

        pub fn init(self: *@This(), _: std.mem.Allocator, _: *World) !void {
            self.started.* = true;
        }
    };

    var started = false;

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    try world.addPlugin(std.testing.allocator, Plugin, .{ .started = &started });

    try std.testing.expect(started);
}

test "a plugin's init can register systems" {
    const system = struct {
        fn call(_: *World) callconv(.c) void {}
    }.call;

    const Plugin = struct {
        system: SystemFunction,

        pub fn init(self: *@This(), alloc: std.mem.Allocator, world: *World) !void {
            try world.addSystem(alloc, "update", self.system);
        }
    };

    var world = World.init();
    defer world.deinit(std.testing.allocator);

    try world.addPlugin(std.testing.allocator, Plugin, .{ .system = system });

    var it = world.iterateSystems();
    try std.testing.expectEqual(system, it.next(&world.system_registry).?);
    try std.testing.expectEqual(null, it.next(&world.system_registry));
}

test "deinit calls a plugin's deinit" {
    const Plugin = struct {
        calls: *usize,

        pub fn init(_: *@This(), _: std.mem.Allocator, _: *World) !void {}

        pub fn deinit(self: *@This(), _: std.mem.Allocator) void {
            self.calls.* += 1;
        }
    };

    var calls: usize = 0;

    var world = World.init();
    try world.addPlugin(std.testing.allocator, Plugin, .{ .calls = &calls });
    world.deinit(std.testing.allocator);

    try std.testing.expectEqual(1, calls);
}

test "deinit calls a plugin's deinit that takes no allocator" {
    const Plugin = struct {
        calls: *usize,

        pub fn init(_: *@This(), _: std.mem.Allocator, _: *World) !void {}

        pub fn deinit(self: *@This()) void {
            self.calls.* += 1;
        }
    };

    var calls: usize = 0;

    var world = World.init();
    try world.addPlugin(std.testing.allocator, Plugin, .{ .calls = &calls });
    world.deinit(std.testing.allocator);

    try std.testing.expectEqual(1, calls);
}

test "deinit tears down every registered plugin" {
    const Plugin = struct {
        calls: *usize,

        pub fn init(_: *@This(), _: std.mem.Allocator, _: *World) !void {}

        pub fn deinit(self: *@This(), _: std.mem.Allocator) void {
            self.calls.* += 1;
        }
    };

    var calls: usize = 0;

    var world = World.init();
    try world.addPlugin(std.testing.allocator, Plugin, .{ .calls = &calls });
    try world.addPlugin(std.testing.allocator, Plugin, .{ .calls = &calls });
    world.deinit(std.testing.allocator);

    try std.testing.expectEqual(2, calls);
}
