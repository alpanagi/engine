pub const Engine = @import("engine.zig").Engine;
pub const Entity = @import("ecs").Entity;
pub const EventId = @import("ecs").EventId;
pub const World = @import("ecs").World;

pub const eventId = @import("ecs").eventId;

pub const components = struct {
    pub const Active = @import("components/active.zig").Active;
    pub const Camera = @import("components/camera.zig").Camera;
    pub const MeshInstance = @import("components/mesh_instance.zig").MeshInstance;
    pub const Transform = @import("components/transform.zig").Transform;
};

pub const data = struct {
    pub const MeshData = @import("data/mesh_data.zig").MeshData;
};

pub const events = struct {
    pub const ComponentAdded = @import("ecs").events.ComponentAdded;
    pub const ComponentDestroying = @import("ecs").events.ComponentDestroying;
    pub const ResourceAdded = @import("ecs").events.ResourceAdded;
    pub const ResourceDestroying = @import("ecs").events.ResourceDestroying;
    pub const ShuttingDown = @import("engine.zig").ShuttingDown;
    pub const WindowDestroying = @import("plugins/window_plugin.zig").WindowDestroying;

    pub const componentAdded = @import("ecs").events.componentAdded;
    pub const componentDestroying = @import("ecs").events.componentDestroying;
    pub const resourceAdded = @import("ecs").events.resourceAdded;
    pub const resourceDestroying = @import("ecs").events.resourceDestroying;
};

pub const gltf = struct {
    pub const Gltf = @import("gltf").Gltf;
    pub const GltfError = @import("gltf").GltfError;
    pub const Mesh = @import("gltf").Mesh;
    pub const Primitive = @import("gltf").Primitive;
};

pub const math = struct {
    pub const mat4 = @import("math/mat4.zig");
    pub const quat = @import("math/quat.zig");
    pub const vec4 = @import("math/vec4.zig");

    pub const Mat4 = mat4.Mat4;
    pub const Quat = quat.Quat;
    pub const Vec4 = vec4.Vec4;
};

pub const params = struct {
    pub const AssetLoader = @import("params/asset_loader/asset_loader.zig").AssetLoader;
    pub const Entities = @import("ecs").Entities;
    pub const Event = @import("ecs").Event;
    pub const Materials = @import("params/materials.zig").Materials;
    pub const Meshes = @import("params/meshes.zig").Meshes;
    pub const Observers = @import("ecs").Observers;
    pub const OneShots = @import("ecs").OneShots;
    pub const Query = @import("ecs").Query;
    pub const Resource = @import("ecs").Resource;
    pub const Resources = @import("ecs").Resources;
    pub const Systems = @import("ecs").Systems;
    pub const Time = @import("params/time.zig").Time;
    pub const Timers = @import("params/timers.zig").Timers;
};

pub const plugins = struct {
    pub const FPSLoggingPlugin = @import("plugins/optional/fps_logging_plugin.zig").FPSLoggingPlugin;
};

pub const resources = struct {
    pub const Config = @import("resources/config.zig").Config;
};
