const std = @import("std");

const Commands = @import("ecs").Commands;
const Resource = @import("ecs").Resource;
const Time = @import("../../resources/time.zig").Time;
const Timestamp = std.Io.Timestamp;

pub const FPSLoggingPlugin = struct {
    timestamp: Timestamp = .zero,
    rendered_frames: u32 = 0,

    pub fn build(self: *FPSLoggingPlugin, allocator: std.mem.Allocator, commands: Commands) void {
        commands.addSystem(allocator, "update", update, self);
    }

    pub fn update(self: *FPSLoggingPlugin, time: Resource(Time)) void {
        if (self.timestamp.nanoseconds == 0) {
            self.timestamp = time.value.now();
            return;
        }

        self.rendered_frames += 1;

        const now = time.value.now();
        if (self.timestamp.durationTo(now).toSeconds() >= 1) {
            std.log.info("FPS: {d}", .{self.rendered_frames});
            self.timestamp = now;
            self.rendered_frames = 0;
        }
    }
};
