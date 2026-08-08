const ecs = @import("ecs");
const std = @import("std");

const Time = @import("../resources/time.zig").Time;

pub const TimePlugin = struct {
    pub fn build(
        self: *TimePlugin,
        allocator: std.mem.Allocator,
        world: *ecs.World,
    ) !void {
        try world.addSystem(allocator, "pre-update", tick, self);
    }

    pub fn tick(_: *TimePlugin, time: ecs.Resource(Time)) void {
        time.value.tick();
    }
};