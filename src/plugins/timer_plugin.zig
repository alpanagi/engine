const ecs = @import("ecs");
const std = @import("std");

const Time = @import("../resources/time.zig").Time;
const Timers = @import("../resources/timers.zig").Timers;

pub const TimerPlugin = struct {
    pub fn build(self: *TimerPlugin, allocator: std.mem.Allocator, commands: ecs.Commands) void {
        commands.addSystem(allocator, "pre-update", tick, self);
    }

    pub fn tick(
        _: *TimerPlugin,
        allocator: std.mem.Allocator,
        time: ecs.Resource(Time),
        timers: ecs.Resource(Timers),
        observers: ecs.Observers,
    ) void {
        timers.value.tick(allocator, time.value.delta(), observers);
    }
};
