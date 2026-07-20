const std = @import("std");
const toml = @import("toml");

pub const ProjectData = struct {
    window_title: []const u8,

    pub fn default(alloc: std.mem.Allocator) !ProjectData {
        return ProjectData{
            .window_title = try alloc.dupe(u8, "Engine"),
        };
    }

    pub fn deinit(self: *ProjectData, alloc: std.mem.Allocator) void {
        alloc.free(self.window_title);
    }
};

pub const AssetManager = struct {
    project_data: ProjectData,

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
        ) catch try ProjectData.default(alloc);

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
    ) !ProjectData {
        const cwd = std.Io.Dir.cwd();
        const text = try cwd.readFileAlloc(io, project_toml_path, alloc, .unlimited);
        defer alloc.free(text);

        return toml.parse(ProjectData, alloc, text);
    }
};
