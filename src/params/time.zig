const std = @import("std");

const World = @import("ecs").World;

const panic = @import("../util.zig").panic;

const clock: std.Io.Clock = .awake;
const max_delta: std.Io.Duration = .fromMilliseconds(333);

pub const Time = struct {
    pub const State = TimeState;

    state: *State,

    pub fn fromWorld(_: std.mem.Allocator, world: *World) Time {
        return .{
            .state = world.resources.get(State) orelse
                panic("system requires Time but the time plugin is not registered", .{}),
        };
    }

    pub fn now(self: Time) std.Io.Timestamp {
        return self.state.current;
    }

    pub fn elapsed(self: Time) std.Io.Duration {
        return self.state.start.durationTo(self.state.current);
    }

    pub fn elapsedSeconds(self: Time) f64 {
        return @as(f64, @floatFromInt(self.elapsed().toNanoseconds())) / std.time.ns_per_s;
    }

    pub fn delta(self: Time) std.Io.Duration {
        return self.state.frame_delta;
    }

    pub fn deltaSeconds(self: Time) f64 {
        return @as(f64, @floatFromInt(self.delta().toNanoseconds())) / std.time.ns_per_s;
    }
};

const TimeState = struct {
    io: std.Io,
    start: std.Io.Timestamp,
    current: std.Io.Timestamp,
    frame_delta: std.Io.Duration,

    pub fn init(io: std.Io) TimeState {
        return TimeState{ .io = io, .start = .zero, .current = .zero, .frame_delta = .zero };
    }

    pub fn tick(self: *TimeState) void {
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
};
