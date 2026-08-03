const sdl = @import("sdl");
const std = @import("std");

const ecs = @import("ecs");

const util = @import("../../util.zig");

const AssetLoader = @import("../../resources/asset_loader.zig").AssetLoader;
const Material = @import("../../resources/materials/material.zig").Material;
const Materials = @import("../../resources/materials/materials.zig").Materials;

const OnWindowDestroy = @import("../window_plugin.zig").OnWindowDestroy;
const OnWindowCreate = @import("../window_plugin.zig").OnWindowCreate;
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
        try world.addSystem(allocator.*, "update", update, self);
    }

    pub fn onWindowCreate(
        self: *GraphicsPlugin,
        allocator: *const std.mem.Allocator,
        world: *ecs.World,
        on_window_create: *const OnWindowCreate,
    ) void {
        const device = sdl.SDL_CreateGPUDevice(
            sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            false,
            "vulkan",
        ) orelse util.sdlPanic();

        if (!sdl.SDL_ClaimWindowForGPUDevice(device, on_window_create.sdl_window)) {
            util.sdlPanic();
        }

        self.device = device;
        self.sdl_window = on_window_create.sdl_window;

        const asset_loader = world.getResource(AssetLoader) orelse return;
        const materials = world.getResource(Materials) orelse return;

        const shader_data = asset_loader.readBinaryFileAlloc(allocator.*, "assets/shaders/diffuse.spv") catch {
            util.panic("Failed to read shader: assets/shaders/diffuse.spv\n", .{});
        };
        defer allocator.free(shader_data);

        var reader = std.Io.Reader.fixed(shader_data);
        const material = Material.init(device, &reader) catch {
            util.panic("Failed to create material: assets/shaders/diffuse.spv\n", .{});
        };

        materials.add(allocator.*, material) catch {
            util.panic("Out of memory for material allocation.\n", .{});
        };
    }

    pub fn onWindowDestroy(
        self: *GraphicsPlugin,
        _: *const std.mem.Allocator,
        _: *ecs.World,
        _: *const OnWindowDestroy,
    ) void {
        if (self.device) |device| {
            if (self.sdl_window) |window| sdl.SDL_ReleaseWindowFromGPUDevice(device, window);
            sdl.SDL_DestroyGPUDevice(device);
            self.device = null;
        }
        self.sdl_window = null;
    }

    pub fn update(
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
                sdl.SDL_BindGPUGraphicsPipeline(renderPass, material.pipeline);
                sdl.SDL_DrawGPUPrimitives(renderPass, 3, 1, 0, 0);
            }

            sdl.SDL_EndGPURenderPass(renderPass);
        }

        if (!sdl.SDL_SubmitGPUCommandBuffer(commandBuffer)) util.sdlPanic();
    }
};
