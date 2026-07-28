const std = @import("std");

const ComponentRegistry = @import("component_registry.zig").ComponentRegistry;
const Entity = @import("domain.zig").Entity;

pub const EntityManager = struct {
    generations: std.ArrayList(u64) = std.ArrayList(u64).empty,
    alive: std.ArrayList(bool) = std.ArrayList(bool).empty,
    bitmasks: std.ArrayList(u64) = std.ArrayList(u64).empty,
    free_slots: std.ArrayList(usize) = std.ArrayList(usize).empty,

    pub fn init() EntityManager {
        return EntityManager{};
    }

    pub fn deinit(self: *EntityManager, alloc: std.mem.Allocator) void {
        self.generations.deinit(alloc);
        self.alive.deinit(alloc);
        self.bitmasks.deinit(alloc);
        self.free_slots.deinit(alloc);
    }

    pub fn createEntity(self: *EntityManager, alloc: std.mem.Allocator) !Entity {
        if (self.free_slots.pop()) |id| {
            self.alive.items[id] = true;
            self.bitmasks.items[id] = 0;
            return Entity{ .id = id, .generation = self.generations.items[id] };
        }

        const id = self.generations.items.len;
        try self.generations.append(alloc, 0);
        try self.alive.append(alloc, true);
        try self.bitmasks.append(alloc, 0);
        return Entity{ .id = id, .generation = 0 };
    }

    pub fn deleteEntity(self: *EntityManager, alloc: std.mem.Allocator, entity: Entity) !void {
        if (!self.isValidEntity(entity)) return;

        self.alive.items[entity.id] = false;
        self.generations.items[entity.id] += 1;
        self.bitmasks.items[entity.id] = 0;
        try self.free_slots.append(alloc, entity.id);
    }

    pub fn isValidEntity(self: *EntityManager, entity: Entity) bool {
        if (entity.id >= self.alive.items.len) return false;
        if (!self.alive.items[entity.id]) return false;
        if (self.generations.items[entity.id] != entity.generation) return false;
        return true;
    }

    pub fn getEntityIterator(_: *EntityManager) EntityIterator {
        return EntityIterator{};
    }

    pub fn getBitmaskForEntity(self: *EntityManager, entity: Entity) ?u64 {
        if (!self.isValidEntity(entity)) return null;
        return self.bitmasks.items[entity.id];
    }

    pub fn enableComponentForEntity(
        self: *EntityManager,
        component_registry: *ComponentRegistry,
        entity: Entity,
        comptime T: type,
    ) void {
        if (!self.isValidEntity(entity)) return;
        const index = component_registry.getComponentIndex(T) orelse return;
        self.bitmasks.items[entity.id] |= @as(u64, 1) << @intCast(index);
    }

    pub fn disableComponentForEntity(
        self: *EntityManager,
        component_registry: *ComponentRegistry,
        entity: Entity,
        comptime T: type,
    ) void {
        if (!self.isValidEntity(entity)) return;
        const index = component_registry.getComponentIndex(T) orelse return;
        self.bitmasks.items[entity.id] &= ~(@as(u64, 1) << @intCast(index));
    }
};

pub const EntityIterator = struct {
    index: usize = 0,
    bitmask: u64 = 0,

    pub fn next(self: *EntityIterator, manager: *EntityManager) ?Entity {
        while (self.index < manager.alive.items.len) {
            const id = self.index;
            self.index += 1;
            if (manager.alive.items[id] and manager.bitmasks.items[id] & self.bitmask == self.bitmask) {
                return Entity{ .id = id, .generation = manager.generations.items[id] };
            }
        }
        return null;
    }
};

test "enableComponentForEntity sets only the bit for the given type" {
    const Position = struct { x: f32, y: f32 };
    const Velocity = struct { dx: f32, dy: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Position);
    try registry.registerComponent(std.testing.allocator, Velocity);

    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    manager.enableComponentForEntity(&registry, a, Velocity);

    try std.testing.expectEqual(0b10, manager.bitmasks.items[a.id]);
}

test "disableComponentForEntity clears only the bit for the given type" {
    const Position = struct { x: f32, y: f32 };
    const Velocity = struct { dx: f32, dy: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Position);
    try registry.registerComponent(std.testing.allocator, Velocity);

    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    manager.enableComponentForEntity(&registry, a, Position);
    manager.enableComponentForEntity(&registry, a, Velocity);

    manager.disableComponentForEntity(&registry, a, Position);

    try std.testing.expectEqual(0b10, manager.bitmasks.items[a.id]);
}

test "enableComponentForEntity is a no-op when the component is already enabled" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Position);

    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    manager.enableComponentForEntity(&registry, a, Position);
    manager.enableComponentForEntity(&registry, a, Position);

    try std.testing.expectEqual(0b1, manager.bitmasks.items[a.id]);
}

test "disableComponentForEntity is a no-op when the component was never enabled" {
    const Position = struct { x: f32, y: f32 };
    const Velocity = struct { dx: f32, dy: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Position);
    try registry.registerComponent(std.testing.allocator, Velocity);

    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    manager.enableComponentForEntity(&registry, a, Position);

    manager.disableComponentForEntity(&registry, a, Velocity);

    try std.testing.expectEqual(0b1, manager.bitmasks.items[a.id]);
}

test "enableComponentForEntity is a no-op for an id that was never created" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Position);

    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    manager.enableComponentForEntity(&registry, Entity{ .id = 0, .generation = 0 }, Position);
}

test "enableComponentForEntity is a no-op for a stale generation handle" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Position);

    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    try manager.deleteEntity(std.testing.allocator, a);
    const b = try manager.createEntity(std.testing.allocator);

    manager.enableComponentForEntity(&registry, a, Position);

    try std.testing.expectEqual(0, manager.bitmasks.items[b.id]);
}

test "disableComponentForEntity is a no-op for an id that was never created" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Position);

    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    manager.disableComponentForEntity(&registry, Entity{ .id = 0, .generation = 0 }, Position);
}

test "disableComponentForEntity is a no-op for a stale generation handle" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Position);

    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    try manager.deleteEntity(std.testing.allocator, a);
    const b = try manager.createEntity(std.testing.allocator);
    manager.enableComponentForEntity(&registry, b, Position);

    manager.disableComponentForEntity(&registry, a, Position);

    try std.testing.expectEqual(0b1, manager.bitmasks.items[b.id]);
}

test "enableComponentForEntity is a no-op when the component type was never registered" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);

    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    manager.enableComponentForEntity(&registry, a, Position);

    try std.testing.expectEqual(0, manager.bitmasks.items[a.id]);
}

test "disableComponentForEntity is a no-op when the component type was never registered" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);

    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    manager.disableComponentForEntity(&registry, a, Position);

    try std.testing.expectEqual(0, manager.bitmasks.items[a.id]);
}

test "createEntity assigns sequential ids at generation 0" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    const b = try manager.createEntity(std.testing.allocator);

    try std.testing.expectEqual(0, a.id);
    try std.testing.expectEqual(0, a.generation);
    try std.testing.expectEqual(1, b.id);
    try std.testing.expectEqual(0, b.generation);
}

test "getBitmaskForEntity returns the current bitmask for an alive entity" {
    const Position = struct { x: f32, y: f32 };
    const Velocity = struct { dx: f32, dy: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Position);
    try registry.registerComponent(std.testing.allocator, Velocity);

    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    manager.enableComponentForEntity(&registry, a, Position);
    manager.enableComponentForEntity(&registry, a, Velocity);

    try std.testing.expectEqual(0b11, manager.getBitmaskForEntity(a));
}

test "getBitmaskForEntity returns null for an id that was never created" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    try std.testing.expectEqual(null, manager.getBitmaskForEntity(Entity{ .id = 0, .generation = 0 }));
}

test "getBitmaskForEntity returns null for a deleted entity" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    try manager.deleteEntity(std.testing.allocator, a);

    try std.testing.expectEqual(null, manager.getBitmaskForEntity(a));
}

test "getBitmaskForEntity returns null for a stale generation handle" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    try manager.deleteEntity(std.testing.allocator, a);
    _ = try manager.createEntity(std.testing.allocator);

    try std.testing.expectEqual(null, manager.getBitmaskForEntity(a));
}

test "iterator yields every alive entity" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    const b = try manager.createEntity(std.testing.allocator);
    const c = try manager.createEntity(std.testing.allocator);

    var it = manager.getEntityIterator();
    try std.testing.expectEqual(a, it.next(&manager).?);
    try std.testing.expectEqual(b, it.next(&manager).?);
    try std.testing.expectEqual(c, it.next(&manager).?);
    try std.testing.expectEqual(null, it.next(&manager));
}

test "iterator skips deleted entities" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    const b = try manager.createEntity(std.testing.allocator);
    try manager.deleteEntity(std.testing.allocator, a);

    var it = manager.getEntityIterator();
    try std.testing.expectEqual(b, it.next(&manager).?);
    try std.testing.expectEqual(null, it.next(&manager));
}

test "iterator yields the current generation for a recycled slot" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    try manager.deleteEntity(std.testing.allocator, a);
    const b = try manager.createEntity(std.testing.allocator);

    var it = manager.getEntityIterator();
    const found = it.next(&manager).?;

    try std.testing.expectEqual(b.id, found.id);
    try std.testing.expectEqual(b.generation, found.generation);
    try std.testing.expect(found.generation != a.generation);
    try std.testing.expectEqual(null, it.next(&manager));
}

test "iterator returns null immediately when no entities exist" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    var it = manager.getEntityIterator();
    try std.testing.expectEqual(null, it.next(&manager));
}

test "iterator with a required mask yields only entities whose bitmask satisfies it" {
    const Position = struct { x: f32, y: f32 };
    const Velocity = struct { dx: f32, dy: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Position);
    try registry.registerComponent(std.testing.allocator, Velocity);

    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    manager.enableComponentForEntity(&registry, a, Position);
    manager.enableComponentForEntity(&registry, a, Velocity);

    const b = try manager.createEntity(std.testing.allocator);
    manager.enableComponentForEntity(&registry, b, Position);

    var it = manager.getEntityIterator();
    it.bitmask = registry.calculateBitmask(&.{ Position, Velocity }).?;

    try std.testing.expectEqual(a, it.next(&manager).?);
    try std.testing.expectEqual(null, it.next(&manager));
}

test "iterator with a required mask skips a deleted entity even if its old bitmask would have matched" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Position);

    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    manager.enableComponentForEntity(&registry, a, Position);
    try manager.deleteEntity(std.testing.allocator, a);

    var it = manager.getEntityIterator();
    it.bitmask = registry.calculateBitmask(&.{Position}).?;

    try std.testing.expectEqual(null, it.next(&manager));
}

test "isValidEntity returns true for a freshly created entity" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);

    try std.testing.expect(manager.isValidEntity(a));
}

test "isValidEntity returns false for an id that was never created" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    try std.testing.expect(!manager.isValidEntity(Entity{ .id = 0, .generation = 0 }));
}

test "isValidEntity returns false for a deleted entity" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    try manager.deleteEntity(std.testing.allocator, a);

    try std.testing.expect(!manager.isValidEntity(a));
}

test "isValidEntity returns false for a stale generation handle" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    try manager.deleteEntity(std.testing.allocator, a);
    _ = try manager.createEntity(std.testing.allocator);

    try std.testing.expect(!manager.isValidEntity(a));
}

test "deleteEntity frees the slot for reuse and bumps its generation" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    try manager.deleteEntity(std.testing.allocator, a);
    const b = try manager.createEntity(std.testing.allocator);

    try std.testing.expectEqual(a.id, b.id);
    try std.testing.expectEqual(a.generation + 1, b.generation);
}

test "deleteEntity clears the entity's bitmask" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    manager.bitmasks.items[a.id] = 0b101;

    try manager.deleteEntity(std.testing.allocator, a);

    try std.testing.expectEqual(0, manager.bitmasks.items[a.id]);
}

test "deleteEntity is a no-op for a stale generation handle" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    try manager.deleteEntity(std.testing.allocator, a);
    _ = try manager.createEntity(std.testing.allocator);

    try manager.deleteEntity(std.testing.allocator, a);

    try std.testing.expect(manager.alive.items[a.id]);
}

test "deleteEntity is a no-op when the entity is already dead" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    const a = try manager.createEntity(std.testing.allocator);
    try manager.deleteEntity(std.testing.allocator, a);
    try manager.deleteEntity(std.testing.allocator, a);

    try std.testing.expectEqual(1, manager.free_slots.items.len);
}

test "deleteEntity is a no-op for an id that was never created" {
    var manager = EntityManager.init();
    defer manager.deinit(std.testing.allocator);

    try manager.deleteEntity(std.testing.allocator, Entity{ .id = 0, .generation = 0 });
}
