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

    const toml = b.dependency("toml", .{
        .target = target,
        .optimize = optimize,
    }).module("toml");
    const ecs = b.dependency("ecs", .{
        .target = target,
        .optimize = optimize,
    }).module("ecs");

    const engine_lib = b.addModule("engine", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const engine_internal = b.createModule(.{
        .root_source_file = b.path("src/engine.zig"),
        .target = target,
        .optimize = optimize,
    });

    for ([_]*std.Build.Module{ engine_lib, engine_internal }) |module| {
        module.addImport("sdl", sdl);
        module.addImport("sdl_image", sdl_image);
        module.addImport("toml", toml);
        module.addImport("ecs", ecs);
    }

    const exe = b.addExecutable(.{
        .name = "engine",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("sdl_main", sdl_main);
    exe.root_module.addImport("engine", engine_internal);

    b.installArtifact(exe);
}

pub fn buildModules(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    imports: []const std.Build.Module.Import,
) void {
    const io = b.graph.io;

    var dir = b.build_root.handle.openDir(io, "src/modules", .{ .iterate = true }) catch return;
    defer dir.close(io);

    var it = dir.iterate();
    while (it.next(io) catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;

        const name = entry.name[0 .. entry.name.len - ".zig".len];
        const source_path = std.fmt.allocPrint(b.allocator, "src/modules/{s}", .{entry.name}) catch @panic("OOM");

        const module = b.addLibrary(.{
            .linkage = .dynamic,
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(source_path),
                .target = target,
                .optimize = optimize,
                .imports = imports,
            }),
        });

        const install = b.addInstallArtifact(module, .{
            .dest_dir = .{ .override = .{ .custom = "../assets/modules" } },
        });
        b.getInstallStep().dependOn(&install.step);
    }
}
