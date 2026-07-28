const std = @import("std");
const World = @import("world.zig").World;

pub const SystemFunction = *const fn (*World) callconv(.c) void;

pub const SystemRegistry = struct {
    groups: std.AutoArrayHashMapUnmanaged(u64, std.ArrayList(SystemFunction)) = .{},

    pub fn init() SystemRegistry {
        return SystemRegistry{};
    }

    pub fn deinit(self: *SystemRegistry, alloc: std.mem.Allocator) void {
        for (self.groups.values()) |*group| group.deinit(alloc);
        self.groups.deinit(alloc);
    }

    pub fn registerSystem(
        self: *SystemRegistry,
        alloc: std.mem.Allocator,
        group: u64,
        function: SystemFunction,
    ) !void {
        const gop = try self.groups.getOrPut(alloc, group);
        if (!gop.found_existing) gop.value_ptr.* = .empty;
        try gop.value_ptr.append(alloc, function);
    }

    pub fn iterateSystems(_: *SystemRegistry) SystemIterator {
        return SystemIterator{};
    }
};

pub const SystemIterator = struct {
    group_index: usize = 0,
    system_index: usize = 0,

    pub fn next(self: *SystemIterator, registry: *SystemRegistry) ?SystemFunction {
        const groups = registry.groups.values();
        while (self.group_index < groups.len) {
            const group = groups[self.group_index];
            if (self.system_index < group.items.len) {
                const function = group.items[self.system_index];
                self.system_index += 1;
                return function;
            }
            self.group_index += 1;
            self.system_index = 0;
        }
        return null;
    }
};

test "registerSystem creates a group on first use" {
    const system = struct {
        fn call(_: *World) callconv(.c) void {}
    }.call;

    var registry = SystemRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try registry.registerSystem(std.testing.allocator, 1, system);

    try std.testing.expectEqual(1, registry.groups.count());
    try std.testing.expectEqual(1, registry.groups.get(1).?.items.len);
}

test "registerSystem appends to an existing group in call order" {
    const a = struct {
        fn call(_: *World) callconv(.c) void {}
    }.call;
    const b = struct {
        fn call(_: *World) callconv(.c) void {}
    }.call;

    var registry = SystemRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try registry.registerSystem(std.testing.allocator, 1, a);
    try registry.registerSystem(std.testing.allocator, 1, b);

    const group = registry.groups.get(1).?;
    try std.testing.expectEqual(2, group.items.len);
    try std.testing.expectEqual(a, group.items[0]);
    try std.testing.expectEqual(b, group.items[1]);
}

test "registerSystem preserves group order by first registration" {
    const a = struct {
        fn call(_: *World) callconv(.c) void {}
    }.call;
    const b = struct {
        fn call(_: *World) callconv(.c) void {}
    }.call;

    var registry = SystemRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try registry.registerSystem(std.testing.allocator, 2, a);
    try registry.registerSystem(std.testing.allocator, 1, b);
    try registry.registerSystem(std.testing.allocator, 2, b);

    const keys = registry.groups.keys();
    try std.testing.expectEqual(2, keys.len);
    try std.testing.expectEqual(2, keys[0]);
    try std.testing.expectEqual(1, keys[1]);
}

test "iterator yields systems group by group, in registration order" {
    const a = struct {
        fn call(_: *World) callconv(.c) void {}
    }.call;
    const b = struct {
        fn call(_: *World) callconv(.c) void {}
    }.call;
    const c = struct {
        fn call(_: *World) callconv(.c) void {}
    }.call;

    var registry = SystemRegistry.init();
    defer registry.deinit(std.testing.allocator);

    try registry.registerSystem(std.testing.allocator, 2, a);
    try registry.registerSystem(std.testing.allocator, 1, b);
    try registry.registerSystem(std.testing.allocator, 2, c);

    var it = registry.iterateSystems();
    try std.testing.expectEqual(a, it.next(&registry).?);
    try std.testing.expectEqual(c, it.next(&registry).?);
    try std.testing.expectEqual(b, it.next(&registry).?);
    try std.testing.expectEqual(null, it.next(&registry));
}

test "iterator returns null immediately when nothing is registered" {
    var registry = SystemRegistry.init();
    defer registry.deinit(std.testing.allocator);

    var it = registry.iterateSystems();
    try std.testing.expectEqual(null, it.next(&registry));
}
