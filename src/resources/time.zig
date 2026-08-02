const std = @import("std");

pub const Time = struct {
    const clock: std.Io.Clock = .awake;

    io: std.Io,
    start: std.Io.Timestamp,
    current: std.Io.Timestamp,

    pub fn init(io: std.Io) Time {
        const timestamp = clock.now(io);
        return Time{
            .io = io,
            .start = timestamp,
            .current = timestamp,
        };
    }

    pub fn tick(self: *Time) void {
        self.current = clock.now(self.io);
    }

    pub fn now(self: *const Time) std.Io.Timestamp {
        return self.current;
    }

    pub fn elapsed(self: *const Time) std.Io.Duration {
        return self.start.durationTo(self.current);
    }
};