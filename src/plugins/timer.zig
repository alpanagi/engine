const ecs = @import("ecs");
const std = @import("std");

const Timer = @import("../resources/timer.zig").Timer;

pub const TimerPlugin = struct {
    pub fn build(
        self: *TimerPlugin,
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
    ) !void {
        try world.addSystem(allocator.*, "pre-update", tick, self);
    }

    pub fn tick(
        _: *TimerPlugin,
        _: *const std.mem.Allocator,
        world: *ecs.World,
    ) void {
        if (world.getResource(Timer)) |timer| timer.tick();
    }
};