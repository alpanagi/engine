const _ = @import("sdl_main");
const std = @import("std");

const Engine = @import("engine.zig").Engine;

pub fn main(init: std.process.Init) !void {
    var iterator = try init.minimal.args.iterateAllocator(init.gpa);
    defer iterator.deinit();

    _ = iterator.skip();
    const working_directory = iterator.next() orelse ".";

    var engine = try Engine.init(init.gpa, init.io, working_directory);
    defer engine.deinit(init.gpa);

    engine.run();
}
