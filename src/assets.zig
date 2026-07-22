const std = @import("std");
const toml = @import("toml");

pub const WindowConfig = struct {
    title: []const u8 = "Engine",
    clear_color: []const u8 = "#000000",

    pub fn default(alloc: std.mem.Allocator) !WindowConfig {
        var window: WindowConfig = .{};

        window.title = try alloc.dupe(u8, window.title);
        errdefer alloc.free(window.title);

        window.clear_color = try alloc.dupe(u8, window.clear_color);
        errdefer alloc.free(window.clear_color);

        return window;
    }

    pub fn deinit(self: *WindowConfig, alloc: std.mem.Allocator) void {
        alloc.free(self.title);
        alloc.free(self.clear_color);
    }
};

pub const ProjectConfig = struct {
    window: WindowConfig = .{},

    pub fn default(alloc: std.mem.Allocator) !ProjectConfig {
        const window = try WindowConfig.default(alloc);
        return .{ .window = window };
    }

    pub fn deinit(self: *ProjectConfig, alloc: std.mem.Allocator) void {
        self.window.deinit(alloc);
    }
};

pub const AssetManager = struct {
    project_data: ProjectConfig,

    pub fn init(alloc: std.mem.Allocator, io: std.Io, working_directory: []const u8) !AssetManager {
        const project_toml_path = try std.fs.path.join(
            alloc,
            &.{ working_directory, "project.toml" },
        );
        defer alloc.free(project_toml_path);

        const project_data = loadProjectData(
            alloc,
            io,
            project_toml_path,
        ) catch try ProjectConfig.default(alloc);

        return AssetManager{
            .project_data = project_data,
        };
    }

    pub fn deinit(self: *AssetManager, alloc: std.mem.Allocator) void {
        self.project_data.deinit(alloc);
    }

    fn loadProjectData(
        alloc: std.mem.Allocator,
        io: std.Io,
        project_toml_path: []const u8,
    ) !ProjectConfig {
        const cwd = std.Io.Dir.cwd();
        const text = try cwd.readFileAlloc(io, project_toml_path, alloc, .unlimited);
        defer alloc.free(text);

        return toml.parse(ProjectConfig, alloc, text) catch ProjectConfig.default(alloc);
    }
};
