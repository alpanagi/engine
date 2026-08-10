const sdl = @import("sdl");
const std = @import("std");

const ecs = @import("ecs");

const util = @import("../../util.zig");

const AssetLoader = @import("../../resources/asset_loader/asset_loader.zig").AssetLoader;
const Mesh = @import("../../components/mesh.zig").Mesh;
const GPUMesh = @import("../../resources/materials/gpu_mesh.zig").GPUMesh;
const Instance = @import("../../resources/materials/instance.zig").Instance;
const Material = @import("../../resources/materials/material.zig").Material;
const Materials = @import("../../resources/materials/materials.zig").Materials;
const MeshData = @import("../../resources/mesh_data.zig").MeshData;
const Transform = @import("../../components/transform.zig").Transform;

const Window = @import("../window_plugin.zig").Window;
const WindowDestroying = @import("../window_plugin.zig").WindowDestroying;

pub const RegisterMesh = struct {
    id: u64,
    material: []const u8,
    data: *MeshData,

    pub fn fromOwnedAlloc(
        alloc: std.mem.Allocator,
        id: []const u8,
        material: []const u8,
        data: *MeshData,
    ) !RegisterMesh {
        return RegisterMesh{
            .id = util.hashBytes(id),
            .material = try alloc.dupe(u8, material),
            .data = data,
        };
    }

    pub fn deinit(self: *RegisterMesh, alloc: std.mem.Allocator) void {
        alloc.free(self.material);
        self.material = &.{};
    }
};

const PendingMesh = struct {
    id: u64,
    material: []const u8,
    data: MeshData,

    fn init(alloc: std.mem.Allocator, event: *const RegisterMesh) !PendingMesh {
        const material = try alloc.dupe(u8, event.material);
        errdefer alloc.free(material);

        const data = event.data.*;
        event.data.positions = &.{};

        return PendingMesh{
            .id = event.id,
            .material = material,
            .data = data,
        };
    }

    fn deinit(self: *PendingMesh, alloc: std.mem.Allocator) void {
        alloc.free(self.material);
        self.data.deinit(alloc);
    }
};

pub const GraphicsPlugin = struct {
    device: ?*sdl.SDL_GPUDevice = null,
    sdl_window: ?*sdl.SDL_Window = null,
    pending_meshes: std.ArrayList(PendingMesh) = .empty,

    pub fn deinit(self: *GraphicsPlugin, alloc: std.mem.Allocator) void {
        for (self.pending_meshes.items) |*pending| pending.deinit(alloc);
        self.pending_meshes.deinit(alloc);
    }

    pub fn build(self: *GraphicsPlugin, commands: ecs.Commands) !void {
        try commands.addObserver(onWindowCreate, self);
        try commands.addObserver(onWindowDestroy, self);
        try commands.addObserver(onMeshRegister, self);
        try commands.addSystem("post-update", uploadPendingMeshes, self);
        try commands.addSystem("post-update", assignInstances, self);
        try commands.addSystem("post-update", uploadBuffers, self);
        try commands.addSystem("post-update", draw, self);
    }

    pub fn onWindowCreate(
        self: *GraphicsPlugin,
        windows: ecs.Query(&.{Window}),
        added: ecs.Event(ecs.events.component.Added(Window)),
    ) !void {
        const window = (try windows.get(added.value.entity))[0];

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
    }

    pub fn onMeshRegister(
        self: *GraphicsPlugin,
        allocator: std.mem.Allocator,
        event: ecs.Event(RegisterMesh),
    ) !void {
        var pending = try PendingMesh.init(allocator, event.value);
        errdefer pending.deinit(allocator);

        try self.pending_meshes.append(allocator, pending);
    }

    pub fn uploadPendingMeshes(
        self: *GraphicsPlugin,
        allocator: std.mem.Allocator,
        materials: ecs.Resource(Materials),
        asset_loader: ecs.Resource(AssetLoader),
    ) !void {
        if (self.pending_meshes.items.len == 0) return;

        const device = self.device orelse return;

        defer self.pending_meshes.clearRetainingCapacity();

        for (self.pending_meshes.items) |*pending| {
            defer pending.deinit(allocator);

            const material_index = materials.value.find(pending.material) orelse
                loadMaterial(device, allocator, asset_loader.value, materials.value, pending.material) orelse continue;

            const material = &materials.value.materials.items[material_index];
            if (material.findGpuMesh(pending.id) != null) continue;

            const vertex_offset = material.addVertices(device, pending.data.positions);
            const gpu_mesh = GPUMesh.init(device, vertex_offset, pending.data.vertexCount());

            _ = try material.addGpuMesh(allocator, pending.id, gpu_mesh);
        }
    }

    pub fn assignInstances(
        self: *GraphicsPlugin,
        allocator: std.mem.Allocator,
        materials: ecs.Resource(Materials),
        asset_loader: ecs.Resource(AssetLoader),
        meshes: ecs.Query(&.{ Mesh, Transform }),
    ) void {
        const device = self.device orelse return;

        var it = meshes.iterator();
        while (it.next()) |entity| {
            const mesh = entity[0];
            const transform = entity[1];

            if (mesh.instance_index != null) continue;

            const material_index = materials.value.find(mesh.material) orelse
                loadMaterial(device, allocator, asset_loader.value, materials.value, mesh.material) orelse continue;

            const material = &materials.value.materials.items[material_index];

            const gpu_mesh_index = material.findGpuMesh(util.hashBytes(mesh.id)) orelse continue;
            const gpu_mesh = &material.gpu_meshes.items[gpu_mesh_index];

            mesh.material_index = material_index;
            mesh.gpu_mesh_index = gpu_mesh_index;
            mesh.instance_index = gpu_mesh.addInstance(device, Instance{ .position = transform.position });
        }
    }

    fn loadMaterial(
        device: *sdl.SDL_GPUDevice,
        allocator: std.mem.Allocator,
        asset_loader: *AssetLoader,
        materials: *Materials,
        id: []const u8,
    ) ?u32 {
        const path = std.fmt.allocPrint(allocator, "assets/shaders/{s}.spv", .{id}) catch {
            util.panic("Out of memory for shader path allocation.\n", .{});
        };
        defer allocator.free(path);

        const shader_data = asset_loader.readBinaryFileAlloc(allocator, path) catch {
            util.panic("Failed to read shader: {s}\n", .{path});
        };
        defer allocator.free(shader_data);

        var reader = std.Io.Reader.fixed(shader_data);
        const material = Material.init(device, &reader) catch {
            util.panic("Failed to create material: {s}\n", .{path});
        };

        const material_index: u32 = @intCast(materials.materials.items.len);
        materials.add(allocator, id, material) catch {
            util.panic("Out of memory for material allocation.\n", .{});
        };

        return material_index;
    }

    pub fn onWindowDestroy(
        self: *GraphicsPlugin,
        allocator: std.mem.Allocator,
        materials: ecs.Resource(Materials),
        _: ecs.Event(WindowDestroying),
    ) void {
        if (self.device) |device| {
            materials.value.sdlDeinit(allocator, device);

            if (self.sdl_window) |window| sdl.SDL_ReleaseWindowFromGPUDevice(device, window);
            sdl.SDL_DestroyGPUDevice(device);
            self.device = null;
        }
        self.sdl_window = null;
    }

    pub fn uploadBuffers(
        self: *GraphicsPlugin,
        materials: ecs.Resource(Materials),
    ) void {
        const device = self.device orelse return;

        const commandBuffer = sdl.SDL_AcquireGPUCommandBuffer(device) orelse util.sdlPanic();
        const copyPass = sdl.SDL_BeginGPUCopyPass(commandBuffer) orelse util.sdlPanic();

        for (materials.value.materials.items) |*material| {
            if (material.vertex_buffer) |*buffer| {
                if (buffer.dirty) buffer.upload(copyPass);
            }

            for (material.gpu_meshes.items) |*gpu_mesh| {
                if (gpu_mesh.instance_buffer.dirty) gpu_mesh.instance_buffer.upload(copyPass);
            }
        }

        sdl.SDL_EndGPUCopyPass(copyPass);
        if (!sdl.SDL_SubmitGPUCommandBuffer(commandBuffer)) util.sdlPanic();
    }

    pub fn draw(
        self: *GraphicsPlugin,
        materials: ecs.Resource(Materials),
        windows: ecs.Query(&.{Window}),
    ) void {
        if (self.device == null) return;

        var it = windows.iterator();
        const window = (it.next() orelse return)[0];

        const commandBuffer = sdl.SDL_AcquireGPUCommandBuffer(self.device) orelse util.sdlPanic();

        var swapchainTexture: ?*sdl.SDL_GPUTexture = null;
        var swapchainTextureWidth: sdl.Uint32 = 1;
        var swapchainTextureHeight: sdl.Uint32 = 1;
        if (!sdl.SDL_WaitAndAcquireGPUSwapchainTexture(
            commandBuffer,
            window.sdl_window,
            &swapchainTexture,
            &swapchainTextureWidth,
            &swapchainTextureHeight,
        )) {
            util.sdlPanic();
        }

        if (swapchainTexture) |texture| {
            const colorTargetInfo = sdl.SDL_GPUColorTargetInfo{
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
            const renderPass = sdl.SDL_BeginGPURenderPass(commandBuffer, &colorTargetInfo, 1, null);

            for (materials.value.materials.items) |material| {
                const vertex_buffer = material.vertex_buffer orelse continue;

                sdl.SDL_BindGPUGraphicsPipeline(renderPass, material.pipeline);

                const binding = sdl.SDL_GPUBufferBinding{
                    .buffer = vertex_buffer.buffer,
                    .offset = 0,
                };
                sdl.SDL_BindGPUVertexBuffers(renderPass, 0, &binding, 1);

                for (material.gpu_meshes.items) |gpu_mesh| {
                    const instance_buffer: *sdl.SDL_GPUBuffer = gpu_mesh.instance_buffer.buffer;
                    sdl.SDL_BindGPUVertexStorageBuffers(renderPass, 0, &instance_buffer, 1);

                    sdl.SDL_DrawGPUPrimitives(
                        renderPass,
                        gpu_mesh.vertex_count,
                        gpu_mesh.instance_buffer.count,
                        gpu_mesh.vertex_offset,
                        0,
                    );
                }
            }

            sdl.SDL_EndGPURenderPass(renderPass);
        }

        if (!sdl.SDL_SubmitGPUCommandBuffer(commandBuffer)) util.sdlPanic();
    }
};
