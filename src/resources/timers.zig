const std = @import("std");

const DeinitFunction = @import("ecs").DeinitFunction;
const Duration = std.Io.Duration;
const Observers = @import("ecs").Observers;
const getDeinitFunction = @import("ecs").getDeinitFunction;
const panicOom = @import("../util.zig").panicOom;

pub const Timers = struct {
    const Entry = struct {
        remaining: Duration,
        event: *anyopaque,

        dispatch: *const fn (std.mem.Allocator, *anyopaque, Observers) void,
        deinit: DeinitFunction,
        destroy: *const fn (std.mem.Allocator, *anyopaque) void,
    };

    entries: std.ArrayList(Entry) = .empty,

    pub fn deinit(self: *Timers, allocator: std.mem.Allocator) void {
        for (self.entries.items) |entry| {
            entry.deinit(allocator, entry.event);
            entry.destroy(allocator, entry.event);
        }
        self.entries.deinit(allocator);
    }

    pub fn dispatchOwnedEvent(
        self: *Timers,
        allocator: std.mem.Allocator,
        duration: Duration,
        event: anytype,
    ) void {
        const Event = @TypeOf(event);

        const owned = allocator.create(Event) catch panicOom("Timers.dispatchOwnedEvent");
        owned.* = event;

        self.entries.append(allocator, .{
            .remaining = duration,
            .event = owned,
            .dispatch = dispatchFunction(Event),
            .deinit = getDeinitFunction(Event),
            .destroy = destroyFunction(Event),
        }) catch panicOom("Timers.dispatchOwnedEvent");
    }

    pub fn tick(
        self: *Timers,
        allocator: std.mem.Allocator,
        delta: Duration,
        observers: Observers,
    ) void {
        const elapsed = delta.toNanoseconds();

        var index = self.entries.items.len;
        while (index > 0) {
            index -= 1;

            const pending = &self.entries.items[index];
            const remaining = pending.remaining.toNanoseconds();
            if (remaining > elapsed) {
                pending.remaining = .fromNanoseconds(remaining - elapsed);
                continue;
            }

            const entry = self.entries.swapRemove(index);
            entry.dispatch(allocator, entry.event, observers);
            entry.destroy(allocator, entry.event);
        }
    }
};

fn dispatchFunction(comptime Event: type) *const fn (std.mem.Allocator, *anyopaque, Observers) void {
    return struct {
        fn call(allocator: std.mem.Allocator, event: *anyopaque, observers: Observers) void {
            const typed: *Event = @ptrCast(@alignCast(event));
            observers.dispatchOwnedEvent(allocator, typed.*);
        }
    }.call;
}

fn destroyFunction(comptime Event: type) *const fn (std.mem.Allocator, *anyopaque) void {
    return struct {
        fn call(allocator: std.mem.Allocator, event: *anyopaque) void {
            const typed: *Event = @ptrCast(@alignCast(event));
            allocator.destroy(typed);
        }
    }.call;
}

