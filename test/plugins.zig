const engine = @import("engine");
const std = @import("std");

test "every exported plugin compiles" {
    std.testing.refAllDecls(engine.plugins.FPSLoggingPlugin);
}
