const std = @import("std");

const CLibrary = struct {
    module: *std.Build.Module,
    system_library: ?[]const u8 = null,
    sources: ?[]const []const u8 = null,
};

fn addSystemCLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    translation_header: []const u8,
    library: []const u8,
) CLibrary {
    const translateC = b.addTranslateC(.{
        .root_source_file = b.path(translation_header),
        .target = target,
        .optimize = optimize,
    });
    translateC.link_libc = true;
    translateC.linkSystemLibrary(library, .{});
    return .{ .module = translateC.createModule(), .system_library = library };
}

fn addLocalCLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    translation_header: []const u8,
    sources: []const []const u8,
) CLibrary {
    const translateC = b.addTranslateC(.{
        .root_source_file = b.path(translation_header),
        .target = target,
        .optimize = optimize,
    });
    translateC.link_libc = true;
    return .{ .module = translateC.createModule(), .sources = sources };
}

fn linkCLibraries(
    build_step: *std.Build.Module,
    libraries: []const CLibrary,
    compile_sources: bool,
) void {
    build_step.link_libc = true;
    for (libraries) |library| {
        if (library.system_library) |name| build_step.linkSystemLibrary(name, .{});
        if (compile_sources) {
            if (library.sources) |sources| {
                build_step.addCSourceFiles(.{ .files = sources });
            }
        }
    }
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl = addSystemCLibrary(b, target, optimize, "c/sdl.h", "SDL3");
    const sdl_main = addSystemCLibrary(b, target, optimize, "c/sdl_main.h", "SDL3");
    const libs = [_]CLibrary{ sdl, sdl_main };

    const exe = b.addExecutable(.{
        .name = "engine",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("sdl", sdl.module);
    exe.root_module.addImport("sdl_main", sdl_main.module);
    exe.root_module.addImport("toml", b.dependency("toml", .{
        .target = target,
        .optimize = optimize,
    }).module("toml"));
    linkCLibraries(exe.root_module, &libs, false);

    b.installArtifact(exe);
}
