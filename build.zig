const std = @import("std");

fn addSystemLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    translation_file: []const u8,
    system_library: []const u8,
) *std.Build.Module {
    const translateC = b.addTranslateC(.{
        .root_source_file = b.path(translation_file),
        .target = target,
        .optimize = optimize,
    });
    translateC.link_libc = true;
    translateC.linkSystemLibrary(system_library, .{});
    return translateC.createModule();
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl = addSystemLibrary(b, target, optimize, "c/sdl.h", "SDL3");
    const sdl_main = addSystemLibrary(b, target, optimize, "c/sdl_main.h", "SDL3");
    const sdl_image = addSystemLibrary(b, target, optimize, "c/sdl_image.h", "SDL3_image");

    const exe = b.addExecutable(.{
        .name = "engine",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("sdl", sdl);
    exe.root_module.addImport("sdl_main", sdl_main);
    exe.root_module.addImport("sdl_image", sdl_image);
    exe.root_module.addImport("toml", b.dependency("toml", .{
        .target = target,
        .optimize = optimize,
    }).module("toml"));

    b.installArtifact(exe);
}
