const sdl = @import("sdl");
const std = @import("std");

pub fn panic(comptime message: []const u8, args: anytype) noreturn {
    std.log.err(message, args);
    std.process.exit(1);
}

pub fn sdlPanic() noreturn {
    std.log.err("{s}\n", .{sdl.SDL_GetError()});
    std.process.exit(1);
}
