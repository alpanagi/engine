const engine = @import("engine");
const std = @import("std");

test "the engine module and the plugins it registers compile" {
    std.testing.refAllDecls(engine);
    std.testing.refAllDecls(engine.components);
    std.testing.refAllDecls(engine.data);
    std.testing.refAllDecls(engine.events);
    std.testing.refAllDecls(engine.math);
    std.testing.refAllDecls(engine.resources);
    std.testing.refAllDecls(engine.Engine);
}
