const _ = @import("sdl_main");
const std = @import("std");

const Engine = @import("engine.zig").Engine;

pub fn main(init: std.process.Init) !void {
    var engine = Engine.init(init.gpa);
    defer engine.deinit(init.gpa);

    engine.createMaterial(init.gpa, init.io, "assets/shaders/placeholder.spv");
    engine.run();
}
