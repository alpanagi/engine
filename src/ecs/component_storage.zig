const std = @import("std");

const ComponentRegistry = @import("component_registry.zig").ComponentRegistry;
const Entity = @import("domain.zig").Entity;

const DeinitFunction = *const fn (*std.ArrayList(u8), std.mem.Allocator) void;

pub const ComponentStorage = struct {
    buffers: [64]std.ArrayList(u8) = [_]std.ArrayList(u8){std.ArrayList(u8).empty} ** 64,
    deinit_functions: [64]?DeinitFunction = [_]?DeinitFunction{null} ** 64,

    pub fn init() ComponentStorage {
        return ComponentStorage{};
    }

    pub fn deinit(self: *ComponentStorage, alloc: std.mem.Allocator) void {
        for (&self.buffers, self.deinit_functions) |*buffer, entry| {
            if (entry) |deinit_function| deinit_function(buffer, alloc);
            buffer.deinit(alloc);
        }
    }

    pub fn addComponent(
        self: *ComponentStorage,
        component_registry: *ComponentRegistry,
        alloc: std.mem.Allocator,
        entity: Entity,
        comptime T: type,
        value: T,
    ) !void {
        if (@sizeOf(T) == 0) @compileError(@typeName(T) ++ " is zero-sized; use EntityManager's bitmask instead of ComponentStorage");

        try component_registry.registerComponent(alloc, T);
        const index = component_registry.getComponentIndex(T).?;
        self.deinit_functions[@intCast(index)] = getDeinitFunction(T);

        const buffer = &self.buffers[@intCast(index)];
        const entity_offset = entity.id * @sizeOf(?T);
        const required_buffer_size = entity_offset + @sizeOf(?T);

        if (buffer.items.len < required_buffer_size) {
            const previous_size = buffer.items.len;
            try buffer.resize(alloc, required_buffer_size);
            @memset(buffer.items[previous_size..required_buffer_size], 0);
        }

        const slot: *align(1) ?T = @ptrCast(buffer.items[entity_offset..][0..@sizeOf(?T)].ptr);
        deinitIfPresent(alloc, T, slot.*);
        slot.* = value;
    }

    pub fn getComponent(
        self: *ComponentStorage,
        component_registry: *ComponentRegistry,
        entity: Entity,
        comptime T: type,
    ) ?*align(1) T {
        if (@sizeOf(T) == 0) @compileError(@typeName(T) ++ " is zero-sized; use EntityManager's bitmask instead of ComponentStorage");

        const index = component_registry.getComponentIndex(T) orelse return null;
        const buffer = &self.buffers[@intCast(index)];
        const entity_offset = entity.id * @sizeOf(?T);
        if (entity_offset + @sizeOf(?T) > buffer.items.len) return null;

        const slot: *align(1) ?T = @ptrCast(buffer.items[entity_offset..][0..@sizeOf(?T)].ptr);
        if (slot.* == null) return null;
        return &slot.*.?;
    }

    pub fn removeComponent(
        self: *ComponentStorage,
        component_registry: *ComponentRegistry,
        alloc: std.mem.Allocator,
        entity: Entity,
        comptime T: type,
    ) void {
        if (@sizeOf(T) == 0) @compileError(@typeName(T) ++ " is zero-sized; use EntityManager's bitmask instead of ComponentStorage");

        const index = component_registry.getComponentIndex(T) orelse return;
        const buffer = &self.buffers[@intCast(index)];
        const entity_offset = entity.id * @sizeOf(?T);
        if (entity_offset + @sizeOf(?T) > buffer.items.len) return;

        const slot: *align(1) ?T = @ptrCast(buffer.items[entity_offset..][0..@sizeOf(?T)].ptr);
        deinitIfPresent(alloc, T, slot.*);
        slot.* = null;
    }
};

fn deinitIfPresent(alloc: std.mem.Allocator, comptime T: type, value: ?T) void {
    var value_copy = value;
    if (value_copy) |*value_ptr| {
        if (@hasDecl(T, "deinit")) {
            const params = @typeInfo(@TypeOf(T.deinit)).@"fn".params;
            switch (params.len) {
                1 => value_ptr.deinit(),
                2 => value_ptr.deinit(alloc),
                else => @compileError(@typeName(T) ++ ".deinit has an unsupported signature"),
            }
        }
    }
}

fn getDeinitFunction(comptime T: type) DeinitFunction {
    return struct {
        fn deinitFunction(buffer: *std.ArrayList(u8), alloc: std.mem.Allocator) void {
            var offset: usize = 0;
            while (offset + @sizeOf(?T) <= buffer.items.len) : (offset += @sizeOf(?T)) {
                const slot: *align(1) ?T = @ptrCast(buffer.items[offset..][0..@sizeOf(?T)].ptr);
                deinitIfPresent(alloc, T, slot.*);
            }
        }
    }.deinitFunction;
}

test "addComponent then getComponent returns the stored value" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Position);

    var storage = ComponentStorage.init();
    defer storage.deinit(std.testing.allocator);

    const entity = Entity{ .id = 3, .generation = 0 };
    try storage.addComponent(
        &registry,
        std.testing.allocator,
        entity,
        Position,
        .{ .x = 1, .y = 2 },
    );

    const got = storage.getComponent(&registry, entity, Position).?;
    try std.testing.expectEqual(1, got.x);
    try std.testing.expectEqual(2, got.y);
}

test "addComponent registers the type when it wasn't registered yet" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);

    var storage = ComponentStorage.init();
    defer storage.deinit(std.testing.allocator);

    const entity = Entity{ .id = 0, .generation = 0 };
    try storage.addComponent(&registry, std.testing.allocator, entity, Position, .{ .x = 1, .y = 2 });

    try std.testing.expectEqual(0, registry.getComponentIndex(Position));
}

test "getComponent returns null when the component was never added for that entity" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Position);

    var storage = ComponentStorage.init();
    defer storage.deinit(std.testing.allocator);

    const entity = Entity{ .id = 0, .generation = 0 };
    try std.testing.expectEqual(null, storage.getComponent(&registry, entity, Position));
}

test "getComponent returns null when the component type was never registered" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);

    var storage = ComponentStorage.init();
    defer storage.deinit(std.testing.allocator);

    const entity = Entity{ .id = 0, .generation = 0 };
    try std.testing.expectEqual(null, storage.getComponent(&registry, entity, Position));
}

test "removeComponent is a no-op when the component type was never registered" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);

    var storage = ComponentStorage.init();
    defer storage.deinit(std.testing.allocator);

    const entity = Entity{ .id = 0, .generation = 0 };
    storage.removeComponent(&registry, std.testing.allocator, entity, Position);
}

test "removeComponent clears the value even for a type without deinit" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Position);

    var storage = ComponentStorage.init();
    defer storage.deinit(std.testing.allocator);

    const entity = Entity{ .id = 0, .generation = 0 };
    try storage.addComponent(&registry, std.testing.allocator, entity, Position, .{ .x = 1, .y = 2 });
    storage.removeComponent(&registry, std.testing.allocator, entity, Position);

    try std.testing.expectEqual(null, storage.getComponent(&registry, entity, Position));
}

test "removeComponent is a no-op for an entity that never had the component" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Position);

    var storage = ComponentStorage.init();
    defer storage.deinit(std.testing.allocator);

    const entity = Entity{ .id = 0, .generation = 0 };
    storage.removeComponent(&registry, std.testing.allocator, entity, Position);

    try std.testing.expectEqual(null, storage.getComponent(&registry, entity, Position));
}

test "removeComponent calls a no-argument deinit" {
    var deinit_calls: usize = 0;
    const Tracked = struct {
        calls: *usize,

        pub fn deinit(self: *@This()) void {
            self.calls.* += 1;
        }
    };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Tracked);

    var storage = ComponentStorage.init();
    defer storage.deinit(std.testing.allocator);

    const entity = Entity{ .id = 0, .generation = 0 };
    try storage.addComponent(&registry, std.testing.allocator, entity, Tracked, .{ .calls = &deinit_calls });
    storage.removeComponent(&registry, std.testing.allocator, entity, Tracked);

    try std.testing.expectEqual(1, deinit_calls);
}

test "removeComponent calls an allocator-taking deinit and frees its allocation" {
    const Tracked = struct {
        data: []u8,

        pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
            alloc.free(self.data);
        }
    };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Tracked);

    var storage = ComponentStorage.init();
    defer storage.deinit(std.testing.allocator);

    const entity = Entity{ .id = 0, .generation = 0 };
    const data = try std.testing.allocator.alloc(u8, 4);
    try storage.addComponent(&registry, std.testing.allocator, entity, Tracked, .{ .data = data });
    storage.removeComponent(&registry, std.testing.allocator, entity, Tracked);
}

test "deinit frees a component's allocation that was never explicitly removed" {
    const Tracked = struct {
        data: []u8,

        pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
            alloc.free(self.data);
        }
    };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Tracked);

    var storage = ComponentStorage.init();

    const entity = Entity{ .id = 0, .generation = 0 };
    const data = try std.testing.allocator.alloc(u8, 4);
    try storage.addComponent(&registry, std.testing.allocator, entity, Tracked, .{ .data = data });

    storage.deinit(std.testing.allocator);
}

test "addComponent over an existing value calls deinit on the previous one without an explicit remove" {
    var deinit_calls: usize = 0;
    const Tracked = struct {
        calls: *usize,

        pub fn deinit(self: *@This()) void {
            self.calls.* += 1;
        }
    };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Tracked);

    var storage = ComponentStorage.init();
    defer storage.deinit(std.testing.allocator);

    const entity = Entity{ .id = 0, .generation = 0 };
    try storage.addComponent(&registry, std.testing.allocator, entity, Tracked, .{ .calls = &deinit_calls });
    try storage.addComponent(&registry, std.testing.allocator, entity, Tracked, .{ .calls = &deinit_calls });

    try std.testing.expectEqual(1, deinit_calls);
}

test "addComponent after removeComponent stores a fresh value" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Position);

    var storage = ComponentStorage.init();
    defer storage.deinit(std.testing.allocator);

    const entity = Entity{ .id = 0, .generation = 0 };
    try storage.addComponent(&registry, std.testing.allocator, entity, Position, .{ .x = 1, .y = 2 });
    storage.removeComponent(&registry, std.testing.allocator, entity, Position);
    try storage.addComponent(&registry, std.testing.allocator, entity, Position, .{ .x = 9, .y = 9 });

    const got = storage.getComponent(&registry, entity, Position).?;
    try std.testing.expectEqual(9, got.x);
    try std.testing.expectEqual(9, got.y);
}

test "addComponent after removeComponent does not double-free the previous allocator-owned value" {
    const Tracked = struct {
        data: []u8,

        pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
            alloc.free(self.data);
        }
    };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);
    try registry.registerComponent(std.testing.allocator, Tracked);

    var storage = ComponentStorage.init();
    defer storage.deinit(std.testing.allocator);

    const entity = Entity{ .id = 0, .generation = 0 };
    const first_data = try std.testing.allocator.alloc(u8, 4);
    try storage.addComponent(&registry, std.testing.allocator, entity, Tracked, .{ .data = first_data });
    storage.removeComponent(&registry, std.testing.allocator, entity, Tracked);

    const second_data = try std.testing.allocator.alloc(u8, 8);
    try storage.addComponent(&registry, std.testing.allocator, entity, Tracked, .{ .data = second_data });

    const got = storage.getComponent(&registry, entity, Tracked).?;
    try std.testing.expectEqual(second_data.ptr, got.data.ptr);
    try std.testing.expectEqual(@as(usize, 8), got.data.len);

    storage.removeComponent(&registry, std.testing.allocator, entity, Tracked);
}
