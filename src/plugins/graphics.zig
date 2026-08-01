const sdl = @import("sdl");
const std = @import("std");

const ecs = @import("ecs");

const util = @import("../util.zig");

const Material = @import("../material.zig").Material;

const OnWindowDestroy = @import("window.zig").OnWindowDestroy;
const OnWindowCreate = @import("window.zig").OnWindowCreate;
const OnWindowUpdate = @import("window.zig").OnWindowUpdate;

pub const GraphicsPlugin = struct {
    device: ?*sdl.SDL_GPUDevice = null,
    sdl_window: ?*sdl.SDL_Window = null,
    materials: std.ArrayList(Material) = .empty,

    pub fn deinit(self: *GraphicsPlugin, alloc: std.mem.Allocator) void {
        self.materials.deinit(alloc);
    }

    pub fn build(self: *GraphicsPlugin, allocator: std.mem.Allocator, world: *ecs.World) !void {
        try world.addObserver(allocator, onWindowCreate, self);
        try world.addObserver(allocator, onWindowDestroy, self);
        try world.addObserver(allocator, onWindowUpdate, self);
    }

    pub fn onWindowCreate(
        self: *GraphicsPlugin,
        allocator: *const std.mem.Allocator,
        _: *ecs.World,
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
        self.materials = std.ArrayList(Material).initCapacity(allocator.*, 16) catch {
            util.panic("Out of memory for shader allocation.\n", .{});
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

    pub fn onWindowUpdate(
        self: *GraphicsPlugin,
        _: *const std.mem.Allocator,
        _: *ecs.World,
        on_window_update: *const OnWindowUpdate,
    ) void {
        const commandBuffer = sdl.SDL_AcquireGPUCommandBuffer(self.device) orelse util.sdlPanic();

        var swapchainTexture: ?*sdl.SDL_GPUTexture = null;
        var swapchainTextureWidth: sdl.Uint32 = 1;
        var swapchainTextureHeight: sdl.Uint32 = 1;
        if (!sdl.SDL_WaitAndAcquireGPUSwapchainTexture(
            commandBuffer,
            on_window_update.sdl_window,
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
                    .r = on_window_update.clear_color.r,
                    .g = on_window_update.clear_color.g,
                    .b = on_window_update.clear_color.b,
                    .a = on_window_update.clear_color.a,
                },
                .load_op = sdl.SDL_GPU_LOADOP_CLEAR,
                .store_op = sdl.SDL_GPU_STOREOP_STORE,
                .cycle = false,
            };
            const renderPass = sdl.SDL_BeginGPURenderPass(commandBuffer, &colorTargetInfo, 1, null);
            sdl.SDL_EndGPURenderPass(renderPass);
        }

        if (!sdl.SDL_SubmitGPUCommandBuffer(commandBuffer)) util.sdlPanic();
    }

    fn createMaterial(
        self: *GraphicsPlugin,
        alloc: std.mem.Allocator,
        reader: *std.Io.Reader,
    ) !void {
        const material = try Material.init(self.device, reader);
        try self.materials.append(alloc, material);
    }
};
