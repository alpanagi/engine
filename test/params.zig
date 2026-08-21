const engine = @import("engine");
const std = @import("std");

const Fired = struct { value: u32 };

const Seen = struct {
    var fired: u32 = 0;
};

const Prepared = struct {
    var positions: [][3]f32 = &.{};
    var shader: []u8 = &.{};
};

test "the engine params resolve from the world and write through to their state" {
    const allocator = std.testing.allocator;

    Seen.fired = 0;
    Prepared.positions = try allocator.alloc([3]f32, 1);
    Prepared.shader = try allocator.dupe(u8, "shader");

    var world = engine.World.init(allocator);
    defer world.deinit(allocator);

    const resources = engine.params.Resources.fromWorld(allocator, &world);
    resources.addOwned(allocator, engine.params.Timers.State, .{});
    resources.addOwned(allocator, engine.params.Meshes.State, .{});
    resources.addOwned(allocator, engine.params.Materials.State, .{});

    engine.params.Observers.fromWorld(allocator, &world).add(allocator, engine.eventId(Fired), struct {
        fn call(event: engine.params.Event(Fired)) void {
            Seen.fired += event.value.value;
        }
    }.call, null);

    engine.params.Systems.fromWorld(allocator, &world).add(allocator, "update", struct {
        fn call(
            inner: std.mem.Allocator,
            timers: engine.params.Timers,
            meshes: engine.params.Meshes,
            materials: engine.params.Materials,
        ) void {
            timers.dispatchOwnedEvent(inner, .fromMilliseconds(10), Fired{ .value = 7 });
            meshes.addOwned(inner, "cube", "engine.diffuse", .{ .positions = Prepared.positions });
            materials.addOwned(inner, "engine.diffuse", Prepared.shader);
        }
    }.call, null);

    world.runSystems(allocator);

    const timers_state = world.resources.get(engine.params.Timers.State).?;
    try std.testing.expectEqual(1, timers_state.entries.items.len);
    try std.testing.expectEqual(1, world.resources.get(engine.params.Meshes.State).?.pending.items.len);
    try std.testing.expectEqual(1, world.resources.get(engine.params.Materials.State).?.pending.items.len);

    timers_state.beginFrame();
    timers_state.tick(allocator, .fromMilliseconds(50), engine.params.Observers.fromWorld(allocator, &world));

    try std.testing.expectEqual(7, Seen.fired);
    try std.testing.expectEqual(0, timers_state.entries.items.len);
}
