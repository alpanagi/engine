const ecs = @import("ecs");
const std = @import("std");

const Time = @import("../resources/time.zig").Time;

pub const TimePlugin = struct {
    io: std.Io,

    pub fn build(
        self: *TimePlugin,
        allocator: std.mem.Allocator,
        resources: ecs.Resources,
        systems: ecs.Systems,
    ) void {
        resources.addOwned(allocator, Time, Time.init(self.io));
        systems.add(allocator, "pre_update", tick, self);
    }

    pub fn tick(_: *TimePlugin, time: ecs.Resource(Time)) void {
        time.value.tick();
    }
};
