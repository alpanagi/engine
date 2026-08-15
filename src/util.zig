const sdl = @import("sdl");
const std = @import("std");

const seed: u64 = 1234;

pub fn hashBytes(bytes: []const u8) u64 {
    return std.hash.Wyhash.hash(seed, bytes);
}

pub fn panic(comptime message: []const u8, args: anytype) noreturn {
    std.log.err(message, args);
    std.process.exit(1);
}

pub fn panicOom(comptime function_name: []const u8) noreturn {
    panic(function_name ++ ": out of memory", .{});
}

pub fn sdlPanic() noreturn {
    std.log.err("{s}\n", .{sdl.SDL_GetError()});
    std.process.exit(1);
}
