const ecs = @import("ecs");
const std = @import("std");

const Time = @import("../resources/time.zig").Time;

pub const TimePlugin = struct {
    pub fn build(
        self: *TimePlugin,
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
    ) !void {
        try world.addSystem(allocator.*, "pre-update", tick, self);
    }

    pub fn tick(
        _: *TimePlugin,
        _: *const std.mem.Allocator,
        world: *ecs.World,
    ) void {
        if (world.getResource(Time)) |time| time.tick();
    }
};