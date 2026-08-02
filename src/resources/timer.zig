const std = @import("std");

pub const Timer = struct {
    const clock: std.Io.Clock = .awake;

    io: std.Io,
    start: std.Io.Timestamp,
    now: std.Io.Timestamp,

    pub fn init(io: std.Io) Timer {
        const timestamp = clock.now(io);
        return Timer{
            .io = io,
            .start = timestamp,
            .now = timestamp,
        };
    }

    pub fn tick(self: *Timer) void {
        self.now = clock.now(self.io);
    }

    pub fn elapsed(self: *const Timer) std.Io.Duration {
        return self.start.durationTo(self.now);
    }
};
