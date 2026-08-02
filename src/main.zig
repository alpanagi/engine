const _ = @import("sdl_main");
const std = @import("std");

const Engine = @import("engine").Engine;
const GraphicsPlugin = @import("engine").plugins.GraphicsPlugin;
const ModuleLoaderPlugin = @import("engine").plugins.ModuleLoaderPlugin;
const TimerPlugin = @import("engine").plugins.TimerPlugin;
const WindowPlugin = @import("engine").plugins.WindowPlugin;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var iterator = try init.minimal.args.iterateAllocator(allocator);
    defer iterator.deinit();

    _ = iterator.skip();
    const working_directory = iterator.next() orelse ".";

    var engine = try Engine.init(allocator, init.io, working_directory);
    defer engine.deinit(allocator);

    try engine.world.addPlugin(allocator, TimerPlugin);
    try engine.world.addPlugin(allocator, GraphicsPlugin);
    try engine.world.addPlugin(allocator, WindowPlugin);
    try engine.world.addPlugin(allocator, ModuleLoaderPlugin);

    try engine.run(allocator);
}
