const std = @import("std");

fn translateSystemLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    translation_file: []const u8,
    system_library: []const u8,
) *std.Build.Step.TranslateC {
    const translateC = b.addTranslateC(.{
        .root_source_file = b.path(translation_file),
        .target = target,
        .optimize = optimize,
    });
    translateC.link_libc = true;
    translateC.linkSystemLibrary(system_library, .{});
    return translateC;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ecs = b.dependency("ecs", .{
        .target = target,
        .optimize = optimize,
    }).module("ecs");

    const sdl = translateSystemLibrary(b, target, optimize, "c/sdl.h", "SDL3").createModule();
    const sdl_image = translateSystemLibrary(b, target, optimize, "c/sdl_image.h", "SDL3_image").createModule();
    _ = translateSystemLibrary(b, target, optimize, "c/sdl_main.h", "SDL3").addModule("sdl_main");

    const shaders = b.dependency("shaders", .{}).module("shaders");
    const toml = b.dependency("toml", .{
        .target = target,
        .optimize = optimize,
    }).module("toml");
    const gltf = b.dependency("gltf", .{
        .target = target,
        .optimize = optimize,
    }).module("gltf");

    const engine_lib = b.addModule("engine", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    engine_lib.addImport("ecs", ecs);
    engine_lib.addImport("sdl", sdl);
    engine_lib.addImport("sdl_image", sdl_image);
    engine_lib.addImport("shaders", shaders);
    engine_lib.addImport("toml", toml);
    engine_lib.addImport("gltf", gltf);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/root.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    tests.root_module.addImport("engine", engine_lib);
    tests.root_module.linkSystemLibrary("SDL3", .{});
    tests.root_module.linkSystemLibrary("SDL3_image", .{});

    b.step("test", "Run the integration tests").dependOn(&b.addRunArtifact(tests).step);
}
