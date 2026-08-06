const sdl = @import("sdl");
const std = @import("std");

const ecs = @import("ecs");

const util = @import("../../util.zig");

const AssetLoader = @import("../../resources/asset_loader/asset_loader.zig").AssetLoader;
const Mesh = @import("../../components/mesh.zig").Mesh;
const Instance = @import("../../resources/materials/instance.zig").Instance;
const Material = @import("../../resources/materials/material.zig").Material;
const Materials = @import("../../resources/materials/materials.zig").Materials;
const Transform = @import("../../components/transform.zig").Transform;

const OnWindowDestroy = @import("../window_plugin.zig").OnWindowDestroy;
const Window = @import("../window_plugin.zig").Window;

pub const GraphicsPlugin = struct {
    device: ?*sdl.SDL_GPUDevice = null,
    sdl_window: ?*sdl.SDL_Window = null,

    pub fn build(
        self: *GraphicsPlugin,
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
    ) !void {
        try world.addObserver(allocator.*, onWindowCreate, self);
        try world.addObserver(allocator.*, onWindowDestroy, self);
        try world.addObserver(allocator.*, onMeshCreate, self);
        try world.addSystem(allocator.*, "post-update", uploadBuffers, self);
        try world.addSystem(allocator.*, "post-update", draw, self);
    }

    pub fn onWindowCreate(
        self: *GraphicsPlugin,
        _: *const std.mem.Allocator,
        world: *ecs.World,
        created: *const ecs.Created(Window),
    ) void {
        const window = (world.getEntity(created.entity, &.{Window}) catch return)[0];

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

    pub fn onMeshCreate(
        self: *GraphicsPlugin,
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
        created: *const ecs.Created(Mesh),
    ) void {
        const device = self.device orelse return;
        const materials = world.getResource(Materials) orelse return;

        const entity = world.getEntity(created.entity, &.{ Mesh, Transform }) catch return;
        const mesh = entity[0];
        const transform = entity[1];

        const material_index = materials.find(mesh.material) orelse
            loadMaterial(device, allocator.*, world, materials, mesh.material) orelse return;

        const material = &materials.materials.items[material_index];
        if (material.gpu_meshes.items.len == 0) return;

        const gpu_mesh_index: u32 = 0;
        const gpu_mesh = &material.gpu_meshes.items[gpu_mesh_index];

        mesh.material_index = material_index;
        mesh.gpu_mesh_index = gpu_mesh_index;
        mesh.instance_index = gpu_mesh.addInstance(device, Instance{ .location = transform.location });
    }

    fn loadMaterial(
        device: *sdl.SDL_GPUDevice,
        allocator: std.mem.Allocator,
        world: *ecs.World,
        materials: *Materials,
        id: []const u8,
    ) ?u32 {
        const asset_loader = world.getResource(AssetLoader) orelse return null;

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
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
        _: *const OnWindowDestroy,
    ) void {
        if (self.device) |device| {
            if (world.getResource(Materials)) |materials| materials.sdlDeinit(allocator.*, device);

            if (self.sdl_window) |window| sdl.SDL_ReleaseWindowFromGPUDevice(device, window);
            sdl.SDL_DestroyGPUDevice(device);
            self.device = null;
        }
        self.sdl_window = null;
    }

    pub fn uploadBuffers(
        self: *GraphicsPlugin,
        _: *const std.mem.Allocator,
        world: *ecs.World,
    ) void {
        const device = self.device orelse return;
        const materials = world.getResource(Materials) orelse return;

        var commandBuffer: ?*sdl.SDL_GPUCommandBuffer = null;
        var copyPass: ?*sdl.SDL_GPUCopyPass = null;

        for (materials.materials.items) |*material| {
            if (material.vertex_buffer) |*buffer| {
                if (!buffer.dirty) continue;

                if (copyPass == null) {
                    commandBuffer = sdl.SDL_AcquireGPUCommandBuffer(device) orelse util.sdlPanic();
                    copyPass = sdl.SDL_BeginGPUCopyPass(commandBuffer.?) orelse util.sdlPanic();
                }

                buffer.upload(copyPass.?);
            }
        }

        if (copyPass) |pass| {
            sdl.SDL_EndGPUCopyPass(pass);
            if (!sdl.SDL_SubmitGPUCommandBuffer(commandBuffer.?)) util.sdlPanic();
        }
    }

    pub fn draw(
        self: *GraphicsPlugin,
        _: *const std.mem.Allocator,
        world: *ecs.World,
    ) void {
        if (self.device == null) return;

        var query = world.query(&.{Window});
        const window = (query.next(world) orelse return)[0];

        const materials = world.getResource(Materials) orelse return;

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

            for (materials.materials.items) |material| {
                const vertex_buffer = material.vertex_buffer orelse continue;

                sdl.SDL_BindGPUGraphicsPipeline(renderPass, material.pipeline);

                const binding = sdl.SDL_GPUBufferBinding{
                    .buffer = vertex_buffer.buffer,
                    .offset = 0,
                };
                sdl.SDL_BindGPUVertexBuffers(renderPass, 0, &binding, 1);

                for (material.gpu_meshes.items) |gpu_mesh| {
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
