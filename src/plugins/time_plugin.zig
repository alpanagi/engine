const ecs = @import("ecs");

const Time = @import("../resources/time.zig").Time;

pub const TimePlugin = struct {
    pub fn build(self: *TimePlugin, commands: ecs.Commands) !void {
        try commands.addSystem("pre-update", tick, self);
    }

    pub fn tick(_: *TimePlugin, time: ecs.Resource(Time)) void {
        time.value.tick();
    }
};