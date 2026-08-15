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
    device: ?*sdl.SDL_GPUDevice = null,
    sdl_window: ?*sdl.SDL_Window = null,
    swapchain_format: sdl.SDL_GPUTextureFormat = sdl.SDL_GPU_TEXTUREFORMAT_INVALID,
    materials: std.ArrayList(Material) = .empty,
    index_by_id: std.AutoHashMapUnmanaged(u64, u32) = .empty,
    mesh_location_by_id: std.AutoHashMapUnmanaged(u64, MeshLocation) = .empty,

    pub fn deinit(self: *GraphicsPlugin, allocator: std.mem.Allocator) void {
        self.mesh_location_by_id.deinit(allocator);
        self.index_by_id.deinit(allocator);

        for (self.materials.items) |*material| material.deinit(allocator);
        self.materials.deinit(allocator);
    }

    fn register(self: *GraphicsPlugin, allocator: std.mem.Allocator, id: []const u8, material: Material) void {
        const index: u32 = @intCast(self.materials.items.len);

        self.index_by_id.put(allocator, util.hashBytes(id), index) catch
            util.panicOom("GraphicsPlugin.register");
        self.materials.append(allocator, material) catch util.panicOom("GraphicsPlugin.register");
    }

    fn find(self: *const GraphicsPlugin, id: []const u8) ?u32 {
        return self.index_by_id.get(util.hashBytes(id));
    }

    pub fn build(self: *GraphicsPlugin, commands: ecs.Commands) void {
        commands.addObserver(ecs.events.component.added(Window), onWindowCreate, self);
        commands.addObserver(ecs.EventId.from(WindowDestroying), onWindowDestroy, self);
        commands.addSystem("post-update", uploadPendingMaterials, self);
        commands.addSystem("post-update", uploadPendingMeshes, self);
        commands.addSystem("post-update", assignInstances, self);
        commands.addSystem("post-update", uploadBuffers, self);
        commands.addSystem("post-update", draw, self);
    }

    pub fn onWindowCreate(
        self: *GraphicsPlugin,
        allocator: std.mem.Allocator,
        materials: ecs.Resource(Materials),
        windows: ecs.Query(&.{Window}),
        added: ecs.Event(ecs.events.ComponentAdded),
    ) void {
        const window = (windows.get(added.value.entity) catch return)[0];

        const device = sdl.SDL_CreateGPUDevice(
            sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            false,
            "vulkan",
        ) orelse util.sdlPanic();

        if (!sdl.SDL_ClaimWindowForGPUDevice(device, window.sdl_window)) {
            util.sdlPanic();
        }

        self.device = device;
        self.sdl_window = window.sdl_window;
        self.swapchain_format = sdl.SDL_GetGPUSwapchainTextureFormat(device, window.sdl_window);

        const diffuse = allocator.dupe(u8, shaders.diffuse) catch
            util.panicOom("GraphicsPlugin.onWindowCreate");

        materials.value.addOwned(allocator, "engine.diffuse", diffuse);
    }

    pub fn uploadPendingMaterials(
        self: *GraphicsPlugin,
        allocator: std.mem.Allocator,
        materials: ecs.Resource(Materials),
    ) void {
        if (materials.value.pending.items.len == 0) return;

        const device = self.device orelse return;

        defer materials.value.pending.clearRetainingCapacity();

        for (materials.value.pending.items) |*pending| {
            defer pending.deinit(allocator);

            self.register(
                allocator,
                pending.id,
                Material.init(device, self.swapchain_format, pending.shader_data),
            );
        }
    }

    pub fn uploadPendingMeshes(
        self: *GraphicsPlugin,
        allocator: std.mem.Allocator,
        meshes: ecs.Resource(Meshes),
    ) void {
        if (meshes.value.pending.items.len == 0) return;

        const device = self.device orelse return;

        defer meshes.value.pending.clearRetainingCapacity();

        for (meshes.value.pending.items) |*mesh| {
            defer mesh.deinit(allocator);

            const id = util.hashBytes(mesh.id);
            if (self.mesh_location_by_id.contains(id)) {
                std.log.err("mesh {s} is already registered", .{mesh.id});
                continue;
            }

            const material_index = self.find(mesh.material) orelse {
                std.log.err("mesh {s} requires unregistered material {s}", .{ mesh.id, mesh.material });
                continue;
            };

            const material = &self.materials.items[material_index];

            const vertex_offset = material.addVertices(device, mesh.data.positions);
            const gpu_mesh = GPUMesh.init(device, vertex_offset, mesh.data.vertexCount());

            const gpu_mesh_index = material.addGpuMesh(allocator, gpu_mesh);

            self.mesh_location_by_id.put(allocator, id, .{
                .material = material_index,
                .gpu_mesh = gpu_mesh_index,
            }) catch util.panicOom("GraphicsPlugin.uploadPendingMeshes");
        }
    }

    pub fn assignInstances(
        self: *GraphicsPlugin,
        meshes: ecs.Query(&.{ MeshInstance, Transform }),
    ) void {
        const device = self.device orelse return;

        var it = meshes.iterator();
        while (it.next()) |entity| {
            const mesh = entity[0];
            const transform = entity[1];

            if (mesh.instance_index != null) continue;

            const location = self.mesh_location_by_id.get(util.hashBytes(mesh.id)) orelse continue;

            const material = &self.materials.items[location.material];
            const gpu_mesh = &material.gpu_meshes.items[location.gpu_mesh];

            mesh.instance_index = gpu_mesh.addInstance(device, Instance{ .position = transform.position });
        }
    }

    pub fn onWindowDestroy(
        self: *GraphicsPlugin,
        allocator: std.mem.Allocator,
        _: ecs.Event(WindowDestroying),
    ) void {
        if (self.device) |device| {
            for (self.materials.items) |*material| {
                material.sdlDeinit(device);
                material.deinit(allocator);
            }

            self.mesh_location_by_id.clearRetainingCapacity();
            self.index_by_id.clearRetainingCapacity();
            self.materials.clearRetainingCapacity();

            if (self.sdl_window) |window| sdl.SDL_ReleaseWindowFromGPUDevice(device, window);
            sdl.SDL_DestroyGPUDevice(device);
            self.device = null;
        }
        self.sdl_window = null;
    }

    pub fn uploadBuffers(self: *GraphicsPlugin) void {
        const device = self.device orelse return;

        const command_buffer = sdl.SDL_AcquireGPUCommandBuffer(device) orelse util.sdlPanic();
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
        if (self.device == null) return;

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
