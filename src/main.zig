const _ = @import("sdl_main");

const Engine = @import("engine.zig").Engine;

pub fn main() !void {
    var engine = Engine.init();
    defer engine.deinit();

    engine.run();
}
