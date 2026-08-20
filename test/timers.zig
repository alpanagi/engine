const engine = @import("engine");
const std = @import("std");

const Timers = engine.resources.Timers;

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

    var world = engine.World.init();
    defer world.deinit(allocator);

    const State = struct {
        var fired: u32 = 0;
    };
    State.fired = 0;

    world.addObserver(allocator, engine.EventId.from(Plain), struct {
        fn call(event: engine.Event(Plain)) void {
            State.fired += event.value.value;
        }
    }.call, null);

    var timers = Timers{};
    defer timers.deinit(allocator);

    const observers = engine.Observers.fromWorld(allocator, &world);
    timers.dispatchOwnedEvent(allocator, .fromMilliseconds(1000), Plain{ .value = 7 });

    timers.tick(allocator, .fromMilliseconds(400), observers);
    try std.testing.expectEqual(0, State.fired);
    try std.testing.expectEqual(1, timers.entries.items.len);

    timers.tick(allocator, .fromMilliseconds(700), observers);
    try std.testing.expectEqual(7, State.fired);
    try std.testing.expectEqual(0, timers.entries.items.len);
}

test "tick: fires every timer that expires in the same tick" {
    const allocator = std.testing.allocator;

    var world = engine.World.init();
    defer world.deinit(allocator);

    const State = struct {
        var total: u32 = 0;
    };
    State.total = 0;

    world.addObserver(allocator, engine.EventId.from(Plain), struct {
        fn call(event: engine.Event(Plain)) void {
            State.total += event.value.value;
        }
    }.call, null);

    var timers = Timers{};
    defer timers.deinit(allocator);

    const observers = engine.Observers.fromWorld(allocator, &world);
    timers.dispatchOwnedEvent(allocator, .fromMilliseconds(100), Plain{ .value = 1 });
    timers.dispatchOwnedEvent(allocator, .fromMilliseconds(300), Plain{ .value = 2 });
    timers.dispatchOwnedEvent(allocator, .fromMilliseconds(100), Plain{ .value = 4 });

    timers.tick(allocator, .fromMilliseconds(150), observers);
    try std.testing.expectEqual(5, State.total);
    try std.testing.expectEqual(1, timers.entries.items.len);

    timers.tick(allocator, .fromMilliseconds(200), observers);
    try std.testing.expectEqual(7, State.total);
    try std.testing.expectEqual(0, timers.entries.items.len);
}

test "tick: an observer can schedule another timer while being dispatched" {
    const allocator = std.testing.allocator;

    var world = engine.World.init();
    defer world.deinit(allocator);

    var timers = Timers{};
    defer timers.deinit(allocator);

    const State = struct {
        var timers_ptr: *Timers = undefined;
        var timers_allocator: std.mem.Allocator = undefined;
        var first: u32 = 0;
        var second: u32 = 0;
    };
    State.timers_ptr = &timers;
    State.timers_allocator = allocator;
    State.first = 0;
    State.second = 0;

    world.addObserver(allocator, engine.EventId.from(Plain), struct {
        fn call(_: engine.Event(Plain)) void {
            State.first += 1;
            State.timers_ptr.dispatchOwnedEvent(
                State.timers_allocator,
                .fromMilliseconds(100),
                Second{},
            );
        }
    }.call, null);

    world.addObserver(allocator, engine.EventId.from(Second), struct {
        fn call(_: engine.Event(Second)) void {
            State.second += 1;
        }
    }.call, null);

    const observers = engine.Observers.fromWorld(allocator, &world);

    var index: u32 = 0;
    while (index < 24) : (index += 1) {
        timers.dispatchOwnedEvent(allocator, .fromMilliseconds(10), Plain{ .value = 1 });
    }

    timers.tick(allocator, .fromMilliseconds(20), observers);
    try std.testing.expectEqual(24, State.first);
    try std.testing.expectEqual(0, State.second);
    try std.testing.expectEqual(24, timers.entries.items.len);

    timers.tick(allocator, .fromMilliseconds(200), observers);
    try std.testing.expectEqual(24, State.second);
    try std.testing.expectEqual(0, timers.entries.items.len);
}

test "tick: releases an event that owns memory once it has fired" {
    const allocator = std.testing.allocator;

    var world = engine.World.init();
    defer world.deinit(allocator);

    var timers = Timers{};
    defer timers.deinit(allocator);

    timers.dispatchOwnedEvent(
        allocator,
        .fromMilliseconds(10),
        Owning{ .buffer = try allocator.alloc(u8, 8) },
    );
    timers.tick(allocator, .fromMilliseconds(20), engine.Observers.fromWorld(allocator, &world));

    try std.testing.expectEqual(0, timers.entries.items.len);
}

test "deinit: releases the events of timers that never fired" {
    const allocator = std.testing.allocator;

    var timers = Timers{};
    timers.dispatchOwnedEvent(
        allocator,
        .fromMilliseconds(5000),
        Owning{ .buffer = try allocator.alloc(u8, 16) },
    );
    timers.deinit(allocator);
}
