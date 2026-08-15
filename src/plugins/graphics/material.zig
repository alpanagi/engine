const sdl = @import("sdl");
const std = @import("std");
const util = @import("../../util.zig");

const GPUBuffer = @import("gpu_buffer.zig").GPUBuffer;
const GPUMesh = @import("gpu_mesh.zig").GPUMesh;

const vertex_size: u32 = @sizeOf(f32) * 3;
const initial_vertex_capacity: u32 = 1024;

pub const Material = struct {
    pipeline: *sdl.SDL_GPUGraphicsPipeline,
    vertex_buffer: ?GPUBuffer = null,
    gpu_meshes: std.ArrayList(GPUMesh) = .empty,

    pub fn init(
        device: *sdl.SDL_GPUDevice,
        swapchain_format: sdl.SDL_GPUTextureFormat,
        shader_data: []const u8,
    ) Material {
        const vertex_shader = createShader(
            device,
            sdl.SDL_GPU_SHADERSTAGE_VERTEX,
            "vertex",
            shader_data,
        );
        defer sdl.SDL_ReleaseGPUShader(device, vertex_shader);

        const fragment_shader = createShader(
            device,
            sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
            "fragment",
            shader_data,
        );
        defer sdl.SDL_ReleaseGPUShader(device, fragment_shader);

        const vertex_buffer_description = sdl.SDL_GPUVertexBufferDescription{
            .slot = 0,
            .pitch = vertex_size,
            .input_rate = sdl.SDL_GPU_VERTEXINPUTRATE_VERTEX,
        };
        const vertex_attribute = sdl.SDL_GPUVertexAttribute{
            .location = 0,
            .buffer_slot = 0,
            .format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
        };
        const vertex_input_state = sdl.SDL_GPUVertexInputState{
            .vertex_buffer_descriptions = &vertex_buffer_description,
            .num_vertex_buffers = 1,
            .vertex_attributes = &vertex_attribute,
            .num_vertex_attributes = 1,
        };
        const rasterizer_state = sdl.SDL_GPURasterizerState{
            .fill_mode = sdl.SDL_GPU_FILLMODE_FILL,
            .cull_mode = sdl.SDL_GPU_CULLMODE_BACK,
            .front_face = sdl.SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE,
            .enable_depth_bias = false,
            .enable_depth_clip = false,
        };
        const multisample_state = sdl.SDL_GPUMultisampleState{
            .sample_count = sdl.SDL_GPU_SAMPLECOUNT_1,
            .enable_alpha_to_coverage = false,
        };
        const depth_stencil_state = sdl.SDL_GPUDepthStencilState{
            .compare_op = sdl.SDL_GPU_COMPAREOP_LESS,
            .enable_depth_test = false,
            .enable_depth_write = false,
            .compare_mask = 0,
            .enable_stencil_test = false,
        };
        const target_blend_state = sdl.SDL_GPUColorTargetBlendState{
            .src_color_blendfactor = sdl.SDL_GPU_BLENDFACTOR_ONE,
            .dst_color_blendfactor = sdl.SDL_GPU_BLENDFACTOR_ZERO,
            .color_blend_op = sdl.SDL_GPU_BLENDOP_ADD,
            .src_alpha_blendfactor = sdl.SDL_GPU_BLENDFACTOR_ONE,
            .dst_alpha_blendfactor = sdl.SDL_GPU_BLENDFACTOR_ZERO,
            .alpha_blend_op = sdl.SDL_GPU_BLENDOP_ADD,
            .color_write_mask = 0,
            .enable_blend = false,
            .enable_color_write_mask = false,
        };
        const target_description = sdl.SDL_GPUColorTargetDescription{
            .format = swapchain_format,
            .blend_state = target_blend_state,
        };
        const target_info = sdl.SDL_GPUGraphicsPipelineTargetInfo{
            .num_color_targets = 1,
            .color_target_descriptions = &target_description,
            .has_depth_stencil_target = false,
        };
        const pipeline_create_info = sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .vertex_shader = vertex_shader,
            .fragment_shader = fragment_shader,
            .vertex_input_state = vertex_input_state,
            .primitive_type = sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .rasterizer_state = rasterizer_state,
            .multisample_state = multisample_state,
            .depth_stencil_state = depth_stencil_state,
            .target_info = target_info,
            .props = 0,
        };

        const pipeline = sdl.SDL_CreateGPUGraphicsPipeline(device, &pipeline_create_info) orelse {
            util.sdlPanic();
        };

        return Material{
            .pipeline = pipeline,
        };
    }

    pub fn sdlDeinit(self: *Material, device: *sdl.SDL_GPUDevice) void {
        for (self.gpu_meshes.items) |*gpu_mesh| gpu_mesh.deinit(device);

        self.freeGpuBuffers(device);
        sdl.SDL_ReleaseGPUGraphicsPipeline(device, self.pipeline);
    }

    pub fn deinit(self: *Material, allocator: std.mem.Allocator) void {
        self.gpu_meshes.deinit(allocator);
    }

    pub fn addGpuMesh(self: *Material, allocator: std.mem.Allocator, gpu_mesh: GPUMesh) u32 {
        const index: u32 = @intCast(self.gpu_meshes.items.len);

        self.gpu_meshes.append(allocator, gpu_mesh) catch util.panicOom("Material.addGpuMesh");

        return index;
    }

    pub fn addVertices(self: *Material, device: *sdl.SDL_GPUDevice, vertices: []const [3]f32) u32 {
        const count: u32 = @intCast(vertices.len);
        const offset = if (self.vertex_buffer) |buffer| buffer.count else 0;
        if (count == 0) return offset;

        self.ensureVertexCapacity(device, offset + count);
        self.vertex_buffer.?.append(device, std.mem.sliceAsBytes(vertices), count);

        return offset;
    }

    fn ensureVertexCapacity(self: *Material, device: *sdl.SDL_GPUDevice, count: u32) void {
        if (self.vertex_buffer == null) {
            self.vertex_buffer = GPUBuffer.init(
                device,
                sdl.SDL_GPU_BUFFERUSAGE_VERTEX,
                initial_vertex_capacity * vertex_size,
            );
        }

        const capacity = self.vertex_buffer.?.size / vertex_size;
        if (count <= capacity) return;

        var new_capacity: u32 = capacity;
        while (new_capacity < count) new_capacity *= 2;

        self.vertex_buffer.?.grow(device, new_capacity * vertex_size);
    }

    fn freeGpuBuffers(self: *Material, device: *sdl.SDL_GPUDevice) void {
        if (self.vertex_buffer) |*buffer| {
            buffer.deinit(device);
            self.vertex_buffer = null;
        }
    }
};

fn createShader(
    device: *sdl.SDL_GPUDevice,
    shader_stage: sdl.SDL_GPUShaderStage,
    entrypoint: [:0]const u8,
    shader_data: []const u8,
) *sdl.SDL_GPUShader {
    const shader_create_info = sdl.SDL_GPUShaderCreateInfo{
        .code_size = shader_data.len,
        .code = shader_data.ptr,
        .entrypoint = entrypoint.ptr,
        .format = sdl.SDL_GPU_SHADERFORMAT_SPIRV,
        .stage = shader_stage,
        .num_samplers = 0,
        .num_storage_textures = 0,
        .num_storage_buffers = if (shader_stage == sdl.SDL_GPU_SHADERSTAGE_VERTEX) 1 else 0,
        .num_uniform_buffers = if (shader_stage == sdl.SDL_GPU_SHADERSTAGE_VERTEX) 1 else 0,

        .props = 0,
    };

    return sdl.SDL_CreateGPUShader(device, &shader_create_info) orelse util.sdlPanic();
}
