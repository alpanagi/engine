const engine = @import("engine");
const std = @import("std");

test "the engine module and the plugins it registers compile" {
    std.testing.refAllDecls(engine);
    std.testing.refAllDecls(engine.components);
    std.testing.refAllDecls(engine.data);
    std.testing.refAllDecls(engine.events);
    std.testing.refAllDecls(engine.math);
    std.testing.refAllDecls(engine.resources);
    std.testing.refAllDecls(engine.Engine);
}

const Provided = struct { value: u32 };

const Seen = struct {
    var value: u32 = 0;
};

const ConsumerPlugin = struct {
    pub fn build(self: *ConsumerPlugin, allocator: std.mem.Allocator, one_shots: engine.OneShots) void {
        one_shots.addSystem(allocator, setup, self);
    }

    pub fn setup(_: *ConsumerPlugin, provided: engine.Resource(Provided)) void {
        Seen.value = provided.value.value;
    }
};

const ProviderPlugin = struct {
    pub fn build(_: *ProviderPlugin, allocator: std.mem.Allocator, resources: engine.Resources) void {
        resources.addOwned(allocator, Provided, .{ .value = 9 });
    }
};

test "a resource queued during build reaches a one shot registered by an earlier plugin" {
    const allocator = std.testing.allocator;
    Seen.value = 0;

    var world = engine.World.init(allocator);
    defer world.deinit(allocator);

    world.addOwnedPlugin(allocator, ConsumerPlugin{});
    world.addOwnedPlugin(allocator, ProviderPlugin{});
    world.runSystems(allocator);

    try std.testing.expectEqual(9, Seen.value);
}
