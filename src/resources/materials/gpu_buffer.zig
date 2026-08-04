const sdl = @import("sdl");

const util = @import("../../util.zig");

pub const GPUBuffer = struct {
    buffer: *sdl.SDL_GPUBuffer,
    transferBuffer: *sdl.SDL_GPUTransferBuffer,
    usage: sdl.SDL_GPUBufferUsageFlags,
    size: u32,
    count: u32 = 0,
    dirty: bool = false,

    pub fn init(
        device: *sdl.SDL_GPUDevice,
        usage: sdl.SDL_GPUBufferUsageFlags,
        size: u32,
    ) GPUBuffer {
        const createInfo = sdl.SDL_GPUBufferCreateInfo{
            .usage = usage,
            .size = size,
            .props = 0,
        };

        const buffer = sdl.SDL_CreateGPUBuffer(device, &createInfo) orelse util.sdlPanic();

        const transferCreateInfo = sdl.SDL_GPUTransferBufferCreateInfo{
            .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .size = size,
            .props = 0,
        };

        const transferBuffer = sdl.SDL_CreateGPUTransferBuffer(
            device,
            &transferCreateInfo,
        ) orelse util.sdlPanic();

        return GPUBuffer{
            .buffer = buffer,
            .transferBuffer = transferBuffer,
            .usage = usage,
            .size = size,
        };
    }

    pub fn deinit(self: *GPUBuffer, device: *sdl.SDL_GPUDevice) void {
        sdl.SDL_ReleaseGPUTransferBuffer(device, self.transferBuffer);
        sdl.SDL_ReleaseGPUBuffer(device, self.buffer);
    }

    pub fn write(self: *GPUBuffer, device: *sdl.SDL_GPUDevice, data: []const u8, count: u32) void {
        const mapped = sdl.SDL_MapGPUTransferBuffer(
            device,
            self.transferBuffer,
            true,
        ) orelse util.sdlPanic();

        @memcpy(@as([*]u8, @ptrCast(mapped))[0..data.len], data);

        sdl.SDL_UnmapGPUTransferBuffer(device, self.transferBuffer);

        self.count = count;
        self.dirty = true;
    }

    pub fn upload(self: *GPUBuffer, copyPass: *sdl.SDL_GPUCopyPass) void {
        const source = sdl.SDL_GPUTransferBufferLocation{
            .transfer_buffer = self.transferBuffer,
            .offset = 0,
        };
        const destination = sdl.SDL_GPUBufferRegion{
            .buffer = self.buffer,
            .offset = 0,
            .size = self.size,
        };

        sdl.SDL_UploadToGPUBuffer(copyPass, &source, &destination, false);

        self.dirty = false;
    }
};