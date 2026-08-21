const std = @import("std");

const DeinitFunction = @import("ecs").DeinitFunction;
const Duration = std.Io.Duration;
const Observers = @import("ecs").Observers;
const World = @import("ecs").World;

const getDeinitFunction = @import("ecs").getDeinitFunction;
const panic = @import("../util.zig").panic;
const panicOom = @import("../util.zig").panicOom;

pub const Timers = struct {
    pub const State = TimersState;

    state: *State,

    pub fn fromWorld(_: std.mem.Allocator, world: *World) Timers {
        return .{
            .state = world.resources.get(State) orelse
                panic("system requires Timers but the timer plugin is not registered", .{}),
        };
    }

    pub fn dispatchOwnedEvent(
        self: Timers,
        allocator: std.mem.Allocator,
        duration: Duration,
        event: anytype,
    ) void {
        const Event = @TypeOf(event);

        const owned = allocator.create(Event) catch panicOom("Timers.dispatchOwnedEvent");
        owned.* = event;

        self.state.entries.append(allocator, .{
            .remaining = duration,
            .created_frame = self.state.frame,
            .event = owned,
            .dispatch = dispatchFunction(Event),
            .deinit = getDeinitFunction(Event),
            .destroy = destroyFunction(Event),
        }) catch panicOom("Timers.dispatchOwnedEvent");
    }
};

const TimersState = struct {
    frame: u64 = 0,
    entries: std.ArrayList(Entry) = .empty,

    pub fn beginFrame(self: *TimersState) void {
        self.frame += 1;
    }

    pub fn deinit(self: *TimersState, allocator: std.mem.Allocator) void {
        for (self.entries.items) |entry| {
            entry.deinit(allocator, entry.event);
            entry.destroy(allocator, entry.event);
        }
        self.entries.deinit(allocator);
    }

    pub fn tick(
        self: *TimersState,
        allocator: std.mem.Allocator,
        delta: Duration,
        observers: Observers,
    ) void {
        const elapsed = delta.toNanoseconds();

        var index = self.entries.items.len;
        while (index > 0) {
            index -= 1;

            const pending = &self.entries.items[index];
            if (pending.created_frame == self.frame) continue;

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

const Entry = struct {
    remaining: Duration,
    created_frame: u64,
    event: *anyopaque,

    dispatch: *const fn (std.mem.Allocator, *anyopaque, Observers) void,
    deinit: DeinitFunction,
    destroy: *const fn (std.mem.Allocator, *anyopaque) void,
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
