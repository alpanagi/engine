const ecs = @import("ecs");
const std = @import("std");

const Time = @import("../params/time.zig").Time;
const Timers = @import("../params/timers.zig").Timers;

pub const TimerPlugin = struct {
    pub fn build(
        self: *TimerPlugin,
        allocator: std.mem.Allocator,
        resources: ecs.Resources,
        systems: ecs.Systems,
    ) void {
        resources.addOwned(allocator, Timers.State, .{});

        systems.addGroupBefore(allocator, "one_shots", "timing");
        systems.add(allocator, "timing", beginFrame, self);
        systems.add(allocator, "pre_update", tick, self);
    }

    pub fn beginFrame(_: *TimerPlugin, timers: ecs.Resource(Timers.State)) void {
        timers.value.beginFrame();
    }

    pub fn tick(
        _: *TimerPlugin,
        allocator: std.mem.Allocator,
        time: Time,
        timers: ecs.Resource(Timers.State),
        observers: ecs.Observers,
    ) void {
        timers.value.tick(allocator, time.delta(), observers);
    }
};
