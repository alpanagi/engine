const std = @import("std");
const World = @import("world.zig").World;

pub const SystemFunction = *const fn (*World) callconv(.c) void;
pub const PluginSystemFunction = *const fn (*anyopaque, *World) callconv(.c) void;

pub const SystemEntry = union(enum) {
    function: SystemFunction,
    plugin_function: struct {
        plugin: *anyopaque,
        function: PluginSystemFunction,
    },

    pub fn run(self: SystemEntry, world: *World) void {
        switch (self) {
            .function => |function| function(world),
            .plugin_function => |system| system.function(system.plugin, world),
        }
    }
};

pub const SystemRegistry = struct {
    groups: std.AutoArrayHashMapUnmanaged(u64, std.ArrayList(SystemEntry)) = .{},

    pub fn init() SystemRegistry {
        return .{};
    }

    pub fn deinit(self: *SystemRegistry, alloc: std.mem.Allocator) void {
        for (self.groups.values()) |*group| group.deinit(alloc);
        self.groups.deinit(alloc);
    }

    pub fn registerSystem(
        self: *SystemRegistry,
        alloc: std.mem.Allocator,
        group: u64,
        comptime function: anytype,
        plugin: anytype,
    ) !void {
        var entry: SystemEntry = undefined;
        if (comptime @TypeOf(plugin) == @TypeOf(null)) {
            const info = functionInfo(@TypeOf(function));
            if (info.params.len != 1 or
                info.params[0].type.? != *World or
                info.return_type.? != void)
            {
                @compileError("a system without a plugin must have signature fn (*World) void");
            }
            const system_function: SystemFunction = function;
            entry = .{ .function = system_function };
        } else {
            const Plugin = pluginType(@TypeOf(plugin));
            validatePluginFunction(Plugin, @TypeOf(function));
            const typed_plugin: *Plugin = plugin;
            entry = .{ .plugin_function = .{
                .plugin = typed_plugin,
                .function = pluginInvoker(Plugin, function),
            } };
        }
        try self.appendEntry(alloc, group, entry);
    }

    fn appendEntry(
        self: *SystemRegistry,
        alloc: std.mem.Allocator,
        group: u64,
        entry: SystemEntry,
    ) !void {
        const gop = try self.groups.getOrPut(alloc, group);
        if (!gop.found_existing) gop.value_ptr.* = .empty;
        gop.value_ptr.append(alloc, entry) catch |err| {
            if (!gop.found_existing) {
                gop.value_ptr.deinit(alloc);
                std.debug.assert(self.groups.orderedRemove(group));
            }
            return err;
        };
    }

    pub fn iterateSystems(_: *SystemRegistry) SystemIterator {
        return .{};
    }
};

fn pluginType(comptime Pointer: type) type {
    const pointer = switch (@typeInfo(Pointer)) {
        .pointer => |info| info,
        else => @compileError("plugin must be a pointer"),
    };
    if (pointer.size != .one or pointer.is_const) {
        @compileError("plugin must be a mutable single-item pointer");
    }
    return pointer.child;
}

fn validatePluginFunction(comptime Plugin: type, comptime Function: type) void {
    const info = functionInfo(Function);
    if (info.params.len != 2 or
        info.params[0].type.? != *Plugin or
        info.params[1].type.? != *World or
        info.return_type.? != void)
    {
        @compileError("a plugin system must have signature fn (*Plugin, *World) void");
    }
}

fn functionInfo(comptime F: type) std.builtin.Type.Fn {
    return switch (@typeInfo(F)) {
        .@"fn" => |info| info,
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => |info| info,
            else => @compileError("system must be a function"),
        },
        else => @compileError("system must be a function"),
    };
}

fn pluginInvoker(comptime T: type, comptime function: anytype) PluginSystemFunction {
    return struct {
        fn call(plugin: *anyopaque, world: *World) callconv(.c) void {
            const typed_plugin: *T = @ptrCast(@alignCast(plugin));
            function(typed_plugin, world);
        }
    }.call;
}

pub const SystemIterator = struct {
    group_index: usize = 0,
    system_index: usize = 0,

    pub fn next(self: *SystemIterator, registry: *SystemRegistry) ?SystemEntry {
        const groups = registry.groups.values();
        while (self.group_index < groups.len) {
            const group = groups[self.group_index];
            if (self.system_index < group.items.len) {
                const entry = group.items[self.system_index];
                self.system_index += 1;
                return entry;
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
    try registry.registerSystem(std.testing.allocator, 1, system, null);

    try std.testing.expectEqual(1, registry.groups.count());
    try std.testing.expectEqual(1, registry.groups.get(1).?.items.len);
}

test "registerSystem appends to an existing group in call order" {
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

    var registry = SystemRegistry.init();
    defer registry.deinit(std.testing.allocator);
    var world = World.init();
    defer world.deinit(std.testing.allocator);
    try registry.registerSystem(std.testing.allocator, 1, a, null);
    try registry.registerSystem(std.testing.allocator, 1, b, null);

    var iterator = registry.iterateSystems();
    iterator.next(&registry).?.run(&world);
    iterator.next(&registry).?.run(&world);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2 }, &State.calls);
}

test "registerSystem binds the plugin pointer when provided" {
    const Plugin = struct {
        calls: usize = 0,

        fn update(self: *@This(), _: *World) void {
            self.calls += 1;
        }
    };

    var registry = SystemRegistry.init();
    defer registry.deinit(std.testing.allocator);
    var world = World.init();
    defer world.deinit(std.testing.allocator);
    var plugin = Plugin{};
    try registry.registerSystem(std.testing.allocator, 1, Plugin.update, &plugin);

    var iterator = registry.iterateSystems();
    iterator.next(&registry).?.run(&world);
    try std.testing.expectEqual(1, plugin.calls);
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
    try registry.registerSystem(std.testing.allocator, 2, a, null);
    try registry.registerSystem(std.testing.allocator, 1, b, null);
    try registry.registerSystem(std.testing.allocator, 2, b, null);

    try std.testing.expectEqualSlices(u64, &.{ 2, 1 }, registry.groups.keys());
}

test "iterator yields systems group by group, in registration order" {
    const State = struct {
        var calls: [3]u8 = undefined;
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
    const c = struct {
        fn call(_: *World) callconv(.c) void {
            State.calls[State.count] = 3;
            State.count += 1;
        }
    }.call;

    var registry = SystemRegistry.init();
    defer registry.deinit(std.testing.allocator);
    var world = World.init();
    defer world.deinit(std.testing.allocator);
    try registry.registerSystem(std.testing.allocator, 2, a, null);
    try registry.registerSystem(std.testing.allocator, 1, b, null);
    try registry.registerSystem(std.testing.allocator, 2, c, null);

    var iterator = registry.iterateSystems();
    while (iterator.next(&registry)) |entry| entry.run(&world);
    try std.testing.expectEqualSlices(u8, &.{ 1, 3, 2 }, &State.calls);
}

test "iterator returns null immediately when nothing is registered" {
    var registry = SystemRegistry.init();
    defer registry.deinit(std.testing.allocator);
    var iterator = registry.iterateSystems();
    try std.testing.expectEqual(null, iterator.next(&registry));
}
