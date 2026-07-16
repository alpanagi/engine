const builtin = @import("builtin");
const sdl = @import("sdl");
const std = @import("std");

const util = @import("util.zig");

const Material = @import("material.zig").Material;
const Window = @import("window.zig").Window;

pub const Graphics = struct {
    device: *sdl.SDL_GPUDevice,
    materials: std.ArrayList(Material),

    pub fn init(alloc: std.mem.Allocator, window: *const Window) Graphics {
        const device = sdl.SDL_CreateGPUDevice(
            sdl.SDL_GPU_SHADERFORMAT_SPIRV,
            false,
            "vulkan",
        ) orelse util.sdlPanic();

        if (!sdl.SDL_ClaimWindowForGPUDevice(device, window.sdl_window)) {
            util.sdlPanic();
        }

        return Graphics{
            .device = device,
            .materials = std.ArrayList(Material).initCapacity(alloc, 16) catch {
                util.panic("Out of memory for shader allocation.\n", .{});
            },
        };
    }

    pub fn deinit(self: *Graphics, alloc: std.mem.Allocator) void {
        self.materials.deinit(alloc);
    }

    pub fn draw(self: *Graphics, window: *Window) void {
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
                .clear_color = sdl.SDL_FColor{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 },
                .load_op = sdl.SDL_GPU_LOADOP_CLEAR,
                .store_op = sdl.SDL_GPU_STOREOP_STORE,
                .cycle = false,
            };
            const renderPass = sdl.SDL_BeginGPURenderPass(commandBuffer, &colorTargetInfo, 1, null);
            sdl.SDL_EndGPURenderPass(renderPass);
        }

        if (!sdl.SDL_SubmitGPUCommandBuffer(commandBuffer)) util.sdlPanic();
    }

    pub fn createMaterial(self: *Graphics, alloc: std.mem.Allocator, reader: *std.Io.Reader) !void {
        const material = try Material.init(self.device, reader);
        try self.materials.append(alloc, material);
    }
};
