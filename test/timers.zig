const engine = @import("engine");
const std = @import("std");

const Timers = engine.params.Timers;

const Plain = struct { value: u32 };
const Second = struct {};

const Owning = struct {
    buffer: []u8,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
    }
};

test "dispatchOwnedEvent: holds the event until the duration elapses" {
    const allocator = std.testing.allocator;

    var world = engine.World.init(allocator);
    defer world.deinit(allocator);

    const State = struct {
        var fired: u32 = 0;
    };
    State.fired = 0;

    engine.params.Observers.fromWorld(allocator, &world).add(allocator, engine.eventId(Plain), struct {
        fn call(event: engine.params.Event(Plain)) void {
            State.fired += event.value.value;
        }
    }.call, null);

    var timers_state = Timers.State{};
    defer timers_state.deinit(allocator);
    const timers = Timers{ .state = &timers_state };

    world.runSystems(allocator);

    const observers = engine.params.Observers.fromWorld(allocator, &world);
    timers.dispatchOwnedEvent(allocator, .fromMilliseconds(1000), Plain{ .value = 7 });

    timers_state.beginFrame();
    timers_state.tick(allocator, .fromMilliseconds(400), observers);
    try std.testing.expectEqual(0, State.fired);
    try std.testing.expectEqual(1, timers_state.entries.items.len);

    timers_state.beginFrame();
    timers_state.tick(allocator, .fromMilliseconds(700), observers);
    try std.testing.expectEqual(7, State.fired);
    try std.testing.expectEqual(0, timers_state.entries.items.len);
}

test "tick: fires every timer that expires in the same tick" {
    const allocator = std.testing.allocator;

    var world = engine.World.init(allocator);
    defer world.deinit(allocator);

    const State = struct {
        var total: u32 = 0;
    };
    State.total = 0;

    engine.params.Observers.fromWorld(allocator, &world).add(allocator, engine.eventId(Plain), struct {
        fn call(event: engine.params.Event(Plain)) void {
            State.total += event.value.value;
        }
    }.call, null);

    var timers_state = Timers.State{};
    defer timers_state.deinit(allocator);
    const timers = Timers{ .state = &timers_state };

    world.runSystems(allocator);

    const observers = engine.params.Observers.fromWorld(allocator, &world);
    timers.dispatchOwnedEvent(allocator, .fromMilliseconds(100), Plain{ .value = 1 });
    timers.dispatchOwnedEvent(allocator, .fromMilliseconds(300), Plain{ .value = 2 });
    timers.dispatchOwnedEvent(allocator, .fromMilliseconds(100), Plain{ .value = 4 });

    timers_state.beginFrame();
    timers_state.tick(allocator, .fromMilliseconds(150), observers);
    try std.testing.expectEqual(5, State.total);
    try std.testing.expectEqual(1, timers_state.entries.items.len);

    timers_state.beginFrame();
    timers_state.tick(allocator, .fromMilliseconds(200), observers);
    try std.testing.expectEqual(7, State.total);
    try std.testing.expectEqual(0, timers_state.entries.items.len);
}

test "tick: an observer can schedule another timer while being dispatched" {
    const allocator = std.testing.allocator;

    var world = engine.World.init(allocator);
    defer world.deinit(allocator);

    var timers_state = Timers.State{};
    defer timers_state.deinit(allocator);
    const timers = Timers{ .state = &timers_state };

    const State = struct {
        var timers_handle: Timers = undefined;
        var timers_allocator: std.mem.Allocator = undefined;
        var first: u32 = 0;
        var second: u32 = 0;
    };
    State.timers_handle = timers;
    State.timers_allocator = allocator;
    State.first = 0;
    State.second = 0;

    engine.params.Observers.fromWorld(allocator, &world).add(allocator, engine.eventId(Plain), struct {
        fn call(_: engine.params.Event(Plain)) void {
            State.first += 1;
            State.timers_handle.dispatchOwnedEvent(
                State.timers_allocator,
                .fromMilliseconds(100),
                Second{},
            );
        }
    }.call, null);

    engine.params.Observers.fromWorld(allocator, &world).add(allocator, engine.eventId(Second), struct {
        fn call(_: engine.params.Event(Second)) void {
            State.second += 1;
        }
    }.call, null);

    world.runSystems(allocator);

    const observers = engine.params.Observers.fromWorld(allocator, &world);

    var index: u32 = 0;
    while (index < 24) : (index += 1) {
        timers.dispatchOwnedEvent(allocator, .fromMilliseconds(10), Plain{ .value = 1 });
    }

    timers_state.beginFrame();
    timers_state.tick(allocator, .fromMilliseconds(20), observers);
    try std.testing.expectEqual(24, State.first);
    try std.testing.expectEqual(0, State.second);
    try std.testing.expectEqual(24, timers_state.entries.items.len);

    timers_state.beginFrame();
    timers_state.tick(allocator, .fromMilliseconds(200), observers);
    try std.testing.expectEqual(24, State.second);
    try std.testing.expectEqual(0, timers_state.entries.items.len);
}

test "tick: releases an event that owns memory once it has fired" {
    const allocator = std.testing.allocator;

    var world = engine.World.init(allocator);
    defer world.deinit(allocator);

    var timers_state = Timers.State{};
    defer timers_state.deinit(allocator);
    const timers = Timers{ .state = &timers_state };

    timers.dispatchOwnedEvent(
        allocator,
        .fromMilliseconds(10),
        Owning{ .buffer = try allocator.alloc(u8, 8) },
    );
    timers_state.beginFrame();
    timers_state.tick(allocator, .fromMilliseconds(20), engine.params.Observers.fromWorld(allocator, &world));

    try std.testing.expectEqual(0, timers_state.entries.items.len);
}

test "deinit: releases the events of timers that never fired" {
    const allocator = std.testing.allocator;

    var timers_state = Timers.State{};
    const timers = Timers{ .state = &timers_state };
    timers.dispatchOwnedEvent(
        allocator,
        .fromMilliseconds(5000),
        Owning{ .buffer = try allocator.alloc(u8, 16) },
    );
    timers_state.deinit(allocator);
}

test "dispatchOwnedEvent: a timer never fires in the frame it was created" {
    const allocator = std.testing.allocator;

    var world = engine.World.init(allocator);
    defer world.deinit(allocator);

    const State = struct {
        var fired: u32 = 0;
    };
    State.fired = 0;

    engine.params.Observers.fromWorld(allocator, &world).add(allocator, engine.eventId(Plain), struct {
        fn call(event: engine.params.Event(Plain)) void {
            State.fired += event.value.value;
        }
    }.call, null);

    world.runSystems(allocator);

    const observers = engine.params.Observers.fromWorld(allocator, &world);

    var timers_state = Timers.State{};
    defer timers_state.deinit(allocator);
    const timers = Timers{ .state = &timers_state };

    timers_state.beginFrame();
    timers.dispatchOwnedEvent(allocator, .fromMilliseconds(0), Plain{ .value = 1 });
    timers_state.tick(allocator, .fromMilliseconds(16), observers);
    try std.testing.expectEqual(0, State.fired);

    timers_state.beginFrame();
    timers_state.tick(allocator, .fromMilliseconds(16), observers);
    try std.testing.expectEqual(1, State.fired);

    timers.dispatchOwnedEvent(allocator, .fromMilliseconds(0), Plain{ .value = 2 });
    try std.testing.expectEqual(1, State.fired);

    timers_state.beginFrame();
    timers_state.tick(allocator, .fromMilliseconds(16), observers);
    try std.testing.expectEqual(3, State.fired);
}
