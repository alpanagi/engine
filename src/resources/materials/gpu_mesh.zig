const std = @import("std");
const sdl = @import("sdl");

const GPUBuffer = @import("gpu_buffer.zig").GPUBuffer;
const Instance = @import("instance.zig").Instance;

const initial_instance_capacity: u32 = 16;

pub const GPUMesh = struct {
    vertex_offset: u32,
    vertex_count: u32,
    instance_buffer: GPUBuffer,

    pub fn init(
        device: *sdl.SDL_GPUDevice,
        vertex_offset: u32,
        vertex_count: u32,
    ) GPUMesh {
        return GPUMesh{
            .vertex_offset = vertex_offset,
            .vertex_count = vertex_count,
            .instance_buffer = GPUBuffer.init(
                device,
                sdl.SDL_GPU_BUFFERUSAGE_VERTEX | sdl.SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ,
                initial_instance_capacity * @sizeOf(Instance),
            ),
        };
    }

    pub fn deinit(self: *GPUMesh, device: *sdl.SDL_GPUDevice) void {
        self.instance_buffer.deinit(device);
    }

    pub fn writeInstances(
        self: *GPUMesh,
        device: *sdl.SDL_GPUDevice,
        instances: []const Instance,
    ) void {
        self.ensureInstanceCapacity(device, @intCast(instances.len));
        self.instance_buffer.write(device, std.mem.sliceAsBytes(instances), @intCast(instances.len));
    }

    pub fn addInstance(self: *GPUMesh, device: *sdl.SDL_GPUDevice, instance: Instance) u32 {
        const index = self.instance_buffer.count;
        self.ensureInstanceCapacity(device, index + 1);

        const instances = [_]Instance{instance};
        self.instance_buffer.append(device, std.mem.sliceAsBytes(&instances), 1);

        return index;
    }

    fn ensureInstanceCapacity(self: *GPUMesh, device: *sdl.SDL_GPUDevice, count: u32) void {
        const capacity = self.instance_buffer.size / @sizeOf(Instance);
        if (count <= capacity) return;

        var new_capacity: u32 = capacity;
        while (new_capacity < count) new_capacity *= 2;

        self.instance_buffer.grow(device, new_capacity * @sizeOf(Instance));
    }
};
