const sdl = @import("sdl");
const util = @import("../../util.zig");

pub const GPUBuffer = struct {
    buffer: *sdl.SDL_GPUBuffer,
    transfer_buffer: *sdl.SDL_GPUTransferBuffer,
    usage: sdl.SDL_GPUBufferUsageFlags,
    size: u32,
    count: u32 = 0,
    dirty: bool = false,

    pub fn init(
        device: *sdl.SDL_GPUDevice,
        usage: sdl.SDL_GPUBufferUsageFlags,
        size: u32,
    ) GPUBuffer {
        const create_info = sdl.SDL_GPUBufferCreateInfo{
            .usage = usage,
            .size = size,
            .props = 0,
        };

        const buffer = sdl.SDL_CreateGPUBuffer(device, &create_info) orelse util.sdlPanic();

        const transfer_create_info = sdl.SDL_GPUTransferBufferCreateInfo{
            .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
            .size = size,
            .props = 0,
        };

        const transfer_buffer = sdl.SDL_CreateGPUTransferBuffer(
            device,
            &transfer_create_info,
        ) orelse util.sdlPanic();

        return GPUBuffer{
            .buffer = buffer,
            .transfer_buffer = transfer_buffer,
            .usage = usage,
            .size = size,
        };
    }

    pub fn deinit(self: *GPUBuffer, device: *sdl.SDL_GPUDevice) void {
        sdl.SDL_ReleaseGPUTransferBuffer(device, self.transfer_buffer);
        sdl.SDL_ReleaseGPUBuffer(device, self.buffer);
    }

    pub fn write(self: *GPUBuffer, device: *sdl.SDL_GPUDevice, data: []const u8, count: u32) void {
        const mapped = sdl.SDL_MapGPUTransferBuffer(
            device,
            self.transfer_buffer,
            true,
        ) orelse util.sdlPanic();

        @memcpy(@as([*]u8, @ptrCast(mapped))[0..data.len], data);

        sdl.SDL_UnmapGPUTransferBuffer(device, self.transfer_buffer);

        self.count = count;
        self.dirty = true;
    }

    pub fn append(self: *GPUBuffer, device: *sdl.SDL_GPUDevice, data: []const u8, count: u32) void {
        const record_size: u32 = @intCast(data.len / count);
        const offset = self.count * record_size;

        const mapped = sdl.SDL_MapGPUTransferBuffer(
            device,
            self.transfer_buffer,
            false,
        ) orelse util.sdlPanic();

        @memcpy(@as([*]u8, @ptrCast(mapped))[offset..][0..data.len], data);

        sdl.SDL_UnmapGPUTransferBuffer(device, self.transfer_buffer);

        self.count += count;
        self.dirty = true;
    }

    pub fn grow(self: *GPUBuffer, device: *sdl.SDL_GPUDevice, new_size: u32) void {
        var new_buffer = GPUBuffer.init(device, self.usage, new_size);

        const old_mapped = sdl.SDL_MapGPUTransferBuffer(device, self.transfer_buffer, false) orelse util.sdlPanic();
        const new_mapped = sdl.SDL_MapGPUTransferBuffer(device, new_buffer.transfer_buffer, false) orelse util.sdlPanic();

        @memcpy(
            @as([*]u8, @ptrCast(new_mapped))[0..self.size],
            @as([*]u8, @ptrCast(old_mapped))[0..self.size],
        );

        sdl.SDL_UnmapGPUTransferBuffer(device, self.transfer_buffer);
        sdl.SDL_UnmapGPUTransferBuffer(device, new_buffer.transfer_buffer);

        new_buffer.count = self.count;
        new_buffer.dirty = true;

        self.deinit(device);
        self.* = new_buffer;
    }

    pub fn upload(self: *GPUBuffer, copy_pass: *sdl.SDL_GPUCopyPass) void {
        const source = sdl.SDL_GPUTransferBufferLocation{
            .transfer_buffer = self.transfer_buffer,
            .offset = 0,
        };
        const destination = sdl.SDL_GPUBufferRegion{
            .buffer = self.buffer,
            .offset = 0,
            .size = self.size,
        };

        sdl.SDL_UploadToGPUBuffer(copy_pass, &source, &destination, false);

        self.dirty = false;
    }
};
