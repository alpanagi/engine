const std = @import("std");

const clock: std.Io.Clock = .awake;
const max_delta: std.Io.Duration = .fromMilliseconds(333);

pub const Time = struct {
    io: std.Io,
    start: std.Io.Timestamp,
    current: std.Io.Timestamp,
    frame_delta: std.Io.Duration,

    pub fn init(io: std.Io) Time {
        return Time{ .io = io, .start = .zero, .current = .zero, .frame_delta = .zero };
    }

    pub fn tick(self: *Time) void {
        const timestamp = clock.now(self.io);

        if (self.current.nanoseconds == 0) {
            self.start = timestamp;
            self.current = timestamp;
            return;
        }

        const measured = self.current.durationTo(timestamp);
        self.frame_delta = .fromNanoseconds(@min(measured.toNanoseconds(), max_delta.toNanoseconds()));
        self.current = timestamp;
    }

    pub fn now(self: *const Time) std.Io.Timestamp {
        return self.current;
    }

    pub fn elapsed(self: *const Time) std.Io.Duration {
        return self.start.durationTo(self.current);
    }

    pub fn elapsedSeconds(self: *const Time) f64 {
        return @as(f64, @floatFromInt(self.elapsed().toNanoseconds())) / std.time.ns_per_s;
    }

    pub fn delta(self: *const Time) std.Io.Duration {
        return self.frame_delta;
    }

    pub fn deltaSeconds(self: *const Time) f64 {
        return @as(f64, @floatFromInt(self.delta().toNanoseconds())) / std.time.ns_per_s;
    }
};
