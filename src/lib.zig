pub const components = @import("engine.zig").components;
pub const data = @import("engine.zig").data;
pub const events = @import("engine.zig").events;
pub const resources = @import("engine.zig").resources;

pub const Commands = @import("ecs").Commands;
pub const Engine = @import("engine.zig").Engine;
pub const Entity = @import("ecs").Entity;
pub const Event = @import("ecs").Event;
pub const EventId = @import("ecs").EventId;
pub const Observers = @import("ecs").Observers;
pub const Query = @import("ecs").Query;
pub const Resource = @import("ecs").Resource;
pub const World = @import("ecs").World;

pub const math = struct {
    pub const mat4 = @import("math/mat4.zig");
    pub const quat = @import("math/quat.zig");
    pub const vec4 = @import("math/vec4.zig");

    pub const Mat4 = mat4.Mat4;
    pub const Quat = quat.Quat;
    pub const Vec4 = vec4.Vec4;
};

pub const plugins = struct {
    pub const FPSLoggingPlugin = @import("plugins/optional/fps_logging_plugin.zig").FPSLoggingPlugin;
};
