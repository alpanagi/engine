const ecs = @import("ecs");
const mat4 = @import("../../math/mat4.zig");
const sdl = @import("sdl");
const shaders = @import("shaders");
const std = @import("std");
const util = @import("../../util.zig");
const view_projection = @import("view_projection.zig");

const Active = @import("../../components/active.zig").Active;
const Camera = @import("../../components/camera.zig").Camera;
const GPUMesh = @import("gpu_mesh.zig").GPUMesh;
const Instance = @import("instance.zig").Instance;
const Material = @import("material.zig").Material;
const Materials = @import("../../resources/materials.zig").Materials;
const Meshes = @import("../../resources/meshes.zig").Meshes;
const MeshInstance = @import("../../components/mesh_instance.zig").MeshInstance;
const Transform = @import("../../components/transform.zig").Transform;
const Window = @import("../window_plugin.zig").Window;
const WindowDestroying = @import("../window_plugin.zig").WindowDestroying;

const MeshLocation = struct {
    material: u32,
    gpu_mesh: u32,
};

pub const GraphicsPlugin = struct {
    device: *sdl.SDL_GPUDevice,
    sdl_window: ?*sdl.SDL_Window = null,
    swapchain_format: sdl.SDL_GPUTextureFormat = sdl.SDL_GPU_TEXTUREFORMAT_INVALID,
    materials: std.ArrayList(Material) = .empty,
    material_index_by_id: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    mesh_location_by_id: std.AutoHashMapUnmanaged(u64, MeshLocation) = .empty,
    entities_by_mesh_id: std.AutoHashMapUnmanaged(u64, std.ArrayList(ecs.Entity)) = .empty,

    pub fn init() GraphicsPlugin {
        const device = sdl.SDL_CreateGPUDevice(
            sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            false,
            "vulkan",
        ) orelse util.sdlPanic();

        return .{ .device = device };
    }

    pub fn deinit(self: *GraphicsPlugin, allocator: std.mem.Allocator) void {
        for (self.materials.items) |*material| {
            material.sdlDeinit(self.device);
            material.deinit(allocator);
        }
        self.materials.deinit(allocator);

        var entity_lists = self.entities_by_mesh_id.valueIterator();
        while (entity_lists.next()) |entities| entities.deinit(allocator);
        self.entities_by_mesh_id.deinit(allocator);

        self.mesh_location_by_id.deinit(allocator);
        self.material_index_by_id.deinit(allocator);

        if (self.sdl_window) |window| {
            sdl.SDL_ReleaseWindowFromGPUDevice(self.device, window);
        }
        self.sdl_window = null;

        sdl.SDL_DestroyGPUDevice(self.device);
    }

    pub fn build(self: *GraphicsPlugin, commands: ecs.Commands) void {
        commands.addObserver(ecs.events.component.added(Window), onWindowCreate, self);
        commands.addObserver(ecs.EventId.from(WindowDestroying), onWindowDestroy, self);
        commands.addObserver(ecs.events.component.added(MeshInstance), onMeshInstanceAdded, self);
        commands.addObserver(ecs.events.component.destroying(MeshInstance), onMeshInstanceDestroying, self);

        commands.addSystem("post-update", registerPendingMaterials, self);
        commands.addSystem("post-update", registerPendingMeshes, self);
        commands.addSystem("post-update", addPendingInstances, self);
        commands.addSystem("post-update", uploadDirtyBuffers, self);
        commands.addSystem("post-update", draw, self);
    }

    pub fn onWindowCreate(
        self: *GraphicsPlugin,
        allocator: std.mem.Allocator,
        materials: ecs.Resource(Materials),
        windows: ecs.Query(&.{Window}),
        component_added_event: ecs.Event(ecs.events.ComponentAdded),
    ) void {
        const window = (windows.get(component_added_event.value.entity) catch return)[0];
        if (!sdl.SDL_ClaimWindowForGPUDevice(self.device, window.sdl_window)) {
            util.sdlPanic();
        }

        self.sdl_window = window.sdl_window;
        self.swapchain_format = sdl.SDL_GetGPUSwapchainTextureFormat(self.device, window.sdl_window);

        const diffuse = allocator.dupe(u8, shaders.diffuse) catch
            util.panicOom("GraphicsPlugin.onWindowCreate");
        materials.value.addOwned(allocator, "engine.diffuse", diffuse);
    }

    pub fn onWindowDestroy(
        self: *GraphicsPlugin,
        _: ecs.Event(WindowDestroying),
    ) void {
        if (self.sdl_window) |window| {
            sdl.SDL_ReleaseWindowFromGPUDevice(self.device, window);
        }
        self.sdl_window = null;
    }

    pub fn onMeshInstanceAdded(
        self: *GraphicsPlugin,
        allocator: std.mem.Allocator,
        meshes: ecs.Resource(Meshes),
        mesh_instances: ecs.Query(&.{MeshInstance}),
        component_added_event: ecs.Event(ecs.events.ComponentAdded),
    ) void {
        const entity = component_added_event.value.entity;
        const mesh_instance = (mesh_instances.get(entity) catch return)[0];
        const mesh_id = util.hashBytes(mesh_instance.id);

        if (!self.mesh_location_by_id.contains(mesh_id)) {
            const is_pending_mesh = for (meshes.value.pending.items) |pending| {
                if (std.mem.eql(u8, pending.id, mesh_instance.id)) break true;
            } else false;

            if (!is_pending_mesh) {
                std.log.err("entity references unknown mesh {s}", .{mesh_instance.id});
                return;
            }
        }

        const gop = self.entities_by_mesh_id.getOrPut(allocator, mesh_id) catch
            util.panicOom("GraphicsPlugin.onMeshInstanceAdded");
        if (!gop.found_existing) gop.value_ptr.* = .empty;

        gop.value_ptr.append(allocator, entity) catch
            util.panicOom("GraphicsPlugin.onMeshInstanceAdded");
    }

    pub fn onMeshInstanceDestroying(
        self: *GraphicsPlugin,
        allocator: std.mem.Allocator,
        mesh_instances: ecs.Query(&.{MeshInstance}),
        component_destroying_event: ecs.Event(ecs.events.ComponentDestroying),
    ) void {
        const entity = component_destroying_event.value.entity;
        const mesh_instance = (mesh_instances.get(entity) catch return)[0];
        if (mesh_instance.instance_index != null) return;

        const mesh_id = util.hashBytes(mesh_instance.id);
        const pending_entities = self.entities_by_mesh_id.getPtr(mesh_id) orelse return;

        for (pending_entities.items, 0..) |pending_entity, index| {
            if (!std.meta.eql(pending_entity, entity)) continue;

            _ = pending_entities.swapRemove(index);

            if (pending_entities.items.len == 0) {
                var empty = self.entities_by_mesh_id.fetchRemove(mesh_id).?.value;
                empty.deinit(allocator);
            }

            return;
        }
    }

    pub fn registerPendingMaterials(
        self: *GraphicsPlugin,
        allocator: std.mem.Allocator,
        materials: ecs.Resource(Materials),
    ) void {
        if (materials.value.pending.items.len == 0) return;
        if (self.swapchain_format == sdl.SDL_GPU_TEXTUREFORMAT_INVALID) return;

        defer materials.value.pending.clearRetainingCapacity();

        for (materials.value.pending.items) |*pending| {
            defer pending.deinit(allocator);

            const index: u32 = @intCast(self.materials.items.len);

            self.material_index_by_id.put(allocator, util.hashBytes(pending.id), index) catch
                util.panicOom("GraphicsPlugin.registerPendingMaterials");
            self.materials.append(
                allocator,
                Material.init(self.device, self.swapchain_format, pending.shader_data),
            ) catch util.panicOom("GraphicsPlugin.registerPendingMaterials");
        }
    }

    pub fn registerPendingMeshes(
        self: *GraphicsPlugin,
        allocator: std.mem.Allocator,
        meshes: ecs.Resource(Meshes),
    ) void {
        if (meshes.value.pending.items.len == 0) return;
        if (self.swapchain_format == sdl.SDL_GPU_TEXTUREFORMAT_INVALID) return;

        defer meshes.value.pending.clearRetainingCapacity();

        for (meshes.value.pending.items) |*pending_mesh| {
            defer pending_mesh.deinit(allocator);

            const mesh_id = util.hashBytes(pending_mesh.id);
            if (self.mesh_location_by_id.contains(mesh_id)) {
                std.log.err("mesh {s} is already registered", .{pending_mesh.id});
                continue;
            }

            const material_index = self.material_index_by_id.get(util.hashBytes(pending_mesh.material)) orelse {
                std.log.err("mesh {s} requires unregistered material {s}", .{ pending_mesh.id, pending_mesh.material });

                if (self.entities_by_mesh_id.fetchRemove(mesh_id)) |dropped_entities| {
                    var entities = dropped_entities.value;
                    std.log.err("dropping {d} entities waiting on mesh {s}", .{ entities.items.len, pending_mesh.id });
                    entities.deinit(allocator);
                }

                continue;
            };

            const material = &self.materials.items[material_index];

            const vertex_offset = material.addVertices(self.device, pending_mesh.data.positions);
            const gpu_mesh = GPUMesh.init(self.device, vertex_offset, pending_mesh.data.vertexCount());

            const gpu_mesh_index = material.addGpuMesh(allocator, gpu_mesh);

            self.mesh_location_by_id.put(allocator, mesh_id, .{
                .material = material_index,
                .gpu_mesh = gpu_mesh_index,
            }) catch util.panicOom("GraphicsPlugin.registerPendingMeshes");
        }
    }

    pub fn addPendingInstances(
        self: *GraphicsPlugin,
        allocator: std.mem.Allocator,
        mesh_instances: ecs.Query(&.{ MeshInstance, Transform }),
    ) void {
        if (self.entities_by_mesh_id.count() == 0) return;

        var mesh_ids: std.ArrayList(u64) = .empty;
        defer mesh_ids.deinit(allocator);

        var it = self.entities_by_mesh_id.iterator();
        while (it.next()) |entry| {
            const location = self.mesh_location_by_id.get(entry.key_ptr.*) orelse continue;

            const material = &self.materials.items[location.material];
            const gpu_mesh = &material.gpu_meshes.items[location.gpu_mesh];

            for (entry.value_ptr.items) |entity| {
                const mesh_instance, const transform = mesh_instances.get(entity) catch continue;

                mesh_instance.instance_index =
                    gpu_mesh.addInstance(self.device, Instance{ .position = transform.position });
            }

            mesh_ids.append(allocator, entry.key_ptr.*) catch
                util.panicOom("GraphicsPlugin.addPendingInstances");
        }

        for (mesh_ids.items) |id| {
            var pending_entities = (self.entities_by_mesh_id.fetchRemove(id) orelse continue).value;
            pending_entities.deinit(allocator);
        }
    }

    pub fn uploadDirtyBuffers(self: *GraphicsPlugin) void {
        const command_buffer = sdl.SDL_AcquireGPUCommandBuffer(self.device) orelse util.sdlPanic();
        const copy_pass = sdl.SDL_BeginGPUCopyPass(command_buffer) orelse util.sdlPanic();

        for (self.materials.items) |*material| {
            if (material.vertex_buffer) |*buffer| {
                if (buffer.dirty) buffer.upload(copy_pass);
            }

            for (material.gpu_meshes.items) |*gpu_mesh| {
                if (gpu_mesh.instance_buffer.dirty) gpu_mesh.instance_buffer.upload(copy_pass);
            }
        }

        sdl.SDL_EndGPUCopyPass(copy_pass);
        if (!sdl.SDL_SubmitGPUCommandBuffer(command_buffer)) util.sdlPanic();
    }

    pub fn draw(
        self: *GraphicsPlugin,
        windows: ecs.Query(&.{Window}),
        cameras: ecs.Query(&.{ Camera, Transform, Active }),
    ) void {
        var it = windows.iterator();
        const window = (it.next() orelse return)[0];

        const command_buffer = sdl.SDL_AcquireGPUCommandBuffer(self.device) orelse util.sdlPanic();

        var swapchain_texture: ?*sdl.SDL_GPUTexture = null;
        var swapchain_texture_width: sdl.Uint32 = 1;
        var swapchain_texture_height: sdl.Uint32 = 1;
        if (!sdl.SDL_WaitAndAcquireGPUSwapchainTexture(
            command_buffer,
            window.sdl_window,
            &swapchain_texture,
            &swapchain_texture_width,
            &swapchain_texture_height,
        )) {
            util.sdlPanic();
        }

        if (swapchain_texture) |texture| {
            const aspect = @as(f32, @floatFromInt(swapchain_texture_width)) /
                @as(f32, @floatFromInt(swapchain_texture_height));

            const view_projection_matrix = if (cameras.first()) |entity| blk: {
                const camera = entity[0];
                const transform = entity[1];

                break :blk mat4.mul(
                    view_projection.perspective(camera.fov_y, aspect, camera.near, camera.far),
                    view_projection.viewFromTransform(transform.position, transform.rotation),
                );
            } else mat4.identity;

            sdl.SDL_PushGPUVertexUniformData(
                command_buffer,
                0,
                &view_projection_matrix,
                @sizeOf(mat4.Mat4),
            );

            const color_target_info = sdl.SDL_GPUColorTargetInfo{
                .texture = texture,
                .clear_color = sdl.SDL_FColor{
                    .r = window.clear_color.r,
                    .g = window.clear_color.g,
                    .b = window.clear_color.b,
                    .a = window.clear_color.a,
                },
                .load_op = sdl.SDL_GPU_LOADOP_CLEAR,
                .store_op = sdl.SDL_GPU_STOREOP_STORE,
                .cycle = false,
            };
            const render_pass = sdl.SDL_BeginGPURenderPass(command_buffer, &color_target_info, 1, null);

            for (self.materials.items) |material| {
                const vertex_buffer = material.vertex_buffer orelse continue;

                sdl.SDL_BindGPUGraphicsPipeline(render_pass, material.pipeline);

                const binding = sdl.SDL_GPUBufferBinding{
                    .buffer = vertex_buffer.buffer,
                    .offset = 0,
                };
                sdl.SDL_BindGPUVertexBuffers(render_pass, 0, &binding, 1);

                for (material.gpu_meshes.items) |gpu_mesh| {
                    const instance_buffer: *sdl.SDL_GPUBuffer = gpu_mesh.instance_buffer.buffer;
                    sdl.SDL_BindGPUVertexStorageBuffers(render_pass, 0, &instance_buffer, 1);

                    sdl.SDL_DrawGPUPrimitives(
                        render_pass,
                        gpu_mesh.vertex_count,
                        gpu_mesh.instance_buffer.count,
                        gpu_mesh.vertex_offset,
                        0,
                    );
                }
            }

            sdl.SDL_EndGPURenderPass(render_pass);
        }

        if (!sdl.SDL_SubmitGPUCommandBuffer(command_buffer)) util.sdlPanic();
    }
};
