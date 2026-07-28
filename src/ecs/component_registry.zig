const std = @import("std");

pub const ComponentRegistry = struct {
    count: u64 = 0,
    ids: std.AutoHashMapUnmanaged(u64, u64) = std.AutoHashMapUnmanaged(u64, u64){},

    pub fn init() ComponentRegistry {
        return ComponentRegistry{};
    }

    pub fn deinit(self: *ComponentRegistry, alloc: std.mem.Allocator) void {
        self.ids.deinit(alloc);
    }

    pub fn registerComponent(
        self: *ComponentRegistry,
        alloc: std.mem.Allocator,
        comptime T: type,
    ) !void {
        const hash = std.hash.Wyhash.hash(0, @typeName(T));
        if (self.ids.contains(hash)) return;
        try self.ids.put(alloc, hash, self.count);
        self.count += 1;
    }

    pub fn getComponentIndex(self: *ComponentRegistry, comptime T: type) ?u64 {
        return self.ids.get(std.hash.Wyhash.hash(0, @typeName(T)));
    }

    pub fn calculateBitmask(self: *ComponentRegistry, comptime types: []const type) ?u64 {
        var mask: u64 = 0;
        inline for (types) |T| {
            const index = self.getComponentIndex(T) orelse return null;
            mask |= @as(u64, 1) << @intCast(index);
        }
        return mask;
    }
};

test "registerComponent assigns sequential indices" {
    const Position = struct { x: f32, y: f32 };
    const Velocity = struct { dx: f32, dy: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try registry.registerComponent(std.testing.allocator, Position);
    try registry.registerComponent(std.testing.allocator, Velocity);

    try std.testing.expectEqual(2, registry.count);
    try std.testing.expectEqual(0, registry.getComponentIndex(Position));
    try std.testing.expectEqual(1, registry.getComponentIndex(Velocity));
}

test "getComponentIndex returns null for unregistered component" {
    const Position = struct { x: f32, y: f32 };
    const Tag = struct {};

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try registry.registerComponent(std.testing.allocator, Position);

    try std.testing.expectEqual(null, registry.getComponentIndex(Tag));
}

test "registerComponent is a no-op when called again for the same type" {
    const Position = struct { x: f32, y: f32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try registry.registerComponent(std.testing.allocator, Position);
    try registry.registerComponent(std.testing.allocator, Position);

    try std.testing.expectEqual(1, registry.count);
    try std.testing.expectEqual(0, registry.getComponentIndex(Position));
}

test "calculateBitmask combines bits for the given types" {
    const Position = struct { x: f32, y: f32 };
    const Velocity = struct { dx: f32, dy: f32 };
    const Health = struct { hp: u32 };

    var registry = ComponentRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try registry.registerComponent(std.testing.allocator, Position);
    try registry.registerComponent(std.testing.allocator, Velocity);
    try registry.registerComponent(std.testing.allocator, Health);

    const mask = registry.calculateBitmask(&.{ Position, Health });

    try std.testing.expectEqual(0b101, mask.?);
}
